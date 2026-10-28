using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace VoucherUmrohHaji.Service.Common;

/// <summary>
/// Klien HTTP Midtrans Snap/API (Basic auth serverKey:). Semua kegagalan — jaringan,
/// status HTTP gagal, maupun body tak terduga — diterjemahkan menjadi DomainException
/// generik; detail HTTP hanya masuk log agar tidak bocor ke klien. Cancellation
/// (termasuk timeout HttpClient) diteruskan apa adanya, bukan DomainException.
/// </summary>
public class MidtransClient(HttpClient http, IOptions<MidtransOptions> options, ILogger<MidtransClient> logger) : IMidtransClient
{
    private readonly MidtransOptions _options = options.Value;

    public Task<(string Token, string RedirectUrl)> CreateSnapTransactionAsync(string orderId, decimal grossAmount) =>
        CallAsync(HttpMethod.Post, "/snap/v1/transactions",
            new { transaction_details = new { order_id = orderId, gross_amount = grossAmount } },
            root =>
            {
                var token = root.GetProperty("token").GetString()
                    ?? throw new InvalidOperationException("Midtrans tidak mengembalikan token");
                return (Token: token, RedirectUrl: $"{BaseUrl}/snap/v2/{token}");
            });

    public Task<MidtransTransactionStatus> GetTransactionStatusAsync(string orderId) =>
        CallAsync(HttpMethod.Get, $"/v2/{orderId}/status", null,
            root => new MidtransTransactionStatus(
                TransactionStatus: root.GetProperty("transaction_status").GetString() ?? string.Empty,
                FraudStatus: root.TryGetProperty("fraud_status", out var fraud) ? fraud.GetString() : null,
                StatusCode: root.GetProperty("status_code").GetString() ?? string.Empty,
                GrossAmount: root.GetProperty("gross_amount").GetString() ?? string.Empty));

    private async Task<T> CallAsync<T>(HttpMethod method, string path, object? payload, Func<JsonElement, T> map)
    {
        try
        {
            using var request = new HttpRequestMessage(method, BaseUrl + path);
            request.Headers.Authorization = new AuthenticationHeaderValue("Basic",
                Convert.ToBase64String(Encoding.UTF8.GetBytes($"{_options.ServerKey}:")));
            if (payload is not null) request.Content = JsonContent.Create(payload);
            using var response = await http.SendAsync(request);
            response.EnsureSuccessStatusCode();
            using var doc = await JsonDocument.ParseAsync(await response.Content.ReadAsStreamAsync());
            return map(doc.RootElement);
        }
        catch (Exception ex) when (ex is not (DomainException or OperationCanceledException))
        {
            logger.LogWarning(ex, "Panggilan Midtrans {Method} {Path} gagal", method, path);
            throw new DomainException("Layanan pembayaran sedang tidak tersedia");
        }
    }

    private string BaseUrl => _options.IsProduction ? "https://app.midtrans.com" : "https://app.sandbox.midtrans.com";
}
