using System.Data;
using Microsoft.EntityFrameworkCore;
using VoucherUmrohHaji.Service.Data;
using VoucherUmrohHaji.Service.Data.Entities;

namespace VoucherUmrohHaji.Service.Features.Payments;

/// <summary>
/// Settlement order terbayar: kredit saldo buyer, simpan voucher milik, ledger topup,
/// dan sebar cashback MLM ke rantai upline. Idempoten — webhook Midtrans bisa datang dua kali.
/// </summary>
public class SettlementService(AppDbContext db)
{
    /// <returns>false bila order tidak ada / bukan pending (no-op idempoten); true bila settlement dieksekusi.</returns>
    public async Task<bool> SettleAsync(string orderId)
    {
        // Serializable + cek ulang status DI DALAM transaksi: dua webhook bersamaan tidak boleh
        // keduanya lolos cek "pending". Kegagalan serialisasi dibiarkan lempar → 500 → Midtrans retry.
        await using var tx = await db.Database.BeginTransactionAsync(IsolationLevel.Serializable);

        var order = await db.Orders.FirstOrDefaultAsync(o => o.Id == orderId);
        if (order is null || order.Status != "pending") return false;

        order.Status = "settlement";
        var buyer = await db.Members.SingleAsync(m => m.Id == order.MemberId);
        buyer.Balance += order.Value;
        var voucher = await db.Vouchers.SingleAsync(v => v.Id == order.VoucherId);
        db.VouchersOwned.Add(new VoucherOwned
        {
            Id = Guid.NewGuid(), MemberId = buyer.Id, Title = voucher.Title,
            Value = order.Value, OrderId = order.Id, CreatedAt = DateTime.UtcNow
        });
        TambahLedger(buyer.Id, "topup", $"Top-Up {voucher.Title}", order.Value, order.Id);

        var setting = await db.MlmSettings.AsNoTracking().SingleAsync(s => s.Id == 1);
        var rules = await db.MlmRules.AsNoTracking().OrderBy(r => r.Level).ToListAsync();
        var chain = await MuatUplineChainAsync(buyer.ParentId, rules.Count);
        foreach (var payout in MlmCalculator.ComputePayouts(order.Amount, rules, setting.DownlineStep, setting.Multiplier, chain))
        {
            var upline = await db.Members.SingleAsync(m => m.Id == payout.MemberId);
            upline.Balance += payout.Amount;
            TambahLedger(upline.Id, "mlm_cashback",
                $"Cashback Level {payout.Level} ×{payout.Factor:0.00} dari {buyer.Name}", payout.Amount, order.Id);
        }

        await db.SaveChangesAsync();
        await tx.CommitAsync();
        return true;
    }

    /// <summary>Naik dari ParentId ke root, maksimal maxLevel level (sisanya tidak dibayar).</summary>
    private async Task<List<(Guid MemberId, int Downlines)>> MuatUplineChainAsync(Guid? parentId, int maxLevel)
    {
        var chain = new List<(Guid, int)>();
        while (parentId is not null && chain.Count < maxLevel)
        {
            var upline = await db.Members.AsNoTracking().SingleAsync(m => m.Id == parentId);
            chain.Add((upline.Id, upline.Downlines));
            parentId = upline.ParentId;
        }
        return chain;
    }

    private void TambahLedger(Guid memberId, string type, string title, long amount, string orderId) =>
        db.Ledgers.Add(new Ledger
        {
            Id = Guid.NewGuid(), MemberId = memberId, Type = type, Title = title,
            Amount = amount, OrderId = orderId, CreatedAt = DateTime.UtcNow
        });
}
