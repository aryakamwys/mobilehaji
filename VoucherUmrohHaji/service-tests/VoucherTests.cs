using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using Microsoft.Extensions.DependencyInjection;
using VoucherUmrohHaji.Service.Data;
using VoucherUmrohHaji.Service.Data.Entities;

public class VoucherTests(TestApiFactory factory) : IClassFixture<TestApiFactory>
{
    private static async Task LoginAdminAsync(HttpClient client)
    {
        var res = await client.PostAsJsonAsync("/api/auth/login", new { email = "admin@haji.local", password = "Admin#2026" });
        var auth = await res.Content.ReadFromJsonAsync<AuthResponse>();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", auth!.AccessToken);
    }

    [Fact]
    public async Task Buyer_melihat_voucher_aktif_saja()
    {
        var admin = factory.CreateClient();
        await LoginAdminAsync(admin);
        var aktif = await (await admin.PostAsJsonAsync("/api/admin/vouchers",
            new { title = "Voucher Tes Aktif", price = 50_000L, value = 55_000L })).Content.ReadFromJsonAsync<VoucherDto>();
        var nonaktif = await (await admin.PostAsJsonAsync("/api/admin/vouchers",
            new { title = "Voucher Tes Nonaktif", price = 60_000L, value = 65_000L })).Content.ReadFromJsonAsync<VoucherDto>();
        var put = await admin.PutAsJsonAsync($"/api/admin/vouchers/{nonaktif!.Id}",
            new { title = "Voucher Tes Nonaktif", price = 60_000L, value = 65_000L, isActive = false });
        Assert.True(put.IsSuccessStatusCode, await put.Content.ReadAsStringAsync());

        var buyer = factory.CreateClient();
        var reg = await buyer.PostAsJsonAsync("/api/auth/register",
            new { name = "Buyer Voucher", email = "buyer.voucher@test.id", password = "Rahasia123" });
        var buyerAuth = await reg.Content.ReadFromJsonAsync<AuthResponse>();
        buyer.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", buyerAuth!.AccessToken);

        var list = await buyer.GetFromJsonAsync<List<VoucherDto>>("/api/vouchers");
        Assert.NotNull(list);
        Assert.All(list!, v => Assert.True(v.IsActive));
        Assert.Contains(list!, v => v.Id == aktif!.Id);
        Assert.DoesNotContain(list!, v => v.Id == nonaktif.Id);
    }

    [Fact]
    public async Task Nonadmin_CRUD_403()
    {
        var anon = factory.CreateClient();
        Assert.Equal(HttpStatusCode.Unauthorized, (await anon.GetAsync("/api/vouchers")).StatusCode);

        var buyer = factory.CreateClient();
        var reg = await buyer.PostAsJsonAsync("/api/auth/register",
            new { name = "Buyer CRUD", email = "buyer.crud@test.id", password = "Rahasia123" });
        var auth = await reg.Content.ReadFromJsonAsync<AuthResponse>();
        buyer.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", auth!.AccessToken);

        var post = await buyer.PostAsJsonAsync("/api/admin/vouchers", new { title = "Boleh?", price = 10_000L, value = 10_000L });
        Assert.Equal(HttpStatusCode.Forbidden, post.StatusCode);
        var del = await buyer.DeleteAsync($"/api/admin/vouchers/{Guid.NewGuid()}");
        Assert.Equal(HttpStatusCode.Forbidden, del.StatusCode);
    }

    [Fact]
    public async Task Hapus_voucher_yang_pernah_diorder_409()
    {
        var admin = factory.CreateClient();
        await LoginAdminAsync(admin);
        var voucher = await (await admin.PostAsJsonAsync("/api/admin/vouchers",
            new { title = "Voucher Bertransaksi", price = 25_000L, value = 27_000L })).Content.ReadFromJsonAsync<VoucherDto>();

        using (var scope = factory.CreateAdminScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            db.Orders.Add(new Order { Id = "ORDER-TEST-1", MemberId = Guid.NewGuid(),
                VoucherId = voucher!.Id, Amount = 25_000, Value = 27_000, Status = "paid" });
            await db.SaveChangesAsync();
        }

        var del = await admin.DeleteAsync($"/api/admin/vouchers/{voucher!.Id}");
        Assert.Equal(HttpStatusCode.Conflict, del.StatusCode);
        Assert.Contains("pernah ditransaksikan", await del.Content.ReadAsStringAsync());
    }

    [Fact]
    public async Task Validasi_price_value_harus_positif_400()
    {
        var admin = factory.CreateClient();
        await LoginAdminAsync(admin);
        foreach (var (title, price, value) in new[]
                 { ("Voucher", 0L, 10_000L), ("Voucher", 10_000L, 0L), ("  ", 10_000L, 10_000L) })
        {
            var res = await admin.PostAsJsonAsync("/api/admin/vouchers", new { title, price, value });
            Assert.Equal(HttpStatusCode.BadRequest, res.StatusCode);
        }
        var put = await admin.PutAsJsonAsync($"/api/admin/vouchers/{Guid.NewGuid()}",
            new { title = "Voucher", price = 0L, value = 10_000L, isActive = true });
        Assert.Equal(HttpStatusCode.BadRequest, put.StatusCode);
    }
}
public record VoucherDto(Guid Id, string Title, long Price, long Value, bool IsActive);
