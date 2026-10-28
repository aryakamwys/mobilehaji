using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using VoucherUmrohHaji.Service.Common;

public class OrderTests(TestApiFactory factory) : IClassFixture<TestApiFactory>
{
    // login dibatasi 5/menit per IP — cache token admin agar test tidak menyentuh limiter
    // (static: satu fixture/factory per kelas, DB admin sama untuk semua instance test)
    private static string? _adminToken;

    private async Task LoginAdminAsync(HttpClient client)
    {
        if (_adminToken is null)
        {
            var res = await client.PostAsJsonAsync("/api/auth/login", new { email = "admin@haji.local", password = "Admin#2026" });
            var auth = await res.Content.ReadFromJsonAsync<AuthResponse>();
            _adminToken = auth!.AccessToken;
        }
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", _adminToken);
    }

    /// <summary>Buyer terautentikasi + satu voucher aktif (harga 50.000, nilai 55.000).</summary>
    private async Task<(HttpClient Buyer, Guid VoucherId)> CreateBuyerWithVoucherAsync(string name)
    {
        var admin = factory.CreateClient();
        await LoginAdminAsync(admin);
        var voucher = await (await admin.PostAsJsonAsync("/api/admin/vouchers",
            new { title = $"Voucher Order {name}", price = 50_000L, value = 55_000L }))
            .Content.ReadFromJsonAsync<VoucherDto>();

        var buyer = factory.CreateClient();
        var reg = await buyer.PostAsJsonAsync("/api/auth/register",
            new { name, email = $"buyer.{name.ToLowerInvariant().Replace(' ', '.')}@test.id", password = "Rahasia123" });
        var auth = await reg.Content.ReadFromJsonAsync<AuthResponse>();
        buyer.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", auth!.AccessToken);
        return (buyer, voucher!.Id);
    }

    [Fact]
    public async Task Buat_order_pending_dengan_snap_token_dari_fake_midtrans()
    {
        var (buyer, voucherId) = await CreateBuyerWithVoucherAsync("Buyer Order Satu");
        var res = await buyer.PostAsJsonAsync("/api/orders", new { voucherId });
        Assert.True(res.IsSuccessStatusCode, await res.Content.ReadAsStringAsync());

        var order = await res.Content.ReadFromJsonAsync<CreateOrderResponse>();
        Assert.NotNull(order);
        Assert.StartsWith("ORD-", order!.OrderId);
        Assert.Equal(14, order.OrderId.Length); // "ORD-" + 10 karakter
        Assert.Equal(50_000L, order.Amount);
        Assert.Equal(55_000L, order.Value);
        Assert.Equal("pending", order.Status);
        Assert.Equal("fake-snap-token", order.SnapToken);
        Assert.Equal("https://app.sandbox.midtrans.com/snap/v2/fake", order.SnapUrl);
    }

    [Fact]
    public async Task Daftar_order_milik_sendiri_terbaru_dulu_order_orang_lain_tersembunyi()
    {
        var (buyer, voucherId) = await CreateBuyerWithVoucherAsync("Buyer Order Dua");
        var (lain, _) = await CreateBuyerWithVoucherAsync("Buyer Order Lain");

        var orderLain = await (await lain.PostAsJsonAsync("/api/orders", new { voucherId }))
            .Content.ReadFromJsonAsync<CreateOrderResponse>();
        var pertama = await (await buyer.PostAsJsonAsync("/api/orders", new { voucherId }))
            .Content.ReadFromJsonAsync<CreateOrderResponse>();
        var kedua = await (await buyer.PostAsJsonAsync("/api/orders", new { voucherId }))
            .Content.ReadFromJsonAsync<CreateOrderResponse>();

        var list = await buyer.GetFromJsonAsync<List<OrderListResponse>>("/api/orders");
        Assert.NotNull(list);
        Assert.Equal(2, list!.Count);
        Assert.Equal(kedua!.OrderId, list[0].OrderId); // terbaru dulu
        Assert.Equal(pertama!.OrderId, list[1].OrderId);
        Assert.DoesNotContain(list, o => o.OrderId == orderLain!.OrderId);
        Assert.Equal("Voucher Order Buyer Order Dua", list[0].VoucherTitle);
        Assert.Equal("pending", list[0].Status);
    }

    [Fact]
    public async Task Cancel_order_pending_lalu_cancel_lagi_400()
    {
        var (buyer, voucherId) = await CreateBuyerWithVoucherAsync("Buyer Order Tiga");
        var order = await (await buyer.PostAsJsonAsync("/api/orders", new { voucherId }))
            .Content.ReadFromJsonAsync<CreateOrderResponse>();

        var cancel = await buyer.PostAsJsonAsync($"/api/orders/{order!.OrderId}/cancel", new { });
        Assert.True(cancel.IsSuccessStatusCode, await cancel.Content.ReadAsStringAsync());

        var list = await buyer.GetFromJsonAsync<List<OrderListResponse>>("/api/orders");
        Assert.Equal("cancel", list!.Single(o => o.OrderId == order.OrderId).Status);

        var ulang = await buyer.PostAsJsonAsync($"/api/orders/{order.OrderId}/cancel", new { });
        Assert.Equal(HttpStatusCode.BadRequest, ulang.StatusCode);
    }

    [Fact]
    public async Task Cancel_order_milik_orang_lain_404_dan_status_tidak_berubah()
    {
        var (buyer, _) = await CreateBuyerWithVoucherAsync("Buyer Order Empat");
        var (lain, voucherId) = await CreateBuyerWithVoucherAsync("Buyer Order Lima");
        var order = await (await lain.PostAsJsonAsync("/api/orders", new { voucherId }))
            .Content.ReadFromJsonAsync<CreateOrderResponse>();

        var res = await buyer.PostAsJsonAsync($"/api/orders/{order!.OrderId}/cancel", new { });
        Assert.Equal(HttpStatusCode.NotFound, res.StatusCode);

        var list = await lain.GetFromJsonAsync<List<OrderListResponse>>("/api/orders");
        Assert.Equal("pending", list!.Single(o => o.OrderId == order.OrderId).Status);
    }

    [Fact]
    public async Task Admin_ditolak_dan_orders_wajib_login()
    {
        var admin = factory.CreateClient();
        await LoginAdminAsync(admin);
        var byAdmin = await admin.PostAsJsonAsync("/api/orders", new { voucherId = Guid.NewGuid() });
        Assert.Equal(HttpStatusCode.BadRequest, byAdmin.StatusCode);
        Assert.Contains("Admin tidak dapat membuat order", await byAdmin.Content.ReadAsStringAsync());

        Assert.Equal(HttpStatusCode.Unauthorized,
            (await factory.CreateClient().GetAsync("/api/orders")).StatusCode);
    }

    [Fact]
    public async Task Voucher_tidak_ada_atau_nonaktif_ditolak_400()
    {
        var admin = factory.CreateClient();
        await LoginAdminAsync(admin);
        var voucher = await (await admin.PostAsJsonAsync("/api/admin/vouchers",
            new { title = "Voucher Order Nonaktif", price = 10_000L, value = 11_000L }))
            .Content.ReadFromJsonAsync<VoucherDto>();
        await admin.PutAsJsonAsync($"/api/admin/vouchers/{voucher!.Id}",
            new { title = "Voucher Order Nonaktif", price = 10_000L, value = 11_000L, isActive = false });

        var (buyer, _) = await CreateBuyerWithVoucherAsync("Buyer Order Enam");
        var nonaktif = await buyer.PostAsJsonAsync("/api/orders", new { voucherId = voucher.Id });
        Assert.Equal(HttpStatusCode.BadRequest, nonaktif.StatusCode);

        var tidakAda = await buyer.PostAsJsonAsync("/api/orders", new { voucherId = Guid.NewGuid() });
        Assert.Equal(HttpStatusCode.BadRequest, tidakAda.StatusCode);
    }
}

public class FakeMidtransClient : IMidtransClient
{
    public const string SnapToken = "fake-snap-token";
    public const string SnapUrl = "https://app.sandbox.midtrans.com/snap/v2/fake";

    public Task<(string Token, string RedirectUrl)> CreateSnapTransactionAsync(string orderId, decimal grossAmount)
        => Task.FromResult((Token: SnapToken, RedirectUrl: SnapUrl));

    public Task<MidtransTransactionStatus> GetTransactionStatusAsync(string orderId)
        => Task.FromResult(new MidtransTransactionStatus("pending", "accept", "200", "50000.00"));
}

public record CreateOrderResponse(string OrderId, long Amount, long Value, string Status, string? SnapToken, string SnapUrl);
public record OrderListResponse(string OrderId, string VoucherTitle, long Amount, long Value, string Status, DateTime CreatedAt);
