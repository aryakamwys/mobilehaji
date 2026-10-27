using System.Net;
using System.Net.Http.Json;

public class AuthTests(TestApiFactory factory) : IClassFixture<TestApiFactory>
{
    [Fact] public async Task Register_lalu_login_menghasilkan_token()
    {
        var client = factory.CreateClient();
        var reg = await client.PostAsJsonAsync("/api/auth/register",
            new { name = "Budi Santoso", email = "budi@test.id", password = "Rahasia123", referral = "" });
        Assert.True(reg.IsSuccessStatusCode, await reg.Content.ReadAsStringAsync());
        var auth = await reg.Content.ReadFromJsonAsync<AuthResponse>();
        Assert.False(string.IsNullOrEmpty(auth!.AccessToken));

        var login = await client.PostAsJsonAsync("/api/auth/login", new { email = "budi@test.id", password = "Rahasia123" });
        Assert.True(login.IsSuccessStatusCode);
    }

    [Fact] public async Task Register_email_duplikat_400()
    {
        var client = factory.CreateClient();
        var body = new { name = "Budi", email = "dua@test.id", password = "Rahasia123" };
        await client.PostAsJsonAsync("/api/auth/register", body);
        var dua = await client.PostAsJsonAsync("/api/auth/register", body);
        Assert.Equal(HttpStatusCode.BadRequest, dua.StatusCode);
    }

    [Fact] public async Task Login_password_salah_401()
    {
        var client = factory.CreateClient();
        await client.PostAsJsonAsync("/api/auth/register", new { name = "Budi", email = "salah@test.id", password = "Rahasia123" });
        var login = await client.PostAsJsonAsync("/api/auth/login", new { email = "salah@test.id", password = "Ngasalan999" });
        Assert.Equal(HttpStatusCode.Unauthorized, login.StatusCode);
    }

    [Fact] public async Task Refresh_token_baru_bisa_dipakai()
    {
        var client = factory.CreateClient();
        var reg = await client.PostAsJsonAsync("/api/auth/register", new { name = "Budi", email = "ref@test.id", password = "Rahasia123" });
        var auth = await reg.Content.ReadFromJsonAsync<AuthResponse>()!;
        var refresh = await client.PostAsJsonAsync("/api/auth/refresh", new { refreshToken = auth!.RefreshToken });
        Assert.True(refresh.IsSuccessStatusCode);
        var bad = await client.PostAsJsonAsync("/api/auth/refresh", new { refreshToken = "sampah-token" });
        Assert.Equal(HttpStatusCode.BadRequest, bad.StatusCode);
    }
}
public record AuthResponse(string AccessToken, string RefreshToken, int ExpiresIn, MemberDto Member);
public record MemberDto(Guid Id, string Name, string Email, string Role, string ReferralCode, long Balance, int Downlines, Guid? ParentId);
