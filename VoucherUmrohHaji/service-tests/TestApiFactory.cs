using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using VoucherUmrohHaji.Service.Data;

// Adaptasi dari brief: EF Core 8+ meregistrasi tiap opsi AddDbContext sebagai
// IDbContextOptionsConfiguration<TContext>, jadi menghapus DbContextOptions saja
// masih menyisakan konfigurasi Npgsql. Hapus semua deskriptor terkait, lalu
// daftarkan ulang dengan Sqlite in-memory.
public class TestApiFactory : WebApplicationFactory<Program>
{
    private readonly SqliteConnection _connection = new("DataSource=:memory:");
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Development");
        builder.UseSetting("AdminUser:Password", "Admin#2026");
        builder.UseSetting("Jwt:Key", "test-key-yang-cukup-panjang-untuk-hmac-256");
        builder.ConfigureServices(s =>
        {
            s.RemoveAll(typeof(DbContextOptions<AppDbContext>));
            s.RemoveAll(typeof(DbContextOptions));
            s.RemoveAll(typeof(IDbContextOptionsConfiguration<AppDbContext>));
            _connection.Open();
            s.AddDbContext<AppDbContext>(o => o.UseSqlite(_connection)
                // snapshot migrasi ditulis untuk Npgsql; saat berjalan di SQLite
                // diff provider memicu warning ini — abaikan agar migrasi tetap terpasang
                .ConfigureWarnings(w => w.Ignore(RelationalEventId.PendingModelChangesWarning)));
        });
    }
}
