namespace VoucherUmrohHaji.Service.Common;

/// <summary>Status transaksi dari GET /v2/{orderId}/status Midtrans.</summary>
public record MidtransTransactionStatus(string TransactionStatus, string? FraudStatus, string StatusCode, string GrossAmount);

/// <summary>Seam pengganti saat test (FakeMidtransClient) — jangan diubah kontraknya: webhook Task 5 memakai GetTransactionStatusAsync.</summary>
public interface IMidtransClient
{
    Task<(string Token, string RedirectUrl)> CreateSnapTransactionAsync(string orderId, decimal grossAmount);
    Task<MidtransTransactionStatus> GetTransactionStatusAsync(string orderId);
}
