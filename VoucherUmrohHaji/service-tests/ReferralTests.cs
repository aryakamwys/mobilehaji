using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using Microsoft.Extensions.DependencyInjection;
using VoucherUmrohHaji.Service.Data;

public class ReferralTests(TestApiFactory factory) : IClassFixture<TestApiFactory>
{
    private async Task<AuthResponse> RegisterAsync(string name)
    {
        var res = await factory.CreateClient().PostAsJsonAsync("/api/auth/register",
            new { name, email = $"ref.{name.ToLowerInvariant().Replace(' ', '.')}@test.id", password = "Rahasia123" });
        var auth = await res.Content.ReadFromJsonAsync<AuthResponse>();
        Assert.NotNull(auth);
        return auth!;
    }

    private HttpClient Client(AuthResponse auth)
    {
        var client = factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", auth.AccessToken);
        return client;
    }

    [Fact]
    public async Task Bind_berhasil_dan_referral_me_menampilkan_jaringan()
    {
        var a = await RegisterAsync("Ref A Satu");
        var b = await RegisterAsync("Ref B Satu");

        var bind = await Client(b).PostAsJsonAsync("/api/referral/bind", new { referralCode = a.Member.ReferralCode });
        Assert.True(bind.IsSuccessStatusCode, await bind.Content.ReadAsStringAsync());

        var meB = await Client(b).GetFromJsonAsync<ReferralMeResponse>("/api/referral/me");
        Assert.NotNull(meB);
        Assert.Equal(b.Member.ReferralCode, meB!.ReferralCode);
        Assert.Equal(a.Member.Name, meB.UplineName);
        Assert.Equal(0, meB.Downlines);
        Assert.Empty(meB.DirectDownlines);

        var meA = await Client(a).GetFromJsonAsync<ReferralMeResponse>("/api/referral/me");
        Assert.NotNull(meA);
        Assert.Equal(a.Member.ReferralCode, meA!.ReferralCode);
        Assert.Null(meA.UplineName);
        Assert.Equal(1, meA.Downlines);
        Assert.Equal(b.Member.Name, meA.DirectDownlines.Single().Name);

        // seed: step=2 multiplier=0.5 → factorPreview = 1 + ⌊1/2⌋ × 0.5 = 1.0
        Assert.Equal(1.0m, meA.FactorPreview);
        Assert.Equal(2, meA.DownlineStep);
        Assert.Equal(0.5m, meA.Multiplier);
        Assert.Equal(new[] { 1, 2, 3 }, meA.Rules.Select(r => r.Level).ToArray());
        Assert.Equal(5m, meA.Rules[0].Percentage);
    }

    [Fact]
    public async Task Bind_gagal_400_untuk_semua_kasus_invalid()
    {
        Assert.Equal(HttpStatusCode.Unauthorized,
            (await factory.CreateClient().GetAsync("/api/referral/me")).StatusCode);

        var a = await RegisterAsync("Ref A Dua");
        var b = await RegisterAsync("Ref B Dua");
        var c = await RegisterAsync("Ref C Dua");

        var sukses = await Client(b).PostAsJsonAsync("/api/referral/bind", new { referralCode = a.Member.ReferralCode });
        Assert.True(sukses.IsSuccessStatusCode, await sukses.Content.ReadAsStringAsync());

        var ulang = await Client(b).PostAsJsonAsync("/api/referral/bind", new { referralCode = c.Member.ReferralCode });
        Assert.Equal(HttpStatusCode.BadRequest, ulang.StatusCode); // sudah punya upline

        var sendiri = await Client(c).PostAsJsonAsync("/api/referral/bind", new { referralCode = c.Member.ReferralCode });
        Assert.Equal(HttpStatusCode.BadRequest, sendiri.StatusCode); // kode sendiri

        var tidakAda = await Client(c).PostAsJsonAsync("/api/referral/bind", new { referralCode = "VCH-TIDAKADA" });
        Assert.Equal(HttpStatusCode.BadRequest, tidakAda.StatusCode); // kode tidak dikenal

        var kosong = await Client(c).PostAsJsonAsync("/api/referral/bind", new { referralCode = "" });
        Assert.Equal(HttpStatusCode.BadRequest, kosong.StatusCode); // kode kosong tetap 400, bukan 500

        var admin = factory.CreateClient();
        var login = await admin.PostAsJsonAsync("/api/auth/login", new { email = "admin@haji.local", password = "Admin#2026" });
        var adminAuth = await login.Content.ReadFromJsonAsync<AuthResponse>();
        admin.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", adminAuth!.AccessToken);
        var byAdmin = await admin.PostAsJsonAsync("/api/referral/bind", new { referralCode = a.Member.ReferralCode });
        Assert.Equal(HttpStatusCode.BadRequest, byAdmin.StatusCode); // admin tidak boleh punya upline
    }

    [Fact]
    public async Task Bind_yang_membentuk_siklus_400()
    {
        var a = await RegisterAsync("Ref A Tiga");
        var b = await RegisterAsync("Ref B Tiga");
        var c = await RegisterAsync("Ref C Tiga");

        var bind = await Client(b).PostAsJsonAsync("/api/referral/bind", new { referralCode = a.Member.ReferralCode });
        Assert.True(bind.IsSuccessStatusCode, await bind.Content.ReadAsStringAsync());

        // ParentId A diset manual ke C (bypass bind) → rantai B→A→C; C mengikat B menutup ring C→B→A→C
        using (var scope = factory.CreateAdminScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            db.Members.Single(m => m.Id == a.Member.Id).ParentId = c.Member.Id;
            await db.SaveChangesAsync();
        }

        var siklus = await Client(c).PostAsJsonAsync("/api/referral/bind", new { referralCode = b.Member.ReferralCode });
        Assert.Equal(HttpStatusCode.BadRequest, siklus.StatusCode);
        Assert.Contains("siklus", await siklus.Content.ReadAsStringAsync());
    }
}

public record ReferralMeResponse(string ReferralCode, int Downlines, List<ReferralDownlineItem> DirectDownlines,
    decimal FactorPreview, string? UplineName, List<ReferralRuleItem> Rules, int DownlineStep, decimal Multiplier);
public record ReferralDownlineItem(string Name);
public record ReferralRuleItem(int Level, decimal Percentage);
