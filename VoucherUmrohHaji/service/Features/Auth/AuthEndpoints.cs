using System.Security.Cryptography;
using Microsoft.EntityFrameworkCore;
using VoucherUmrohHaji.Service.Common;
using VoucherUmrohHaji.Service.Data;
using VoucherUmrohHaji.Service.Data.Entities;
using VoucherUmrohHaji.Service.Features.Referrals;

namespace VoucherUmrohHaji.Service.Features.Auth;

public record RegisterRequest(string Name, string Email, string Password, string? Referral);
public record LoginRequest(string Email, string Password);
public record RefreshRequest(string RefreshToken);
public record MemberDto(Guid Id, string Name, string Email, string Role, string ReferralCode, long Balance, int Downlines, Guid? ParentId);
public record AuthResponse(string AccessToken, string RefreshToken, int ExpiresIn, MemberDto Member);

public static class AuthEndpoints
{
    public static IEndpointRouteBuilder MapAuthEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapPost("/api/auth/register", async (RegisterRequest req, AppDbContext db, TokenService tokens, ReferralService referrals) =>
        {
            if (string.IsNullOrWhiteSpace(req.Name) || string.IsNullOrWhiteSpace(req.Email))
                throw new DomainException("Isi nama dan alamat email yang valid");
            var name = req.Name.Trim();
            var email = req.Email.Trim().ToLowerInvariant();
            if (name.Length < 3 || !email.Contains('@') || !email.Contains('.')) throw new DomainException("Isi nama dan alamat email yang valid");
            if (string.IsNullOrWhiteSpace(req.Password) || req.Password.Length < 8) throw new DomainException("Password minimal 8 karakter");
            if (await db.Members.AnyAsync(m => m.Email == email)) throw new DomainException("Email sudah digunakan");

            var member = new Member { Id = Guid.NewGuid(), Name = name, Email = email,
                PasswordHash = BCrypt.Net.BCrypt.HashPassword(req.Password),
                ReferralCode = await GenerateUniqueCodeAsync(db) };
            // Tambahkan dulu lalu bind: BindUplineAsync memvalidasi SEBELUM menyimpan, dan
            // SaveChangesAsync-nya menyimpan member + increment ancestor dalam satu transaksi.
            // Referral invalid → DomainException → tidak ada yang tersimpan (register atomik).
            db.Members.Add(member);
            if (!string.IsNullOrWhiteSpace(req.Referral)) await referrals.BindUplineAsync(member, req.Referral);
            await db.SaveChangesAsync();
            var (access, refresh, expiresIn) = await tokens.IssueAsync(member);
            return Results.Ok(new AuthResponse(access, refresh, expiresIn, member.ToDto()));
        }).WithTags("Auth").WithSummary("Daftar akun baru (referral opsional)");

        app.MapPost("/api/auth/login", async (LoginRequest req, AppDbContext db, TokenService tokens) =>
        {
            if (string.IsNullOrWhiteSpace(req.Email) || string.IsNullOrWhiteSpace(req.Password))
                throw new DomainException("Isi email dan password");
            var email = req.Email.Trim().ToLowerInvariant();
            var member = await db.Members.SingleOrDefaultAsync(m => m.Email == email);
            if (member is null || !BCrypt.Net.BCrypt.Verify(req.Password, member.PasswordHash))
                return Results.Unauthorized();
            var (access, refresh, expiresIn) = await tokens.IssueAsync(member);
            return Results.Ok(new AuthResponse(access, refresh, expiresIn, member.ToDto()));
        }).RequireRateLimiting("login").WithTags("Auth").WithSummary("Login, dapat access + refresh token");

        app.MapPost("/api/auth/refresh", async (RefreshRequest req, TokenService tokens) =>
        {
            if (string.IsNullOrWhiteSpace(req.RefreshToken))
                throw new DomainException("Refresh token tidak valid atau kedaluwarsa");
            var (access, refresh, member) = await tokens.RefreshAsync(req.RefreshToken);
            return Results.Ok(new AuthResponse(access, refresh, TokenService.AccessTokenLifetimeSeconds, member.ToDto()));
        }).WithTags("Auth").WithSummary("Tukar refresh token");

        return app;
    }

    private static async Task<string> GenerateUniqueCodeAsync(AppDbContext db)
    {
        while (true)
        {
            var code = "VCH-" + Convert.ToHexString(RandomNumberGenerator.GetBytes(4));
            if (!await db.Members.AnyAsync(m => m.ReferralCode == code)) return code;
        }
    }
}
