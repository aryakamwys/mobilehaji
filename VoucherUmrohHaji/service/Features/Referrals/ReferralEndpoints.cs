using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using VoucherUmrohHaji.Service.Common;
using VoucherUmrohHaji.Service.Data;
using VoucherUmrohHaji.Service.Features.Payments;

namespace VoucherUmrohHaji.Service.Features.Referrals;

public record ReferralMeResponse(string ReferralCode, int Downlines, List<DirectDownlineItem> DirectDownlines,
    decimal FactorPreview, string? UplineName, List<MlmRuleItem> Rules, int DownlineStep, decimal Multiplier);
public record DirectDownlineItem(string Name);
public record MlmRuleItem(int Level, decimal Percentage);
public record BindReferralRequest(string ReferralCode);

public static class ReferralEndpoints
{
    public static IEndpointRouteBuilder MapReferralEndpoints(this IEndpointRouteBuilder app)
    {
        // Jaringan milik pemanggil: downline langsung dan upline hanya dari rantai member sendiri.
        app.MapGet("/api/referral/me", async (ClaimsPrincipal user, AppDbContext db) =>
        {
            var memberId = user.MemberId();
            var me = await db.Members.AsNoTracking().SingleAsync(m => m.Id == memberId);
            var directDownlines = await db.Members.AsNoTracking()
                .Where(m => m.ParentId == memberId)
                .OrderBy(m => m.CreatedAt)
                .Select(m => new DirectDownlineItem(m.Name))
                .ToListAsync();
            var uplineName = me.ParentId is null
                ? null
                : await db.Members.AsNoTracking()
                    .Where(m => m.Id == me.ParentId).Select(m => m.Name).FirstOrDefaultAsync();
            var setting = await db.MlmSettings.AsNoTracking().SingleAsync(s => s.Id == 1);
            var rules = await db.MlmRules.AsNoTracking().OrderBy(r => r.Level)
                .Select(r => new MlmRuleItem(r.Level, r.Percentage)).ToListAsync();
            // step/multiplier ikut dikirim: admin memakainya untuk mengisi form konfigurasi MLM
            return Results.Ok(new ReferralMeResponse(me.ReferralCode, me.Downlines, directDownlines,
                MlmCalculator.ComputeFactor(me.Downlines, setting.DownlineStep, setting.Multiplier),
                uplineName, rules, setting.DownlineStep, setting.Multiplier));
        }).RequireAuthorization();

        // Semua validasi (bukan admin, belum punya upline, kode ada, bukan kode sendiri, tanpa siklus)
        // ada di ReferralService.BindUplineAsync → DomainException → 400.
        app.MapPost("/api/referral/bind", async (
            BindReferralRequest req, ClaimsPrincipal user, AppDbContext db, ReferralService referrals) =>
        {
            var member = await db.Members.SingleAsync(m => m.Id == user.MemberId());
            await referrals.BindUplineAsync(member, req.ReferralCode);
            return Results.Ok(new { ok = true });
        }).RequireAuthorization();

        return app;
    }
}
