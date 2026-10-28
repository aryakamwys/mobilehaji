using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Cryptography;
using System.Text;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using VoucherUmrohHaji.Service.Data;

public class WithdrawalTests(TestApiFactory factory) : IClassFixture<TestApiFactory>
{
    private const string ServerKey = "SB-Mid-server-TEST";

    // login dibatasi 5/menit per IP — cache token admin agar test tidak menyentuh limiter
    private static string? _adminToken;

    private async Task<HttpClient> AdminClientAsync()
    {
        var client = factory.CreateClient();
        if (_adminToken is null)
        {
            var res = await client.PostAsJsonAsync("/api/auth/login",
                new { email = "admin@haji.local", password = "Admin#2026" });
            var auth = await res.Content.ReadFromJsonAsync<AuthResponse>();
            _adminToken = auth!.AccessToken;
        }
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", _adminToken);
        return client;
    }

    private async Task<AuthResponse> RegisterAsync(string name)
    {
        var res = await factory.CreateClient().PostAsJsonAsync("/api/auth/register",
            new { name, email = $"wd.{name.ToLowerInvariant().Replace(' ', '.')}@test.id", password = "Rahasia123" });
        var auth = await res.Content.ReadFromJsonAsync<AuthResponse>();
        Assert.NotNull(auth);
        return auth!;
    }

    private HttpClient ClientFor(AuthResponse auth)
    {
        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", auth.AccessToken);
        return client;
    }

    /// <summary>Buyer dengan saldo 100.000 hasil settlement webhook voucher 100.000.</summary>
    private async Task<(AuthResponse Buyer, HttpClient Client)> BuyerDenganSaldoAsync(string name)
    {
        var admin = await AdminClientAsync();
        var voucher = await (await admin.PostAsJsonAsync("/api/admin/vouchers",
            new { title = $"Voucher WD {name}", price = 100_000L, value = 100_000L }))
            .Content.ReadFromJsonAsync<VoucherDto>();
        var buyer = await RegisterAsync(name);
        var client = ClientFor(buyer);
        var order = await (await client.PostAsJsonAsync("/api/orders", new { voucherId = voucher!.Id }))
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
        return (buyer, client);
    }

    /// <summary>Signature SHA256 Midtrans atas order_id + status_code + gross_amount + serverKey, hex lowercase.</summary>
    private static string SignatureUntuk(string orderId, string statusCode = "200", string grossAmount = "100000.00") =>
        Convert.ToHexString(SHA256.HashData(Encoding.ASCII.GetBytes(orderId + statusCode + grossAmount + ServerKey)))
            .ToLowerInvariant();

    private async Task<T> DbAsync<T>(Func<AppDbContext, Task<T>> query)
    {
        using var scope = factory.CreateAdminScope();
        return await query(scope.ServiceProvider.GetRequiredService<AppDbContext>());
    }

    private Task<long> SaldoAsync(Guid memberId) =>
        DbAsync(db => db.Members.Where(m => m.Id == memberId).Select(m => m.Balance).FirstAsync());

    [Fact]
    public async Task Withdraw_berhasil_menahan_saldo_dan_ledger_negatif()
    {
        var (buyer, client) = await BuyerDenganSaldoAsync("Wd Sukses Satu");

        var res = await client.PostAsJsonAsync("/api/withdrawals",
            new { amount = 30_000L, bank = "BCA", account = "1234567890", holder = "Budi Santoso" });
        Assert.True(res.IsSuccessStatusCode, await res.Content.ReadAsStringAsync());
        var wd = await res.Content.ReadFromJsonAsync<WithdrawalItem>();
        Assert.NotNull(wd);
        Assert.StartsWith("WD-", wd!.Id);
        Assert.Equal(30_000L, wd.Amount);
        Assert.Equal("BCA", wd.Bank);
        Assert.Equal("pending", wd.Status);

        Assert.Equal(70_000L, await SaldoAsync(buyer.Member.Id));
        var ledger = await DbAsync(db =>
            db.Ledgers.SingleAsync(l => l.MemberId == buyer.Member.Id && l.Type == "withdraw"));
        Assert.Equal(-30_000L, ledger.Amount);
        Assert.Equal("Hold withdraw ke BCA", ledger.Title);
        Assert.Equal(wd.Id, ledger.OrderId);

        // daftar withdraw hanya milik pemanggil dan berisi penarikan tadi
        var list = await client.GetFromJsonAsync<List<WithdrawalItem>>("/api/withdrawals");
        Assert.Equal(wd.Id, Assert.Single(list!).Id);
    }

    [Fact]
    public async Task Withdraw_invalid_400_tanpa_efek_samping()
    {
        var (buyer, client) = await BuyerDenganSaldoAsync("Wd Kurang Dua");
        var lengkap = new { bank = "BCA", account = "1234567890", holder = "Budi" };

        var kurang = await client.PostAsJsonAsync("/api/withdrawals", new { amount = 150_000L, lengkap.bank, lengkap.account, lengkap.holder });
        Assert.Equal(HttpStatusCode.BadRequest, kurang.StatusCode);
        Assert.Contains("Nominal tidak valid atau saldo tidak mencukupi", await kurang.Content.ReadAsStringAsync());

        var nol = await client.PostAsJsonAsync("/api/withdrawals", new { amount = 0L, lengkap.bank, lengkap.account, lengkap.holder });
        Assert.Equal(HttpStatusCode.BadRequest, nol.StatusCode);

        var bankKosong = await client.PostAsJsonAsync("/api/withdrawals",
            new { amount = 10_000L, bank = "   ", lengkap.account, lengkap.holder });
        Assert.Equal(HttpStatusCode.BadRequest, bankKosong.StatusCode);
        Assert.Contains("Lengkapi nama bank, rekening, dan pemilik rekening", await bankKosong.Content.ReadAsStringAsync());

        var rekeningPendek = await client.PostAsJsonAsync("/api/withdrawals",
            new { amount = 10_000L, lengkap.bank, account = "123", lengkap.holder });
        Assert.Equal(HttpStatusCode.BadRequest, rekeningPendek.StatusCode);

        // tidak ada withdrawal/ledger tercipta, saldo utuh
        Assert.Equal(100_000L, await SaldoAsync(buyer.Member.Id));
        Assert.Empty(await DbAsync(db => db.Withdrawals.Where(w => w.MemberId == buyer.Member.Id).ToListAsync()));
        Assert.Empty(await DbAsync(db => db.Ledgers.Where(l => l.MemberId == buyer.Member.Id && l.Type == "withdraw").ToListAsync()));

        // admin tidak boleh mengajukan withdraw
        var admin = await AdminClientAsync();
        var byAdmin = await admin.PostAsJsonAsync("/api/withdrawals",
            new { amount = 10_000L, lengkap.bank, lengkap.account, holder = "Admin" });
        Assert.Equal(HttpStatusCode.BadRequest, byAdmin.StatusCode);
        Assert.Contains("Hanya buyer", await byAdmin.Content.ReadAsStringAsync());
    }

    [Fact]
    public async Task Approve_menandai_approved_dan_tolak_proses_ulang()
    {
        var (buyer, client) = await BuyerDenganSaldoAsync("Wd Approve Tiga");
        var wd = await (await client.PostAsJsonAsync("/api/withdrawals",
            new { amount = 25_000L, bank = "Mandiri", account = "9876543210", holder = "Budi" }))
            .Content.ReadFromJsonAsync<WithdrawalItem>();
        Assert.NotNull(wd);

        var admin = await AdminClientAsync();
        var approve = await admin.PostAsync($"/api/admin/withdrawals/{wd!.Id}/approve", null);
        Assert.True(approve.IsSuccessStatusCode, await approve.Content.ReadAsStringAsync());

        Assert.Equal("approved", await DbAsync(db => Task.FromResult(db.Withdrawals.Find(wd.Id)!.Status)));
        Assert.Equal(75_000L, await SaldoAsync(buyer.Member.Id)); // approve tidak melepas hold

        var lagi = await admin.PostAsync($"/api/admin/withdrawals/{wd.Id}/approve", null);
        Assert.Equal(HttpStatusCode.BadRequest, lagi.StatusCode);
        Assert.Contains("Penarikan sudah diproses", await lagi.Content.ReadAsStringAsync());
    }

    [Fact]
    public async Task Reject_mengembalikan_saldo_dengan_ledger_refund_sekali()
    {
        var (buyer, client) = await BuyerDenganSaldoAsync("Wd Reject Empat");
        var wd = await (await client.PostAsJsonAsync("/api/withdrawals",
            new { amount = 40_000L, bank = "BNI", account = "5555444433", holder = "Budi" }))
            .Content.ReadFromJsonAsync<WithdrawalItem>();
        Assert.NotNull(wd);
        Assert.Equal(60_000L, await SaldoAsync(buyer.Member.Id));

        var admin = await AdminClientAsync();
        var reject = await admin.PostAsync($"/api/admin/withdrawals/{wd!.Id}/reject", null);
        Assert.True(reject.IsSuccessStatusCode, await reject.Content.ReadAsStringAsync());

        Assert.Equal("rejected", await DbAsync(db => Task.FromResult(db.Withdrawals.Find(wd.Id)!.Status)));
        Assert.Equal(100_000L, await SaldoAsync(buyer.Member.Id)); // dikembalikan penuh
        var refund = await DbAsync(db =>
            db.Ledgers.SingleAsync(l => l.MemberId == buyer.Member.Id && l.Type == "refund"));
        Assert.Equal(40_000L, refund.Amount); // positif
        Assert.Equal($"Pengembalian withdraw {wd.Id}", refund.Title);
        Assert.Equal(wd.Id, refund.OrderId);

        // reject kedua kali → 400, refund tidak dobel
        var duaKali = await admin.PostAsync($"/api/admin/withdrawals/{wd.Id}/reject", null);
        Assert.Equal(HttpStatusCode.BadRequest, duaKali.StatusCode);
        Assert.Contains("Penarikan sudah diproses", await duaKali.Content.ReadAsStringAsync());
        Assert.Equal(100_000L, await SaldoAsync(buyer.Member.Id));
        Assert.Single(await DbAsync(db =>
            db.Ledgers.Where(l => l.MemberId == buyer.Member.Id && l.Type == "refund").ToListAsync()));
    }

    [Fact]
    public async Task Buyer_ditolak_endpoint_admin_dan_daftar_admin_pending_dulu()
    {
        var (_, clientA) = await BuyerDenganSaldoAsync("Wd Lima A");
        var (_, clientB) = await BuyerDenganSaldoAsync("Wd Lima B");
        var wdA = await (await clientA.PostAsJsonAsync("/api/withdrawals",
            new { amount = 10_000L, bank = "BCA", account = "1111111111", holder = "A" }))
            .Content.ReadFromJsonAsync<WithdrawalItem>();
        var wdB = await (await clientB.PostAsJsonAsync("/api/withdrawals",
            new { amount = 20_000L, bank = "BRI", account = "2222222222", holder = "B" }))
            .Content.ReadFromJsonAsync<WithdrawalItem>();
        var admin = await AdminClientAsync();
        Assert.True((await admin.PostAsync($"/api/admin/withdrawals/{wdB!.Id}/approve", null)).IsSuccessStatusCode);

        // buyer tidak boleh menyentuh endpoint admin — 403, bukan 400/500
        Assert.Equal(HttpStatusCode.Forbidden, (await clientA.GetAsync("/api/admin/withdrawals")).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden,
            (await clientA.PostAsync($"/api/admin/withdrawals/{wdA!.Id}/approve", null)).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, (await clientA.GetAsync("/api/admin/members")).StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden,
            (await clientA.PutAsJsonAsync("/api/admin/mlm-config",
                new { levels = new decimal[] { 5m }, downlineStep = 2, multiplier = 0.5m })).StatusCode);

        // daftar admin: pending dulu (prefix), sisanya terbaru; daftar buyer hanya miliknya sendiri
        var list = await admin.GetFromJsonAsync<List<WithdrawalItem>>("/api/admin/withdrawals");
        Assert.NotNull(list);
        var pendingCount = list!.Count(w => w.Status == "pending");
        Assert.All(list.Take(pendingCount), w => Assert.Equal("pending", w.Status));
        Assert.All(list.Skip(pendingCount), w => Assert.NotEqual("pending", w.Status));
        Assert.Contains(wdA.Id, list.Take(pendingCount).Select(w => w.Id)); // wdA masih pending
        Assert.Contains(wdB.Id, list.Skip(pendingCount).Select(w => w.Id)); // wdB sudah approved
        Assert.Equal(wdA.Id, Assert.Single((await clientA.GetFromJsonAsync<List<WithdrawalItem>>("/api/withdrawals"))!).Id);
    }
}

public record WithdrawalItem(string Id, long Amount, string Bank, string Account, string Holder, string Status, DateTime CreatedAt);
