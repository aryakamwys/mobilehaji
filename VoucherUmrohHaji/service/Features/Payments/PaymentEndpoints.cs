using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json.Serialization;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using VoucherUmrohHaji.Service.Common;
using VoucherUmrohHaji.Service.Data;
using VoucherUmrohHaji.Service.Data.Entities;

namespace VoucherUmrohHaji.Service.Features.Payments;

/// <summary>Body notifikasi Midtrans — nama properti JSON snake_case, gross_amount string apa adanya (dipakai signature).</summary>
public record MidtransNotification(
    [property: JsonPropertyName("order_id")] string OrderId,
    [property: JsonPropertyName("status_code")] string StatusCode,
    [property: JsonPropertyName("gross_amount")] string GrossAmount,
    [property: JsonPropertyName("transaction_status")] string TransactionStatus,
    [property: JsonPropertyName("fraud_status")] string? FraudStatus,
    [property: JsonPropertyName("signature_key")] string? SignatureKey);

public record OrderStatusResponse(string OrderId, string Status);

public static class PaymentEndpoints
{
    public static IEndpointRouteBuilder MapPaymentEndpoints(this IEndpointRouteBuilder app)
    {
        // Webhook dipanggil server Midtrans — anonim, keandalan dari signature SHA256.
        app.MapPost("/api/webhooks/midtrans", async (
            MidtransNotification notif, AppDbContext db, SettlementService settlement,
            IOptions<MidtransOptions> options, ILogger<Program> logger) =>
        {
            // signature = SHA256(order_id + status_code + gross_amount + serverKey) atas string apa adanya
            var payload = notif.OrderId + notif.StatusCode + notif.GrossAmount + options.Value.ServerKey;
            var expected = Convert.ToHexString(SHA256.HashData(Encoding.ASCII.GetBytes(payload)));
            if (!string.Equals(expected, notif.SignatureKey, StringComparison.OrdinalIgnoreCase))
                return Results.BadRequest(new { error = "Signature tidak valid" });

            var order = await db.Orders.FindAsync(notif.OrderId);
            if (order is null)
            {
                logger.LogWarning("Webhook Midtrans untuk order tidak dikenal: {OrderId}", notif.OrderId);
                return Results.Ok(); // 200 agar Midtrans tidak retry tanpa henti
            }

            await TerapkanStatusAsync(order, notif.TransactionStatus, notif.FraudStatus, db, settlement);
            return Results.Ok();
        });

        app.MapGet("/api/orders/{id}/status", async (
            string id, ClaimsPrincipal user, AppDbContext db, IMidtransClient midtrans, SettlementService settlement) =>
        {
            var order = await db.Orders.FindAsync(id);
            if (order is null || (order.MemberId != user.MemberId() && !user.IsInRole("admin")))
                return Results.NotFound(); // order milik orang lain sama saja dengan tidak ada

            if (order.Status == "pending")
            {
                var status = await midtrans.GetTransactionStatusAsync(order.Id); // gagal → DomainException → 400
                await TerapkanStatusAsync(order, status.TransactionStatus, status.FraudStatus, db, settlement);
            }
            return Results.Ok(new OrderStatusResponse(order.Id, order.Status));
        }).RequireAuthorization();

        return app;
    }

    /// <summary>Pemetaan status Midtrans → status order; dipakai webhook dan inquiry agar konsisten.</summary>
    private static async Task TerapkanStatusAsync(
        Order order, string transactionStatus, string? fraudStatus, AppDbContext db, SettlementService settlement)
    {
        switch (transactionStatus)
        {
            case "settlement":
            case "capture" when fraudStatus == "accept":
                await settlement.SettleAsync(order.Id);
                break;
            case "cancel" or "deny":
                if (order.Status == "pending") { order.Status = "cancel"; await db.SaveChangesAsync(); }
                break;
            case "expire":
                if (order.Status == "pending") { order.Status = "expire"; await db.SaveChangesAsync(); }
                break;
            // status lain (pending, deny pada order non-pending, dsb.) → no-op
        }
    }
}
