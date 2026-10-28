using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using VoucherUmrohHaji.Service.Common;
using VoucherUmrohHaji.Service.Data;

namespace VoucherUmrohHaji.Service.Features.Wallet;

public record WalletResponse(long Balance, List<OwnedVoucherItem> Owned, List<LedgerItem> Ledger);
public record OwnedVoucherItem(string Title, long Value, string OrderId, DateTime CreatedAt);
public record LedgerItem(string Type, string Title, long Amount, string OrderId, DateTime CreatedAt);

public static class WalletEndpoints
{
    public static IEndpointRouteBuilder MapWalletEndpoints(this IEndpointRouteBuilder app)
    {
        // Wallet selalu milik pemanggil (admin pun hanya melihat wallet sendiri) —
        // semua query memfilter MemberId di sisi DB, urut terbaru dulu, ledger maksimal 50.
        app.MapGet("/api/wallet", async (ClaimsPrincipal user, AppDbContext db) =>
        {
            var memberId = user.MemberId();
            var balance = await db.Members.AsNoTracking()
                .Where(m => m.Id == memberId).Select(m => m.Balance).FirstAsync();
            var owned = await db.VouchersOwned.AsNoTracking()
                .Where(v => v.MemberId == memberId)
                .OrderByDescending(v => v.CreatedAt)
                .Select(v => new OwnedVoucherItem(v.Title, v.Value, v.OrderId, v.CreatedAt))
                .ToListAsync();
            var ledger = await db.Ledgers.AsNoTracking()
                .Where(l => l.MemberId == memberId)
                .OrderByDescending(l => l.CreatedAt)
                .Take(50)
                .Select(l => new LedgerItem(l.Type, l.Title, l.Amount, l.OrderId, l.CreatedAt))
                .ToListAsync();
            return Results.Ok(new WalletResponse(balance, owned, ledger));
        }).RequireAuthorization().WithTags("Wallet").WithSummary("Saldo, voucher dimiliki, mutasi");

        return app;
    }
}
