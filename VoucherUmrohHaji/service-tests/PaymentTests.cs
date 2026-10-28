using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.DependencyInjection;
using VoucherUmrohHaji.Service.Common;
using VoucherUmrohHaji.Service.Data;

public class PaymentTests(TestApiFactory factory) : IClassFixture<TestApiFactory>
{
    private const string ServerKey = "SB-Mid-server-TEST";

    // login dibatasi 5/menit per IP — cache token admin agar test tidak menyentuh limiter
    private static string? _adminToken;

    private async Task LoginAdminAsync(HttpClient client)
    {
        if (_adminToken is null)
        {
            var res = await client.PostAsJsonAsync("/api/auth/login", new { email = "admin@haji.local", password = "Admin#2026" });
            var auth = await res.Content.ReadFromJsonAsync<AuthResponse>();
            _adminToken = auth!.AccessToken;
        }
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", _adminToken);
    }

    private async Task<AuthResponse> RegisterAsync(string name, string? referral = null)
    {
        var client = factory.CreateClient();
        var res = await client.PostAsJsonAsync("/api/auth/register",
            new { name, email = $"pay.{name.ToLowerInvariant().Replace(' ', '.')}@test.id", password = "Rahasia123", referral });
        var auth = await res.Content.ReadFromJsonAsync<AuthResponse>();
        Assert.NotNull(auth);
        return auth!;
    }

    /// <summary>Buyer + upline (+ grandparent opsional) + order pending voucher 100.000/100.000.</summary>
    private async Task<(string OrderId, Guid BuyerId, string BuyerName, string VoucherTitle, Guid UplineId, Guid? GrandparentId, string BuyerToken)>
        BuatOrderPendingAsync(string name, bool withGrandparent)
    {
        var admin = factory.CreateClient();
        await LoginAdminAsync(admin);
        var voucher = await (await admin.PostAsJsonAsync("/api/admin/vouchers",
            new { title = $"Voucher Bayar {name}", price = 100_000L, value = 100_000L }))
            .Content.ReadFromJsonAsync<VoucherDto>();

        Guid? grandparentId = null;
        string? uplineReferral = null;
        if (withGrandparent)
        {
            var grandparent = await RegisterAsync($"Kakek {name}");
            grandparentId = grandparent.Member.Id;
            uplineReferral = grandparent.Member.ReferralCode;
        }
        var upline = await RegisterAsync($"Upline {name}", uplineReferral);
        var buyer = await RegisterAsync($"Buyer {name}", upline.Member.ReferralCode);

        var buyerClient = factory.CreateClient();
        buyerClient.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", buyer.AccessToken);
        var order = await (await buyerClient.PostAsJsonAsync("/api/orders", new { voucherId = voucher!.Id }))
            .Content.ReadFromJsonAsync<CreateOrderResponse>();
        Assert.NotNull(order);
        return (order!.OrderId, buyer.Member.Id, buyer.Member.Name, voucher!.Title, upline.Member.Id, grandparentId, buyer.AccessToken);
    }

    /// <summary>Signature SHA512 Midtrans atas order_id + status_code + gross_amount + serverKey, hex lowercase.</summary>
    private static string SignatureUntuk(string orderId, string statusCode = "200", string grossAmount = "100000.00") =>
        Convert.ToHexString(SHA512.HashData(Encoding.ASCII.GetBytes(orderId + statusCode + grossAmount + ServerKey)))
            .ToLowerInvariant();

    private static object Notifikasi(string orderId, string transactionStatus, string signature,
        string statusCode = "200", string grossAmount = "100000.00", string? fraudStatus = "accept") => new
    {
        order_id = orderId, status_code = statusCode, gross_amount = grossAmount,
        transaction_status = transactionStatus, fraud_status = fraudStatus, signature_key = signature
    };

    [Fact]
    public async Task Webhook_signature_valid_settlement_dan_idempotent()
    {
        var (orderId, buyerId, buyerName, voucherTitle, uplineId, grandparentId, _) =
            await BuatOrderPendingAsync("Satu", withGrandparent: true);
        var notif = Notifikasi(orderId, "settlement", SignatureUntuk(orderId));

        var respons1 = await factory.CreateClient().PostAsJsonAsync("/api/webhooks/midtrans", notif);
        var respons2 = await factory.CreateClient().PostAsJsonAsync("/api/webhooks/midtrans", notif); // replay
        Assert.True(respons1.IsSuccessStatusCode, await respons1.Content.ReadAsStringAsync());
        Assert.True(respons2.IsSuccessStatusCode, await respons2.Content.ReadAsStringAsync());

        using var scope = factory.CreateAdminScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        // saldo buyer +value SEKALI (replay tidak menggandakan), satu ledger topup, order settlement
        Assert.Equal(100_000L, db.Members.Single(m => m.Id == buyerId).Balance);
        var topups = db.Ledgers.Where(l => l.OrderId == orderId && l.Type == "topup").ToList();
        Assert.Single(topups);
        Assert.Equal($"Top-Up {voucherTitle}", topups[0].Title);
        Assert.Equal(100_000L, topups[0].Amount);
        Assert.Equal("settlement", db.Orders.Find(orderId)!.Status);
        var owned = db.VouchersOwned.Single(v => v.OrderId == orderId);
        Assert.Equal(voucherTitle, owned.Title);
        Assert.Equal(100_000L, owned.Value);

        // upline L1: 1 downline → factor 1.0 → 5% = 5.000; grandparent L2: 2 downline → factor 1.5 → 3% × 1.5 = 4.500
        var cashbacks = db.Ledgers.Where(l => l.OrderId == orderId && l.Type == "mlm_cashback").ToList();
        Assert.Equal(2, cashbacks.Count); // chain hanya 2 level, rules level 3 tidak terpakai
        Assert.Equal(5_000L, db.Members.Single(m => m.Id == uplineId).Balance);
        Assert.Equal(4_500L, db.Members.Single(m => m.Id == grandparentId).Balance);
        Assert.Contains(cashbacks, l => l.Title == $"Cashback Level 1 ×1.00 dari {buyerName}" && l.Amount == 5_000L);
        Assert.Contains(cashbacks, l => l.Title == $"Cashback Level 2 ×1.50 dari {buyerName}" && l.Amount == 4_500L);
    }

    [Fact]
    public async Task Webhook_signature_salah_400_dan_tidak_settle()
    {
        var (orderId, buyerId, _, _, uplineId, _, _) = await BuatOrderPendingAsync("Dua", withGrandparent: false);

        var res = await factory.CreateClient().PostAsJsonAsync("/api/webhooks/midtrans",
            Notifikasi(orderId, "settlement", SignatureUntuk(orderId, grossAmount: "99999.00")));
        Assert.Equal(HttpStatusCode.BadRequest, res.StatusCode);
        Assert.Contains("Signature tidak valid", await res.Content.ReadAsStringAsync());

        using var scope = factory.CreateAdminScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Equal(0L, db.Members.Single(m => m.Id == buyerId).Balance);
        Assert.Equal(0L, db.Members.Single(m => m.Id == uplineId).Balance);
        Assert.Empty(db.Ledgers.Where(l => l.OrderId == orderId));
        Assert.Equal("pending", db.Orders.Find(orderId)!.Status);
        Assert.Empty(db.VouchersOwned.Where(v => v.OrderId == orderId));
    }

    [Fact]
    public async Task Inquiry_status_juga_settle_order_pending()
    {
        var (orderId, buyerId, _, _, uplineId, _, buyerToken) = await BuatOrderPendingAsync("Tiga", withGrandparent: false);
        factory.Services.GetRequiredService<IMidtransClient>().AsFake().NextStatus = "settlement";

        Assert.Equal(HttpStatusCode.Unauthorized,
            (await factory.CreateClient().GetAsync($"/api/orders/{orderId}/status")).StatusCode);

        var buyer = factory.CreateClient();
        buyer.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", buyerToken);
        var json = await buyer.GetFromJsonAsync<OrderStatusResponse>($"/api/orders/{orderId}/status");
        Assert.NotNull(json);
        Assert.Equal(orderId, json!.OrderId);
        Assert.Equal("settlement", json.Status);

        // inquiry kedua: status tetap, saldo tidak dobel
        var lagi = await buyer.GetFromJsonAsync<OrderStatusResponse>($"/api/orders/{orderId}/status");
        Assert.Equal("settlement", lagi!.Status);

        using var scope = factory.CreateAdminScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Equal(100_000L, db.Members.Single(m => m.Id == buyerId).Balance);
        Assert.Single(db.Ledgers.Where(l => l.OrderId == orderId && l.Type == "topup"));
        Assert.Equal(5_000L, db.Members.Single(m => m.Id == uplineId).Balance);
    }

    [Fact]
    public async Task Inquiry_order_orang_lain_404_dan_webhook_order_tidak_dikenal_200()
    {
        var (orderId, buyerId, _, _, _, _, _) = await BuatOrderPendingAsync("Empat", withGrandparent: false);
        var lain = factory.CreateClient();
        lain.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", (await RegisterAsync($"Lain {orderId[..8]}")).AccessToken);

        Assert.Equal(HttpStatusCode.NotFound, (await lain.GetAsync($"/api/orders/{orderId}/status")).StatusCode);

        var tidakDikenal = "ORD-TIDAKADA99";
        var res = await factory.CreateClient().PostAsJsonAsync("/api/webhooks/midtrans",
            Notifikasi(tidakDikenal, "settlement", SignatureUntuk(tidakDikenal)));
        Assert.True(res.IsSuccessStatusCode, await res.Content.ReadAsStringAsync());

        using var scope = factory.CreateAdminScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Equal(0L, db.Members.Single(m => m.Id == buyerId).Balance);
        Assert.Equal("pending", db.Orders.Find(orderId)!.Status);
    }

    [Fact]
    public async Task Webhook_pakai_SHA512_bukan_SHA256()
    {
        var (orderId, buyerId, _, _, uplineId, _, _) = await BuatOrderPendingAsync("Lima", withGrandparent: false);
        // SHA256 atas payload yang sama — kalau endpoint masih memakai SHA256, tanda ini diterima
        var sha256 = Convert.ToHexString(SHA256.HashData(
            Encoding.ASCII.GetBytes(orderId + "200" + "100000.00" + ServerKey))).ToLowerInvariant();

        var ditolak = await factory.CreateClient().PostAsJsonAsync("/api/webhooks/midtrans",
            Notifikasi(orderId, "settlement", sha256));
        Assert.Equal(HttpStatusCode.BadRequest, ditolak.StatusCode);

        using (var scope = factory.CreateAdminScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            Assert.Equal(0L, db.Members.Single(m => m.Id == buyerId).Balance);
            Assert.Equal(0L, db.Members.Single(m => m.Id == uplineId).Balance);
            Assert.Empty(db.Ledgers.Where(l => l.OrderId == orderId));
            Assert.Equal("pending", db.Orders.Find(orderId)!.Status);
        }

        var diterima = await factory.CreateClient().PostAsJsonAsync("/api/webhooks/midtrans",
            Notifikasi(orderId, "settlement", SignatureUntuk(orderId)));
        Assert.True(diterima.IsSuccessStatusCode, await diterima.Content.ReadAsStringAsync());

        using (var scope = factory.CreateAdminScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            Assert.Equal(100_000L, db.Members.Single(m => m.Id == buyerId).Balance);
            Assert.Single(db.Ledgers.Where(l => l.OrderId == orderId && l.Type == "topup"));
            Assert.Equal("settlement", db.Orders.Find(orderId)!.Status);
        }
    }

    [Fact]
    public async Task Capture_accept_settle_dan_capture_challenge_noop()
    {
        var (orderId, buyerId, _, _, _, _, _) = await BuatOrderPendingAsync("Enam", withGrandparent: false);
        var challenge = await factory.CreateClient().PostAsJsonAsync("/api/webhooks/midtrans",
            Notifikasi(orderId, "capture", SignatureUntuk(orderId), fraudStatus: "challenge"));
        Assert.True(challenge.IsSuccessStatusCode, await challenge.Content.ReadAsStringAsync());

        using (var scope = factory.CreateAdminScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            Assert.Equal("pending", db.Orders.Find(orderId)!.Status); // challenge bukan settle
            Assert.Empty(db.Ledgers.Where(l => l.OrderId == orderId));
        }

        var capture = await factory.CreateClient().PostAsJsonAsync("/api/webhooks/midtrans",
            Notifikasi(orderId, "capture", SignatureUntuk(orderId), fraudStatus: "accept"));
        Assert.True(capture.IsSuccessStatusCode, await capture.Content.ReadAsStringAsync());

        using (var scope = factory.CreateAdminScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            Assert.Equal(100_000L, db.Members.Single(m => m.Id == buyerId).Balance);
            Assert.Equal("settlement", db.Orders.Find(orderId)!.Status);
        }
    }

    [Fact]
    public async Task Deny_jadi_cancel_dan_expire_jadi_expire()
    {
        var (orderId, buyerId, _, _, _, _, _) = await BuatOrderPendingAsync("Tujuh", withGrandparent: false);
        var deny = await factory.CreateClient().PostAsJsonAsync("/api/webhooks/midtrans",
            Notifikasi(orderId, "deny", SignatureUntuk(orderId)));
        Assert.True(deny.IsSuccessStatusCode, await deny.Content.ReadAsStringAsync());

        var (orderId2, _, _, _, _, _, _) = await BuatOrderPendingAsync("Delapan", withGrandparent: false);
        var expire = await factory.CreateClient().PostAsJsonAsync("/api/webhooks/midtrans",
            Notifikasi(orderId2, "expire", SignatureUntuk(orderId2)));
        Assert.True(expire.IsSuccessStatusCode, await expire.Content.ReadAsStringAsync());

        using var scope = factory.CreateAdminScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.Equal("cancel", db.Orders.Find(orderId)!.Status);
        Assert.Equal("expire", db.Orders.Find(orderId2)!.Status);
        Assert.Equal(0L, db.Members.Single(m => m.Id == buyerId).Balance);
        Assert.Empty(db.Ledgers.Where(l => l.OrderId == orderId || l.OrderId == orderId2));
    }
}

public record OrderStatusResponse(string OrderId, string Status);

public static class FakeMidtransExtensions
{
    public static FakeMidtransClient AsFake(this IMidtransClient client) => (FakeMidtransClient)client;
}
