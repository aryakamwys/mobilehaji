using System.Data;
using Microsoft.EntityFrameworkCore;
using VoucherUmrohHaji.Service.Common;
using VoucherUmrohHaji.Service.Data;
using VoucherUmrohHaji.Service.Data.Entities;
using VoucherUmrohHaji.Service.Features.Withdrawals;

namespace VoucherUmrohHaji.Service.Features.Admin;

public record MemberListItem(Guid Id, string Name, string Email, string Role, string ReferralCode,
    long Balance, int Downlines, Guid? ParentId);
public record MembersPageResponse(List<MemberListItem> Items, int TotalPages);
public record MlmConfigRequest(decimal[] Levels, int DownlineStep, decimal Multiplier);
public record MlmRuleItem(int Level, decimal Percentage);
public record MlmConfigResponse(List<MlmRuleItem> Levels, int DownlineStep, decimal Multiplier);
public record WithdrawalStatusResponse(string Id, string Status);

public static class AdminEndpoints
{
    public static IEndpointRouteBuilder MapAdminEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGet("/api/admin/withdrawals", async (AppDbContext db) =>
            Results.Ok(await db.Withdrawals.AsNoTracking()
                .OrderBy(w => w.Status == "pending" ? 0 : 1)
                .ThenByDescending(w => w.CreatedAt)
                .Select(w => new WithdrawalDto(w.Id, w.Amount, w.Bank, w.Account, w.Holder, w.Status, w.CreatedAt))
                .ToListAsync()))
            .RequireAuthorization(p => p.RequireRole("admin")).WithTags("Admin").WithSummary("Semua pengajuan withdraw");

        app.MapPost("/api/admin/withdrawals/{id}/approve", (string id, AppDbContext db) =>
                ProsesAsync(db, id, approve: true))
            .RequireAuthorization(p => p.RequireRole("admin")).WithTags("Admin").WithSummary("Setujui penarikan");

        app.MapPost("/api/admin/withdrawals/{id}/reject", (string id, AppDbContext db) =>
                ProsesAsync(db, id, approve: false))
            .RequireAuthorization(p => p.RequireRole("admin")).WithTags("Admin").WithSummary("Tolak penarikan (saldo dikembalikan)");

        // Daftar anggota: urut nama di sisi DB, halaman + totalPages (kontrak Flutter).
        app.MapGet("/api/admin/members", async (int? page, int? pageSize, AppDbContext db) =>
        {
            var size = Math.Clamp(pageSize ?? 20, 1, 100);
            var current = Math.Max(page ?? 1, 1);
            var total = await db.Members.CountAsync();
            var items = await db.Members.AsNoTracking()
                .OrderBy(m => m.Name)
                .Skip((current - 1) * size).Take(size)
                .Select(m => new MemberListItem(m.Id, m.Name, m.Email, m.Role, m.ReferralCode,
                    m.Balance, m.Downlines, m.ParentId))
                .ToListAsync();
            return Results.Ok(new MembersPageResponse(items, (int)Math.Ceiling(total / (double)size)));
        }).RequireAuthorization(p => p.RequireRole("admin")).WithTags("Admin").WithSummary("Daftar anggota");

        // Validasi mengikuti Store.swift configure: 1–20 level, tiap 0–100, step > 0,
        // multiplier 0–100 (decimal selalu finite; nilai tak terparse ditolak binding → 400).
        app.MapPut("/api/admin/mlm-config", async (MlmConfigRequest req, AppDbContext db) =>
        {
            if (req.Levels is null || req.Levels.Length < 1 || req.Levels.Length > 20
                || req.Levels.Any(p => p < 0 || p > 100)
                || req.DownlineStep <= 0 || req.Multiplier < 0 || req.Multiplier > 100)
                throw new DomainException("Konfigurasi komisi tidak valid");

            await using var tx = await db.Database.BeginTransactionAsync();
            // DELETE eksplisit lebih dulu — INSERT baru dengan Level sama tidak bentrok PK
            await db.MlmRules.ExecuteDeleteAsync();
            db.MlmRules.AddRange(req.Levels.Select((p, i) => new MlmRule { Level = i + 1, Percentage = p }));
            var setting = await db.MlmSettings.SingleAsync(s => s.Id == 1);
            setting.DownlineStep = req.DownlineStep;
            setting.Multiplier = req.Multiplier;
            await db.SaveChangesAsync();
            await tx.CommitAsync();
            return Results.Ok(new MlmConfigResponse(
                req.Levels.Select((p, i) => new MlmRuleItem(i + 1, p)).ToList(),
                req.DownlineStep, req.Multiplier));
        }).RequireAuthorization(p => p.RequireRole("admin")).WithTags("Admin").WithSummary("Persentase per level, step, multiplier");

        return app;
    }

    /// <summary>
    /// Approve/reject penarikan. Serializable + proyeksi skalar status (pola SettlementService):
    /// dua klik admin bersamaan hanya satu yang menang — penarikan diproses tepat sekali,
    /// refund masuk tepat sekali. Bukan pending (termasuk tidak dikenal) → 400, sesuai Store.swift.
    /// </summary>
    private static async Task<IResult> ProsesAsync(AppDbContext db, string id, bool approve)
    {
        await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable);
        var status = await db.Withdrawals.Where(w => w.Id == id)
            .Select(w => (string?)w.Status).FirstOrDefaultAsync();
        if (status != "pending") throw new DomainException("Penarikan sudah diproses");

        var withdrawal = await db.Withdrawals.SingleAsync(w => w.Id == id);
        withdrawal.Status = approve ? "approved" : "rejected";
        if (!approve)
        {
            var member = await db.Members.SingleAsync(m => m.Id == withdrawal.MemberId);
            member.Balance += withdrawal.Amount;
            db.Ledgers.Add(new Ledger
            {
                Id = Guid.NewGuid(), MemberId = withdrawal.MemberId, Type = "refund",
                Title = $"Pengembalian withdraw {id}", Amount = withdrawal.Amount,
                OrderId = id, CreatedAt = DateTime.UtcNow
            });
        }
        await db.SaveChangesAsync();
        await tx.CommitAsync();
        return Results.Ok(new WithdrawalStatusResponse(withdrawal.Id, withdrawal.Status));
    }
}
