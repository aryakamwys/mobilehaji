using System.Security.Claims;
using System.Security.Cryptography;
using Microsoft.EntityFrameworkCore;
using VoucherUmrohHaji.Service.Common;
using VoucherUmrohHaji.Service.Data;
using VoucherUmrohHaji.Service.Data.Entities;

namespace VoucherUmrohHaji.Service.Features.Orders;

public record CreateOrderRequest(Guid VoucherId);
public record CreateOrderResponse(string OrderId, long Amount, long Value, string Status, string? SnapToken, string SnapUrl);
public record OrderListItem(string OrderId, string VoucherTitle, long Amount, long Value, string Status, DateTime CreatedAt);
public record CancelOrderResponse(string OrderId, string Status);

public static class OrderEndpoints
{
    public static IEndpointRouteBuilder MapOrderEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapPost("/api/orders", async (CreateOrderRequest req, ClaimsPrincipal user, AppDbContext db, IMidtransClient midtrans) =>
        {
            if (user.IsInRole("admin")) throw new DomainException("Admin tidak dapat membuat order");
            var voucher = await db.Vouchers.FindAsync(req.VoucherId);
            if (voucher is null || !voucher.IsActive) throw new DomainException("Voucher tidak tersedia");

            var order = new Order
            {
                Id = await GenerateOrderIdAsync(db),
                MemberId = user.MemberId(),
                VoucherId = voucher.Id,
                Amount = voucher.Price,
                Value = voucher.Value,
                Status = "pending",
                CreatedAt = DateTime.UtcNow
            };
            // snap token lebih dulu: bila Midtrans gagal (DomainException) tidak ada order menggantung
            var (token, redirectUrl) = await midtrans.CreateSnapTransactionAsync(order.Id, order.Amount);
            order.SnapToken = token;
            db.Orders.Add(order);
            await db.SaveChangesAsync();
            return Results.Ok(new CreateOrderResponse(order.Id, order.Amount, order.Value, order.Status, order.SnapToken, redirectUrl));
        }).RequireAuthorization();

        app.MapGet("/api/orders", async (ClaimsPrincipal user, AppDbContext db) =>
        {
            var memberId = user.MemberId();
            // ponytail: satu halaman (20 terbaru) tanpa parameter paging — tambahkan ?page= bila butuh riwayat panjang
            return Results.Ok(await (
                from o in db.Orders
                join v in db.Vouchers on o.VoucherId equals v.Id
                where o.MemberId == memberId
                orderby o.CreatedAt descending, o.Id descending
                select new OrderListItem(o.Id, v.Title, o.Amount, o.Value, o.Status, o.CreatedAt)
            ).Take(20).ToListAsync());
        }).RequireAuthorization();

        app.MapPost("/api/orders/{id}/cancel", async (string id, ClaimsPrincipal user, AppDbContext db) =>
        {
            // order milik orang lain sama saja dengan tidak ada → 404, jangan bocorkan keberadaannya
            var order = await db.Orders.FindAsync(id);
            if (order is null || order.MemberId != user.MemberId()) return Results.NotFound();
            if (order.Status != "pending") throw new DomainException("Hanya order berstatus pending yang dapat dibatalkan");
            order.Status = "cancel";
            await db.SaveChangesAsync();
            return Results.Ok(new CancelOrderResponse(order.Id, order.Status));
        }).RequireAuthorization();

        return app;
    }

    private static async Task<string> GenerateOrderIdAsync(AppDbContext db)
    {
        const string alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
        while (true)
        {
            var id = "ORD-" + new string(RandomNumberGenerator.GetItems<char>(alphabet, 10));
            if (!await db.Orders.AnyAsync(o => o.Id == id)) return id;
        }
    }
}
