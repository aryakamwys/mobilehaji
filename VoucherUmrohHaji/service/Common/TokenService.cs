using System.Buffers.Text;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using VoucherUmrohHaji.Service.Data;
using VoucherUmrohHaji.Service.Data.Entities;

namespace VoucherUmrohHaji.Service.Common;

/// <summary>Menerbitkan access token JWT (HS256) dan refresh token acak yang disimpan sebagai hash.</summary>
public class TokenService(AppDbContext db, IConfiguration configuration)
{
    public const int AccessTokenLifetimeSeconds = 15 * 60;
    private static readonly TimeSpan RefreshTokenLifetime = TimeSpan.FromDays(30);

    public async Task<(string accessToken, string refreshToken, int expiresIn)> IssueAsync(Member member)
    {
        var refreshToken = Convert.ToHexString(RandomNumberGenerator.GetBytes(32));
        db.RefreshTokens.Add(new RefreshToken
        {
            Id = Guid.NewGuid(),
            MemberId = member.Id,
            TokenHash = Hash(refreshToken),
            ExpiresAt = DateTime.UtcNow.Add(RefreshTokenLifetime)
        });
        await db.SaveChangesAsync();
        return (CreateAccessToken(member), refreshToken, AccessTokenLifetimeSeconds);
    }

    public async Task<(string accessToken, string refreshToken)> RefreshAsync(string refreshToken)
    {
        var stored = await db.RefreshTokens.SingleOrDefaultAsync(t => t.TokenHash == Hash(refreshToken));
        if (stored is null || stored.Revoked || stored.ExpiresAt <= DateTime.UtcNow)
            throw new DomainException("Refresh token tidak valid atau kedaluwarsa");

        stored.Revoked = true;
        var member = await db.Members.FindAsync(stored.MemberId)
            ?? throw new DomainException("Refresh token tidak valid atau kedaluwarsa");
        var (access, rotated, _) = await IssueAsync(member);
        return (access, rotated);
    }

    public async Task RevokeAsync(string refreshToken)
    {
        var stored = await db.RefreshTokens.SingleOrDefaultAsync(t => t.TokenHash == Hash(refreshToken));
        if (stored is null || stored.Revoked) return;
        stored.Revoked = true;
        await db.SaveChangesAsync();
    }

    private string CreateAccessToken(Member member)
    {
        var key = configuration["Jwt:Key"] ?? throw new InvalidOperationException("Jwt:Key belum dikonfigurasi (user-secrets).");
        if (key.Length < 32) throw new InvalidOperationException("Jwt:Key minimal 32 karakter.");
        var issuedAt = DateTimeOffset.UtcNow;
        var payload = JsonSerializer.Serialize(new Dictionary<string, object?>
        {
            ["sub"] = member.Id.ToString(),
            ["nameid"] = member.Id.ToString(),
            ["role"] = member.Role,
            ["iss"] = configuration["Jwt:Issuer"] ?? throw new InvalidOperationException("Jwt:Issuer belum dikonfigurasi."),
            ["aud"] = configuration["Jwt:Audience"] ?? throw new InvalidOperationException("Jwt:Audience belum dikonfigurasi."),
            ["iat"] = issuedAt.ToUnixTimeSeconds(),
            ["exp"] = issuedAt.AddSeconds(AccessTokenLifetimeSeconds).ToUnixTimeSeconds()
        });
        var header = Base64Url.EncodeToString(Encoding.UTF8.GetBytes("""{"alg":"HS256","typ":"JWT"}"""));
        var body = Base64Url.EncodeToString(Encoding.UTF8.GetBytes(payload));
        var signature = Base64Url.EncodeToString(HMACSHA256.HashData(
            Encoding.UTF8.GetBytes(key), Encoding.UTF8.GetBytes($"{header}.{body}")));
        return $"{header}.{body}.{signature}";
    }

    private static string Hash(string token) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(token)));
}
