using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.DependencyInjection;
using VoucherUmrohHaji.Service.Data;
using VoucherUmrohHaji.Service.Data.Entities;

public class WalletTests(TestApiFactory factory) : IClassFixture<TestApiFactory>
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

    private async Task<AuthResponse> RegisterAsync(string name)
    {
        var res = await factory.CreateClient().PostAsJsonAsync("/api/auth/register",
            new { name, email = $"wallet.{name.ToLowerInvariant().Replace(' ', '.')}@test.id", password = "Rahasia123" });
        var auth = await res.Content.ReadFromJsonAsync<AuthResponse>();
        Assert.NotNull(auth);
        return auth!;
    }

    /// <summary>Buyer + order voucher 100.000 yang sudah settle via webhook valid.</summary>
    private async Task<(HttpClient Buyer, string OrderId, string VoucherTitle)> SettleOrderAsync(string name)
    {
        var admin = factory.CreateClient();
        await LoginAdminAsync(admin);
        var voucher = await (await admin.PostAsJsonAsync("/api/admin/vouchers",
            new { title = $"Voucher Wallet {name}", price = 100_000L, value = 100_000L }))
            .Content.ReadFromJsonAsync<VoucherDto>();

        var buyer = factory.CreateClient();
        buyer.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", (await RegisterAsync(name)).AccessToken);
        var order = await (await buyer.PostAsJsonAsync("/api/orders", new { voucherId = voucher!.Id }))
            .Content.ReadFromJsonAsync<CreateOrderResponse>();
        Assert.NotNull(order);

        var notif = new
        {
            order_id = order!.OrderId, status_code = "200", gross_amount = "100000.00",
            transaction_status = "settlement", fraud_status = "accept",
            signature_key = SignatureUntuk(order.OrderId)
        };
        var webhook = await factory.CreateClient().PostAsJsonAsync("/api/webhooks/midtrans", notif);
        Assert.True(webhook.IsSuccessStatusCode, await webhook.Content.ReadAsStringAsync());
        return (buyer, order.OrderId, voucher!.Title);
    }

    /// <summary>Signature SHA512 Midtrans atas order_id + status_code + gross_amount + serverKey, hex lowercase.</summary>
    private static string SignatureUntuk(string orderId, string statusCode = "200", string grossAmount = "100000.00") =>
        Convert.ToHexString(SHA512.HashData(Encoding.ASCII.GetBytes(orderId + statusCode + grossAmount + ServerKey)))
            .ToLowerInvariant();

    [Fact]
    public async Task Wallet_setelah_settlement_menampilkan_saldo_owned_dan_ledger()
    {
        var (buyer, orderId, voucherTitle) = await SettleOrderAsync("Wallet Satu");
        Assert.Equal(HttpStatusCode.Unauthorized, (await factory.CreateClient().GetAsync("/api/wallet")).StatusCode);

        var wallet = await buyer.GetFromJsonAsync<WalletResponse>("/api/wallet");
        Assert.NotNull(wallet);
        Assert.Equal(100_000L, wallet!.Balance);

        var owned = Assert.Single(wallet.Owned);
        Assert.Equal(voucherTitle, owned.Title);
        Assert.Equal(100_000L, owned.Value);
        Assert.Equal(orderId, owned.OrderId);

        var ledger = Assert.Single(wallet.Ledger);
        Assert.Equal("topup", ledger.Type);
        Assert.Equal(100_000L, ledger.Amount);
        Assert.Equal(orderId, ledger.OrderId);

        // wallet orang lain tidak ikut terlihat — balance kosong, tanpa owned/ledger
        var lain = factory.CreateClient();
        lain.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue("Bearer", (await RegisterAsync("Wallet Lain Satu")).AccessToken);
        var walletLain = await lain.GetFromJsonAsync<WalletResponse>("/api/wallet");
        Assert.NotNull(walletLain);
        Assert.Equal(0L, walletLain!.Balance);
        Assert.Empty(walletLain.Owned);
        Assert.Empty(walletLain.Ledger);
    }

    [Fact]
    public async Task Ledger_dibatasi_50_entri_terbaru_dulu()
    {
        var auth = await RegisterAsync("Wallet Dua");
        using (var scope = factory.CreateAdminScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            for (var i = 1; i <= 55; i++)
                db.Ledgers.Add(new Ledger
                {
                    Id = Guid.NewGuid(), MemberId = auth.Member.Id, Type = "topup",
                    Title = $"Top-Up ke-{i}", Amount = i, OrderId = $"ORD-WLT{i}",
                    CreatedAt = DateTime.UtcNow.AddMinutes(i)
                });
            await db.SaveChangesAsync();
        }

        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", auth.AccessToken);
        var wallet = await client.GetFromJsonAsync<WalletResponse>("/api/wallet");
        Assert.NotNull(wallet);
        Assert.Equal(50, wallet!.Ledger.Count);
        Assert.Equal("Top-Up ke-55", wallet.Ledger[0].Title); // terbaru dulu
        Assert.Equal("Top-Up ke-6", wallet.Ledger[49].Title);
    }
}

public record WalletResponse(long Balance, List<WalletOwnedItem> Owned, List<WalletLedgerItem> Ledger);
public record WalletOwnedItem(string Title, long Value, string OrderId, DateTime CreatedAt);
public record WalletLedgerItem(string Type, string Title, long Amount, string OrderId, DateTime CreatedAt);
