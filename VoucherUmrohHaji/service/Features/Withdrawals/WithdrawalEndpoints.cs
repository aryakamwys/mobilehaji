using System.Data;
using System.Security.Claims;
using System.Security.Cryptography;
using Microsoft.EntityFrameworkCore;
using VoucherUmrohHaji.Service.Common;
using VoucherUmrohHaji.Service.Data;
using VoucherUmrohHaji.Service.Data.Entities;

namespace VoucherUmrohHaji.Service.Features.Withdrawals;

public record CreateWithdrawalRequest(long Amount, string Bank, string Account, string Holder);
public record WithdrawalDto(string Id, long Amount, string Bank, string Account, string Holder, string Status, DateTime CreatedAt);

public static class WithdrawalEndpoints
{
    public static IEndpointRouteBuilder MapWithdrawalEndpoints(this IEndpointRouteBuilder app)
    {
        // Pengajuan withdraw memindahkan uang: saldo dihold dalam transaksi Serializable dengan
        // pembacaan ulang via proyeksi skalar (pola SettlementService) — dua ajukan bersamaan
        // tidak dapat melewati saldo. Urutan validasi mengikuti Store.swift requestWithdrawal.
        app.MapPost("/api/withdrawals", async (CreateWithdrawalRequest req, ClaimsPrincipal user, AppDbContext db) =>
        {
            if (user.IsInRole("admin")) throw new DomainException("Hanya buyer yang dapat mengajukan withdraw");
            var memberId = user.MemberId();
            if (req.Amount <= 0) throw new DomainException("Nominal tidak valid atau saldo tidak mencukupi");

            await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable);
            var balance = await db.Members.Where(m => m.Id == memberId)
                .Select(m => (long?)m.Balance).FirstOrDefaultAsync()
                ?? throw new DomainException("Member tidak ditemukan");
            var bank = (req.Bank ?? string.Empty).Trim();
            var account = (req.Account ?? string.Empty).Trim();
            var holder = (req.Holder ?? string.Empty).Trim();
            if (req.Amount > balance) throw new DomainException("Nominal tidak valid atau saldo tidak mencukupi");
            if (bank.Length == 0 || account.Length < 5 || holder.Length == 0)
                throw new DomainException("Lengkapi nama bank, rekening, dan pemilik rekening");

            var withdrawal = new Withdrawal
            {
                Id = await GenerateWithdrawalIdAsync(db),
                MemberId = memberId, Amount = req.Amount,
                Bank = bank, Account = account, Holder = holder,
                Status = "pending", CreatedAt = DateTime.UtcNow
            };
            var member = await db.Members.SingleAsync(m => m.Id == memberId);
            member.Balance -= req.Amount;
            db.Withdrawals.Add(withdrawal);
            db.Ledgers.Add(new Ledger
            {
                Id = Guid.NewGuid(), MemberId = memberId, Type = "withdraw",
                Title = $"Hold withdraw ke {bank}", Amount = -req.Amount,
                OrderId = withdrawal.Id, CreatedAt = DateTime.UtcNow
            });
            await db.SaveChangesAsync();
            await tx.CommitAsync();
            return Results.Ok(new WithdrawalDto(withdrawal.Id, withdrawal.Amount, withdrawal.Bank,
                withdrawal.Account, withdrawal.Holder, withdrawal.Status, withdrawal.CreatedAt));
        }).RequireAuthorization();

        // Riwayat withdraw selalu milik pemanggil, terbaru dulu.
        app.MapGet("/api/withdrawals", async (ClaimsPrincipal user, AppDbContext db) =>
        {
            var memberId = user.MemberId();
            return Results.Ok(await db.Withdrawals.AsNoTracking()
                .Where(w => w.MemberId == memberId)
                .OrderByDescending(w => w.CreatedAt)
                .Select(w => new WithdrawalDto(w.Id, w.Amount, w.Bank, w.Account, w.Holder, w.Status, w.CreatedAt))
                .ToListAsync());
        }).RequireAuthorization();

        return app;
    }

    private static async Task<string> GenerateWithdrawalIdAsync(AppDbContext db)
    {
        const string alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
        while (true)
        {
            var id = "WD-" + new string(RandomNumberGenerator.GetItems<char>(alphabet, 10));
            if (!await db.Withdrawals.AnyAsync(w => w.Id == id)) return id;
        }
    }
}
