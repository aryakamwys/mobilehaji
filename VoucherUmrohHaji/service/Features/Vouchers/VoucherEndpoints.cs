using Microsoft.EntityFrameworkCore;
using VoucherUmrohHaji.Service.Common;
using VoucherUmrohHaji.Service.Data;
using VoucherUmrohHaji.Service.Data.Entities;

namespace VoucherUmrohHaji.Service.Features.Vouchers;

public record VoucherDto(Guid Id, string Title, long Price, long Value, bool IsActive);
public record CreateVoucherRequest(string Title, long Price, long Value);
public record UpdateVoucherRequest(string Title, long Price, long Value, bool IsActive);

public static class VoucherEndpoints
{
    public static IEndpointRouteBuilder MapVoucherEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapGet("/api/vouchers", async (AppDbContext db) =>
            await db.Vouchers.Where(v => v.IsActive)
                .Select(v => new VoucherDto(v.Id, v.Title, v.Price, v.Value, v.IsActive))
                .ToListAsync())
            .RequireAuthorization();

        app.MapPost("/api/admin/vouchers", async (CreateVoucherRequest req, AppDbContext db) =>
        {
            Validate(req.Title, req.Price, req.Value);
            var voucher = new Voucher { Id = Guid.NewGuid(), Title = req.Title.Trim(), Price = req.Price, Value = req.Value, IsActive = true };
            db.Vouchers.Add(voucher);
            await db.SaveChangesAsync();
            return Results.Created($"/api/admin/vouchers/{voucher.Id}", voucher.ToDto());
        }).RequireAuthorization(p => p.RequireRole("admin"));

        app.MapPut("/api/admin/vouchers/{id:guid}", async (Guid id, UpdateVoucherRequest req, AppDbContext db) =>
        {
            Validate(req.Title, req.Price, req.Value);
            var voucher = await db.Vouchers.FindAsync(id);
            if (voucher is null) return Results.NotFound();
            voucher.Title = req.Title.Trim();
            voucher.Price = req.Price;
            voucher.Value = req.Value;
            voucher.IsActive = req.IsActive;
            await db.SaveChangesAsync();
            return Results.Ok(voucher.ToDto());
        }).RequireAuthorization(p => p.RequireRole("admin"));

        app.MapDelete("/api/admin/vouchers/{id:guid}", async (Guid id, AppDbContext db) =>
        {
            if (await db.Orders.AnyAsync(o => o.VoucherId == id))
                return Results.Conflict(new { error = "Voucher pernah ditransaksikan. Nonaktifkan, jangan hapus." });
            var voucher = await db.Vouchers.FindAsync(id);
            if (voucher is null) return Results.NotFound();
            db.Vouchers.Remove(voucher);
            await db.SaveChangesAsync();
            return Results.NoContent();
        }).RequireAuthorization(p => p.RequireRole("admin"));

        return app;
    }

    private static void Validate(string title, long price, long value)
    {
        if (string.IsNullOrWhiteSpace(title) || price <= 0 || value <= 0)
            throw new DomainException("Judul dan nominal voucher harus valid");
    }

    private static VoucherDto ToDto(this Voucher voucher) =>
        new(voucher.Id, voucher.Title, voucher.Price, voucher.Value, voucher.IsActive);
}
