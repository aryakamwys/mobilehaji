using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Cryptography;
using System.Text;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using VoucherUmrohHaji.Service.Data;

public class AdminTests(TestApiFactory factory) : IClassFixture<TestApiFactory>
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

    private async Task<AuthResponse> RegisterAsync(string name, string? referral = null)
    {
        var res = await factory.CreateClient().PostAsJsonAsync("/api/auth/register",
            new { name, email = $"adm.{name.ToLowerInvariant().Replace(' ', '.')}@test.id", password = "Rahasia123", referral });
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

    /// <summary>Signature SHA512 Midtrans atas order_id + status_code + gross_amount + serverKey, hex lowercase.</summary>
    private static string SignatureUntuk(string orderId, string statusCode = "200", string grossAmount = "100000.00") =>
        Convert.ToHexString(SHA512.HashData(Encoding.ASCII.GetBytes(orderId + statusCode + grossAmount + ServerKey)))
            .ToLowerInvariant();

    private async Task<T> DbAsync<T>(Func<AppDbContext, Task<T>> query)
    {
        using var scope = factory.CreateAdminScope();
        return await query(scope.ServiceProvider.GetRequiredService<AppDbContext>());
    }

    [Fact]
    public async Task Members_terurut_nama_dengan_halaman_dan_clamp()
    {
        var admin = await AdminClientAsync();
        await RegisterAsync("Adm Alpha Satu");
        await RegisterAsync("Adm Zeta Dua");

        // ukuran halaman 100 (clamp atas) ≥ jumlah member → total sebenarnya
        var semua = await admin.GetFromJsonAsync<MembersPage>("/api/admin/members?page=1&pageSize=100");
        Assert.NotNull(semua);
        var total = semua!.Items.Count;
        Assert.True(total >= 3); // admin + minimal dua buyer di atas
        Assert.Equal((int)Math.Ceiling(total / 100.0), semua.TotalPages); // ⌈total/pageSize⌉

        var halaman = await admin.GetFromJsonAsync<MembersPage>("/api/admin/members?page=1&pageSize=2");
        Assert.Equal(2, halaman!.Items.Count);
        Assert.Equal((int)Math.Ceiling(total / 2.0), halaman.TotalPages);
        // halaman 1 = dua nama pertama menurut urutan nama DB
        Assert.Equal(semua.Items.Take(2).Select(i => i.Name), halaman.Items.Select(i => i.Name));
        // halaman terakhir berisi sisanya
        var terakhir = await admin.GetFromJsonAsync<MembersPage>(
            $"/api/admin/members?page={halaman.TotalPages}&pageSize=2");
        Assert.Equal(total - 2 * (halaman.TotalPages - 1), terakhir!.Items.Count);

        // body ringkas memuat semua field kontrak Flutter
        var item = halaman.Items[0];
        Assert.NotEqual(Guid.Empty, item.Id);
        Assert.False(string.IsNullOrWhiteSpace(item.Email));
        Assert.Contains(item.Role, new[] { "admin", "buyer" });
        Assert.False(string.IsNullOrWhiteSpace(item.ReferralCode));
        Assert.True(item.Balance >= 0);

        // clamp bawah: page=0 → 1, pageSize=500 → 100 → semua member pada satu halaman
        var clamp = await admin.GetFromJsonAsync<MembersPage>("/api/admin/members?page=0&pageSize=500");
        Assert.Equal(total, clamp!.Items.Count);
        Assert.Equal(1, clamp.TotalPages);
    }

    [Fact]
    public async Task Mlm_config_invalid_400_dan_tidak_mengubah_rules()
    {
        var admin = await AdminClientAsync();
        var sebelum = await DbAsync(db => db.MlmRules.OrderBy(r => r.Level)
            .Select(r => new MlmRuleEcho(r.Level, r.Percentage)).ToListAsync());

        var duaPuluhSatu = await admin.PutAsJsonAsync("/api/admin/mlm-config",
            new { levels = Enumerable.Repeat(5m, 21).ToArray(), downlineStep = 2, multiplier = 0.5m });
        Assert.Equal(HttpStatusCode.BadRequest, duaPuluhSatu.StatusCode);
        Assert.Contains("Konfigurasi komisi tidak valid", await duaPuluhSatu.Content.ReadAsStringAsync());

        var persen150 = await admin.PutAsJsonAsync("/api/admin/mlm-config",
            new { levels = new decimal[] { 5m, 150m }, downlineStep = 2, multiplier = 0.5m });
        Assert.Equal(HttpStatusCode.BadRequest, persen150.StatusCode);
        Assert.Contains("Konfigurasi komisi tidak valid", await persen150.Content.ReadAsStringAsync());

        var stepNol = await admin.PutAsJsonAsync("/api/admin/mlm-config",
            new { levels = new decimal[] { 5m }, downlineStep = 0, multiplier = 0.5m });
        Assert.Equal(HttpStatusCode.BadRequest, stepNol.StatusCode);

        var multiplierBesar = await admin.PutAsJsonAsync("/api/admin/mlm-config",
            new { levels = new decimal[] { 5m }, downlineStep = 2, multiplier = 150m });
        Assert.Equal(HttpStatusCode.BadRequest, multiplierBesar.StatusCode);

        // rules tidak tersentuh oleh permintaan invalid
        Assert.Equal(sebelum, await DbAsync(db => db.MlmRules.OrderBy(r => r.Level)
            .Select(r => new MlmRuleEcho(r.Level, r.Percentage)).ToListAsync()));
    }

    [Fact]
    public async Task Mlm_config_valid_mengubah_payout_berikutnya()
    {
        var admin = await AdminClientAsync();
        var upline = await RegisterAsync("Upline Mlm Tiga");
        var buyer = await RegisterAsync("Buyer Mlm Tiga", upline.Member.ReferralCode);

        var res = await admin.PutAsJsonAsync("/api/admin/mlm-config",
            new { levels = new decimal[] { 10m }, downlineStep = 2, multiplier = 0.5m });
        Assert.True(res.IsSuccessStatusCode, await res.Content.ReadAsStringAsync());
        var cfg = await res.Content.ReadFromJsonAsync<MlmConfigEcho>();
        Assert.NotNull(cfg);
        Assert.Single(cfg!.Levels);
        Assert.Equal(10m, cfg.Levels[0].Percentage);
        Assert.Equal(2, cfg.DownlineStep);
        Assert.Equal(0.5m, cfg.Multiplier);

        // rules lama tergantikan: hanya level 1 = 10%
        var rules = await DbAsync(db => db.MlmRules.OrderBy(r => r.Level).ToListAsync());
        var rule = Assert.Single(rules);
        Assert.Equal(1, rule.Level);
        Assert.Equal(10m, rule.Percentage);

        // order baru 100.000 settle → upline (1 downline → factor 1.0) menerima 10% = 10.000
        var voucher = await (await admin.PostAsJsonAsync("/api/admin/vouchers",
            new { title = "Voucher MLM Tiga", price = 100_000L, value = 100_000L }))
            .Content.ReadFromJsonAsync<VoucherDto>();
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

        Assert.Equal(10_000L, await DbAsync(db =>
            db.Members.Where(m => m.Id == upline.Member.Id).Select(m => m.Balance).FirstAsync()));
        var cashback = await DbAsync(db =>
            db.Ledgers.SingleAsync(l => l.OrderId == order.OrderId && l.Type == "mlm_cashback"));
        Assert.Equal(10_000L, cashback.Amount);
        Assert.Contains("Level 1", cashback.Title);
    }
}

public record MembersPage(List<MemberItem> Items, int TotalPages);
public record MemberItem(Guid Id, string Name, string Email, string Role, string ReferralCode,
    long Balance, int Downlines, Guid? ParentId);
public record MlmConfigEcho(List<MlmRuleEcho> Levels, int DownlineStep, decimal Multiplier);
public record MlmRuleEcho(int Level, decimal Percentage);
