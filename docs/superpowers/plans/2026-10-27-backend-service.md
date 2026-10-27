# Backend Service Implementation Plan (VoucherUmrohHaji)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Backend ASP.NET Core Minimal API (.NET 10) untuk aplikasi voucher Umroh/Haji: auth JWT, katalog voucher, order + pembayaran Midtrans Snap, settlement MLM idempotent via webhook, dompet, referral, withdrawal dengan approval admin.

**Architecture:** Minimal API dengan folder per fitur (`Features/`), EF Core + PostgreSQL untuk produksi, SQLite in-memory untuk integration test. Semua logic uang di server; settlement berjalan dalam satu DB transaction dengan guard status (idempotent). Midtrans diakses lewat `IMidtransClient` (Http client, server-side).

**Tech Stack:** .NET 10, ASP.NET Core Minimal API, EF Core 10 + Npgsql, BCrypt.Net-Next, JwtBearer, xUnit + Microsoft.AspNetCore.Mvc.Testing + EF Core Sqlite.

**Spec:** `docs/superpowers/specs/2026-10-27-voucher-production-design.md` (baca sebelum eksekusi — plan ini argumen dari spec itu).

## Global Constraints

- Target framework `net10.0`, project `VoucherUmrohHaji/service/service.csproj`, C# conventions sesuai CLAUDE.md (PascalCase, `_camelCase` fields, `Async` suffix, ≤300 baris/file).
- Uang: disimpan `long` (Rupiah tanpa sen), **semua aritmetika uang dalam `decimal`** lalu dibulatkan ke `long`. Persen & multiplier: `decimal`.
- Timestamp: `DateTime.UtcNow`, disimpan UTC.
- Nama endpoint prefix `/api`. Response error: `{ "error": "pesan" }` dengan status semantik (400/401/403/404/409).
- Secret (Midtrans server key, JWT key, password admin seed) via `dotnet user-secrets` / environment variable — **tidak di-commit**. Sandbox Midtrans: `SB-Mid-server-…`.
- Commit: Conventional Commits, satu task = satu commit, build + test hijau sebelum commit, push ke `origin main` tiap task (disepakati user).
- Jangan commit `bin/`, `obj/`. `service.exe` mungkin berjalan — hentikan dulu sebelum build (`taskkill //IM service.exe //F` hanya bila build gagal karena file lock).
- Bahasa pesan error & judul ledger: Indonesia (sama dengan demo Swift).

## Konvensi kode yang dipakai semua task

- Exception domain: `Common/DomainException.cs` — `public class DomainException(string message) : Exception(message);` ditangani `Common/DomainExceptionHandler.cs` (IExceptionHandler .NET 8+) → 400 `{ "error": message }`. Registrasi di Program.cs: `builder.Services.AddExceptionHandler<DomainExceptionHandler>(); builder.Services.AddProblemDetails(); app.UseExceptionHandler();` — `AddProblemDetails()` WAJIB: `UseExceptionHandler()` tanpa `IProblemDetailsService` terdaftar melempar `InvalidOperationException` saat startup di .NET 8+.
- Struktur endpoint: `Features/<Nama>/<Nama>Endpoints.cs` dengan `public static class XEndpoints { public static void MapXEndpoints(this IEndpointRouteBuilder app) }`, dipanggil `app.MapAuthEndpoints()` dst dari Program.cs.
- DTO request/response: record di file yang sama dengan endpoints-nya.
- Autentikasi endpoint: `.RequireAuthorization()` dan untuk admin `.RequireAuthorization(p => p.RequireRole("admin"))`.
- Claim member saat ini: extension `Common/ClaimsPrincipalExtensions.cs` — `public static Guid MemberId(this ClaimsPrincipal user)` → `Guid.Parse(user.FindFirstValue(ClaimTypes.NameIdentifier)!)`.

---

### Task 1: Scaffold — Entitas, DbContext, Migrasi, Seed, Health

**Files:**
- Create: `VoucherUmrohHaji/service/Data/Entities/Member.cs`, `Voucher.cs`, `Order.cs`, `VoucherOwned.cs`, `Ledger.cs`, `Withdrawal.cs`, `MlmRule.cs`, `MlmSetting.cs`, `RefreshToken.cs`
- Create: `VoucherUmrohHaji/service/Data/AppDbContext.cs`
- Create: `VoucherUmrohHaji/service/Data/SeedData.cs`
- Create: `VoucherUmrohHaji/service/Common/DomainException.cs`, `Common/DomainExceptionHandler.cs`
- Modify: `VoucherUmrohHaji/service/Program.cs`
- Modify: `VoucherUmrohHaji/service/service.csproj` (packages)
- Modify: `VoucherUmrohHaji/service/appsettings.Development.json` (connection string)

**Interfaces (dipakai task berikutnya):**
- `AppDbContext` DbSets: `Members`, `Vouchers`, `Orders`, `VouchersOwned`, `Ledgers`, `Withdrawals`, `MlmRules`, `MlmSettings`, `RefreshTokens` — semua `DbSet<T>`.
- Entitas (nama properti persis): `Member(Id Guid, Name string, Email string, PasswordHash string, Role string, ReferralCode string, ParentId Guid?, Balance long, Downlines int, CreatedAt DateTime)` · `Voucher(Id Guid, Title string, Price long, Value long, IsActive bool)` · `Order(Id string, MemberId Guid, VoucherId Guid, Amount long, Value long, Status string, SnapToken string?, CreatedAt DateTime)` · `VoucherOwned(Id Guid, MemberId Guid, Title string, Value long, OrderId string, CreatedAt DateTime)` · `Ledger(Id Guid, MemberId Guid, Type string, Title string, Amount long, OrderId string, CreatedAt DateTime)` · `Withdrawal(Id string, MemberId Guid, Amount long, Bank string, Account string, Holder string, Status string, CreatedAt DateTime)` · `MlmRule(Level int PK, Percentage decimal)` · `MlmSetting(Id int PK selalu 1, DownlineStep int, Multiplier decimal)` · `RefreshToken(Id Guid, MemberId Guid, TokenHash string, ExpiresAt DateTime, Revoked bool, CreatedAt DateTime)`
- `SeedData.InitializeAsync(AppDbContext db, IConfiguration config)` — idempotent.

- [ ] **Step 1: Tambah packages**

```bash
cd VoucherUmrohHaji/service
dotnet add package Npgsql.EntityFrameworkCore.PostgreSQL
dotnet add package Microsoft.EntityFrameworkCore.Design
```

- [ ] **Step 2: Buat 9 file entitas** — properti persis seperti blok Interfaces di atas, satu class per file, tanpa attribute. Contoh `Member.cs` (yang lain polanya sama):

```csharp
namespace VoucherUmrohHaji.Service.Data.Entities;

public class Member
{
    public Guid Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string PasswordHash { get; set; } = string.Empty;
    public string Role { get; set; } = "buyer";
    public string ReferralCode { get; set; } = string.Empty;
    public Guid? ParentId { get; set; }
    public long Balance { get; set; }
    public int Downlines { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
```

- [ ] **Step 3: AppDbContext.cs** (unique index + precision):

```csharp
using Microsoft.EntityFrameworkCore;
using VoucherUmrohHaji.Service.Data.Entities;

namespace VoucherUmrohHaji.Service.Data;

public class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    public DbSet<Member> Members => Set<Member>();
    public DbSet<Voucher> Vouchers => Set<Voucher>();
    public DbSet<Order> Orders => Set<Order>();
    public DbSet<VoucherOwned> VouchersOwned => Set<VoucherOwned>();
    public DbSet<Ledger> Ledgers => Set<Ledger>();
    public DbSet<Withdrawal> Withdrawals => Set<Withdrawal>();
    public DbSet<MlmRule> MlmRules => Set<MlmRule>();
    public DbSet<MlmSetting> MlmSettings => Set<MlmSetting>();
    public DbSet<RefreshToken> RefreshTokens => Set<RefreshToken>();

    protected override void OnModelCreating(ModelBuilder b)
    {
        b.Entity<Member>(e => { e.HasIndex(m => m.Email).IsUnique(); e.HasIndex(m => m.ReferralCode).IsUnique(); });
        b.Entity<Order>().HasIndex(o => o.MemberId);
        b.Entity<Ledger>().HasIndex(l => l.MemberId);
        b.Entity<RefreshToken>().HasIndex(t => t.TokenHash).IsUnique();
        b.Entity<MlmRule>().HasKey(r => r.Level);
        b.Entity<MlmSetting>().HasKey(s => s.Id);
        b.Entity<MlmRule>().Property(r => r.Percentage).HasPrecision(5, 2);
        b.Entity<MlmSetting>().Property(s => s.Multiplier).HasPrecision(5, 2);
    }
}
```

- [ ] **Step 4: DomainException + handler** (persis blok Konvensi kode).

- [ ] **Step 5: SeedData.cs** — admin dari config, voucher & rules sesuai seed Swift:

```csharp
using Microsoft.EntityFrameworkCore;
using VoucherUmrohHaji.Service.Data.Entities;

namespace VoucherUmrohHaji.Service.Data;

public static class SeedData
{
    public static async Task InitializeAsync(AppDbContext db, IConfiguration config)
    {
        await db.Database.MigrateAsync();
        if (await db.Members.AnyAsync()) return;

        var adminEmail = config["AdminUser:Email"] ?? "admin@haji.local";
        var adminPassword = config["AdminUser:Password"] ?? throw new InvalidOperationException("Set AdminUser:Password (user-secrets/env).");
        db.Members.Add(new Member { Id = Guid.NewGuid(), Name = "Administrator", Email = adminEmail.ToLowerInvariant(),
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(adminPassword), Role = "admin", ReferralCode = "ADMIN-HQ" });
        db.Vouchers.AddRange(
            new Voucher { Id = Guid.NewGuid(), Title = "Voucher Reguler 100K", Price = 100_000, Value = 100_000, IsActive = true },
            new Voucher { Id = Guid.NewGuid(), Title = "Voucher Gold 500K", Price = 500_000, Value = 525_000, IsActive = true },
            new Voucher { Id = Guid.NewGuid(), Title = "Voucher VIP 1 Juta", Price = 1_000_000, Value = 1_100_000, IsActive = true });
        db.MlmRules.AddRange(new MlmRule { Level = 1, Percentage = 5m },
            new MlmRule { Level = 2, Percentage = 3m }, new MlmRule { Level = 3, Percentage = 1.5m });
        db.MlmSettings.Add(new MlmSetting { Id = 1, DownlineStep = 2, Multiplier = 0.5m });
        await db.SaveChangesAsync();
    }
}
```

Catatan: BCrypt package ditambahkan di Task 2 — tambahkan `dotnet add package BCrypt.Net-Next` sekarang bersama Step 1 agar SeedData compile.

- [ ] **Step 6: Program.cs rewrite**

```csharp
using Microsoft.EntityFrameworkCore;
using VoucherUmrohHaji.Service.Common;
using VoucherUmrohHaji.Service.Data;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddDbContext<AppDbContext>(o =>
    o.UseNpgsql(builder.Configuration.GetConnectionString("Default")));
builder.Services.AddExceptionHandler<DomainExceptionHandler>();
builder.Services.AddOpenApi();

var app = builder.Build();
app.UseExceptionHandler();
if (app.Environment.IsDevelopment()) app.MapOpenApi();

app.MapGet("/api/health", () => Results.Ok(new { status = "ok" }));

using (var scope = app.Services.CreateScope())
    await SeedData.InitializeAsync(scope.ServiceProvider.GetRequiredService<AppDbContext>(), app.Configuration);

app.Run();
public partial class Program { }
```

`appsettings.Development.json` tambahkan: `"ConnectionStrings": { "Default": "Host=localhost;Port=5432;Database=voucher;Username=postgres;Password=haji" }`.

- [ ] **Step 7: Migrasi + apply** (butuh Postgres lokal; kalau belum ada: `docker run --name haji-pg -e POSTGRES_PASSWORD=haji -e POSTGRES_DB=voucher -p 5432:5432 -d postgres:17`)

```bash
dotnet tool install --global dotnet-ef
dotnet user-secrets init
dotnet user-secrets set "AdminUser:Password" "Admin#2026"
dotnet ef migrations add InitialCreate
dotnet ef database update   # atau otomatis saat run: seed memanggil MigrateAsync
dotnet run   # lalu: curl http://localhost:<port>/api/health → {"status":"ok"}
```

- [ ] **Step 8: Build & commit**

```bash
dotnet build   # harus 0 error
git add VoucherUmrohHaji/service
git commit -m "feat(service): scaffold EF Core entities, DbContext, migration, seed, health endpoint"
git push origin main
```

---

### Task 2: Autentikasi — Register, Login, Refresh (JWT)

**Files:**
- Create: `VoucherUmrohHaji/service/Common/TokenService.cs`, `Common/ClaimsPrincipalExtensions.cs`
- Create: `VoucherUmrohHaji/service/Features/Referrals/ReferralService.cs`
- Create: `VoucherUmrohHaji/service/Features/Auth/AuthEndpoints.cs`
- Create: `VoucherUmrohHaji/service-tests/service.tests.csproj`, `AuthTests.cs`, `TestApiFactory.cs`
- Modify: `service.csproj` (JWT package), `Program.cs`, `appsettings*.json` (Jwt section)

**Interfaces:**
- Produces: `POST /api/auth/register` body `{"name","email","password","referral"?}` → 200 `AuthResponse`; `POST /api/auth/login` `{"email","password"}` → 200; `POST /api/auth/refresh` `{"refreshToken"}` → 200. `AuthResponse(AccessToken string, RefreshToken string, ExpiresIn int, Member MemberDto)`; `MemberDto(Id Guid, Name, Email, Role, ReferralCode, Balance long, Downlines int, ParentId Guid?)`.
- Produces: `TokenService.IssueAsync(Member) : Task<(string accessToken, string refreshToken, int expiresIn)>`; `TokenService.RefreshAsync(string refreshToken) : Task<(string accessToken, string refreshToken)>` (throw `DomainException` jika invalid); `TokenService.RevokeAsync(string refreshToken)`.
- Produces: `ReferralService(AppDbContext)` — `FindByCodeAsync(string code) : Task<Member?>` (buyer, case-insensitive); `BindUplineAsync(Member child, string referralCode) : Task` (validasi: bukan admin, belum punya upline, kode ada, bukan kode sendiri, tanpa siklus; set ParentId + increment Downlines semua ancestor; throw DomainException). Dipakai Task 6 & register.

- [ ] **Step 1: Test project + failing test (TestApiFactory)**

`TestApiFactory.cs` — WebApplicationFactory dengan Sqlite in-memory + config test:

```csharp
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using VoucherUmrohHaji.Service.Data;

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
            s.Remove(s.Single(d => d.ServiceType == typeof(DbContextOptions<AppDbContext>)));
            _connection.Open();
            s.AddDbContext<AppDbContext>(o => o.UseSqlite(_connection));
        });
    }
}
```

`AuthTests.cs` (xunit; helper `PostAsJsonAsync`/`ReadFromJsonAsync` via `client.CreateClient()`):

```csharp
public class AuthTests(TestApiFactory factory) : IClassFixture<TestApiFactory>
{
    [Fact] public async Task Register_lalu_login_menghasilkan_token()
    {
        var client = factory.CreateClient();
        var reg = await client.PostAsJsonAsync("/api/auth/register",
            new { name = "Budi Santoso", email = "budi@test.id", password = "Rahasia123", referral = "" });
        Assert.True(reg.IsSuccessStatusCode, await reg.Content.ReadAsStringAsync());
        var auth = await reg.Content.ReadFromJsonAsync<AuthResponse>();
        Assert.False(string.IsNullOrEmpty(auth!.AccessToken));

        var login = await client.PostAsJsonAsync("/api/auth/login", new { email = "budi@test.id", password = "Rahasia123" });
        Assert.True(login.IsSuccessStatusCode);
    }

    [Fact] public async Task Register_email_duplikat_400()
    {
        var client = factory.CreateClient();
        var body = new { name = "Budi", email = "dua@test.id", password = "Rahasia123" };
        await client.PostAsJsonAsync("/api/auth/register", body);
        var dua = await client.PostAsJsonAsync("/api/auth/register", body);
        Assert.Equal(HttpStatusCode.BadRequest, dua.StatusCode);
    }

    [Fact] public async Task Login_password_salah_401()
    {
        var client = factory.CreateClient();
        await client.PostAsJsonAsync("/api/auth/register", new { name = "Budi", email = "salah@test.id", password = "Rahasia123" });
        var login = await client.PostAsJsonAsync("/api/auth/login", new { email = "salah@test.id", password = "Ngasalan999" });
        Assert.Equal(HttpStatusCode.Unauthorized, login.StatusCode);
    }

    [Fact] public async Task Refresh_token_baru_bisa_dipakai()
    {
        var client = factory.CreateClient();
        var reg = await client.PostAsJsonAsync("/api/auth/register", new { name = "Budi", email = "ref@test.id", password = "Rahasia123" });
        var auth = await reg.Content.ReadFromJsonAsync<AuthResponse>()!;
        var refresh = await client.PostAsJsonAsync("/api/auth/refresh", new { refreshToken = auth!.RefreshToken });
        Assert.True(refresh.IsSuccessStatusCode);
        var bad = await client.PostAsJsonAsync("/api/auth/refresh", new { refreshToken = "sampah-token" });
        Assert.Equal(HttpStatusCode.BadRequest, bad.StatusCode);
    }
}
public record AuthResponse(string AccessToken, string RefreshToken, int ExpiresIn, MemberDto Member);
public record MemberDto(Guid Id, string Name, string Email, string Role, string ReferralCode, long Balance, int Downlines, Guid? ParentId);
```

Packages test project: `xunit`, `xunit.runner.visualstudio`, `Microsoft.NET.Test.Sdk`, `Microsoft.AspNetCore.Mvc.Testing`, `Microsoft.EntityFrameworkCore.Sqlite`, `Microsoft.EntityFrameworkCore.Design`.

- [ ] **Step 2: Run → gagal** (`dotnet test` — endpoint belum ada, 404).

- [ ] **Step 3: Implementasi**

`dotnet add package Microsoft.AspNetCore.Authentication.JwtBearer`.

`Common/TokenService.cs`: HMAC-SHA256 JWT, claims `NameIdentifier = memberId`, `Role = member.Role`; access 15 menit; refresh = `Convert.ToHexString(RandomNumberGenerator.GetBytes(32))`, simpan `TokenHash = SHA256(refreshToken)`, 30 hari. Konfigurasi `Jwt:Key/Issuer/Audience` (user-secrets; `Jwt:Key` minimal 32 karakter).

`Features/Auth/AuthEndpoints.cs`:

```csharp
app.MapPost("/api/auth/register", async (RegisterRequest req, AppDbContext db, TokenService tokens, ReferralService referrals) =>
{
    var name = req.Name.Trim();
    var email = req.Email.Trim().ToLowerInvariant();
    if (name.Length < 3 || !email.Contains('@') || !email.Contains('.')) throw new DomainException("Isi nama dan alamat email yang valid");
    if (req.Password.Length < 8) throw new DomainException("Password minimal 8 karakter");
    if (await db.Members.AnyAsync(m => m.Email == email)) throw new DomainException("Email sudah digunakan");

    var member = new Member { Id = Guid.NewGuid(), Name = name, Email = email,
        PasswordHash = BCrypt.Net.BCrypt.HashPassword(req.Password), ReferralCode = GenerateUniqueCode(db) };
    db.Members.Add(member);
    await db.SaveChangesAsync();
    if (!string.IsNullOrWhiteSpace(req.Referral)) await referrals.BindUplineAsync(member, req.Referral);
    var (access, refresh, expiresIn) = await tokens.IssueAsync(member);
    return Results.Ok(new AuthResponse(access, refresh, expiresIn, member.ToDto()));
});
```

`Login`: cari by email → `BCrypt.Verify` (salah → `Results.Unauthorized()` bukan exception) → IssueAsync. `Refresh`: `tokens.RefreshAsync` → 200 / DomainException 400. `GenerateUniqueCode(AppDbContext)`: `"VCH-" + 8 karakter hex uppercase acak`, loop cek unik di DB. Extension `Member.ToDto()` di `Common/MemberExtensions.cs`.

`Program.cs` tambah: `AddAuthentication(JwtBearerDefaults).AddJwtBearer(...)`, `AddAuthorization`, `app.UseAuthentication(); app.UseAuthorization();`, rate limit: `AddRateLimiter(o => o.AddFixedWindowLimiter("login", ...))` — 5 request/menit per IP untuk `POST /api/auth/login` (`.RequireRateLimiting("login")`).

- [ ] **Step 4: `dotnet test` → 4 test PASS. Step 5: commit `feat(auth): register, login, refresh dengan JWT dan rate limit` + push.**

---

### Task 3: Vouchers — Katalog Publik + CRUD Admin

**Files:**
- Create: `VoucherUmrohHaji/service/Features/Vouchers/VoucherEndpoints.cs`
- Test: `VoucherTests.cs`

**Interfaces:**
- `GET /api/vouchers` (auth buyer/admin) → `[{id, title, price, value, isActive:true-only}]`
- Admin: `POST /api/admin/vouchers {"title","price","value"}`, `PUT /api/admin/vouchers/{id}` (termasuk `isActive`), `DELETE /api/admin/vouchers/{id}`.

- [ ] **Step 1: Failing tests** (login sebagai admin seed `admin@haji.local`/`Admin#2026` via helper `LoginAdminAsync(client)` di test):

```csharp
[Fact] public async Task Buyer_melihat_voucher_aktif_saja() { /* seed 1 aktif + 1 nonaktif via admin; GET → hanya aktif */ }
[Fact] public async Task Nonadmin_CRUD_403() { /* register buyer → POST voucher → 403 */ }
[Fact] public async Task Hapus_voucher_yang_pernah_diorder_409() { /* admin buat voucher, buyer buat order? order baru ada Task 4 — ganti: insert Order row langsung via factory scope DbContext; DELETE → 409 */ }
[Fact] public async Task Validasi_price_value_harus_positif_400() { }
```

`TestApiFactory` tambahkan helper `CreateAdminScope()` untuk akses `AppDbContext` langsung seeding data.

- [ ] **Step 2: run → fail. Step 3: implementasi** — CRUD standar; guard delete: `if (await db.Orders.AnyAsync(o => o.VoucherId == id)) return Results.Conflict(new { error = "Voucher pernah ditransaksikan. Nonaktifkan, jangan hapus." });` Validasi title non-kosong, price>0, value>0 → `DomainException`.

- [ ] **Step 4: test pass. Step 5: commit `feat(vouchers): katalog publik dan CRUD admin` + push.**

---

### Task 4: Orders + Midtrans Snap Token

**Files:**
- Create: `VoucherUmrohHaji/service/Common/MidtransOptions.cs`, `Common/MidtransClient.cs`, `Common/IMidtransClient.cs`
- Create: `VoucherUmrohHaji/service/Features/Orders/OrderEndpoints.cs`
- Modify: `Program.cs` (TypedHttpClient + Options), `appsettings.Development.json` (`Midtrans` section, IsProduction false)
- Test: `OrderTests.cs`, fake `FakeMidtransClient`

**Interfaces:**
- `IMidtransClient.CreateSnapTransactionAsync(string orderId, decimal grossAmount) : Task<(string Token, string RedirectUrl)>` — POST `https://app.sandbox.midtrans.com/snap/v1/transactions` (atau production bila `Midtrans:IsProduction=true`), Basic auth `<serverKey>:`.
- `IMidtransClient.GetTransactionStatusAsync(string orderId) : Task<MidtransTransactionStatus>` — GET `/v2/{orderId}/status`; `record MidtransTransactionStatus(string TransactionStatus, string? FraudStatus, string StatusCode, string GrossAmount)`.
- `POST /api/orders {"voucherId"}` → 200 `{"orderId","amount","value","status":"pending","snapToken","snapUrl"}`; `GET /api/orders` (milik sendiri, terbaru dulu, page 1 size 20); `POST /api/orders/{id}/cancel` (hanya pending → 400 selain itu).

- [ ] **Step 1: Failing tests** — `OrderTests`: buyer register → POST /api/orders dengan voucherId dari GET /api/vouchers → status pending + snapToken dari fake; order kedua user lain tak terlihat di GET; cancel pending → 200, cancel ulang → 400. `FakeMidtransClient : IMidtransClient` (fixed token `"fake-snap-token"`, url `https://app.sandbox.midtrans.com/snap/v2/fake"`); register di `TestApiFactory.ConfigureServices`: `s.AddSingleton<IMidtransClient, FakeMidtransClient>()` setelah `Remove` implementasi aslinya.

- [ ] **Step 2: run → fail. Step 3: implementasi** — `MidtransClient` TypedHttp client (`AddHttpClient<IMidtransClient, MidtransClient>()`), Basic auth dari `MidtransOptions.ServerKey`; gagal panggil API → `DomainException("Layanan pembayaran sedang tidak tersedia")` + log warning (jangan lempar detail HTTP keluar). Buat order: voucher harus aktif, admin ditolak (`DomainException("Admin tidak dapat membuat order")`), id `"ORD-" + 10 char uppercase`, simpan `SnapToken`. Cancel: hanya `pending`.

- [ ] **Step 4: test pass. Step 5: commit `feat(orders): buat order, snap token Midtrans, cancel, daftar order` + push.**

---

### Task 5: Payments — Webhook Verifikasi + Settlement MLM + Inquiry

**Files:**
- Create: `VoucherUmrohHaji/service/Features/Payments/MlmCalculator.cs`, `SettlementService.cs`, `PaymentEndpoints.cs`
- Test: `MlmCalculatorTests.cs` (unit), `PaymentTests.cs` (integration)

**Interfaces:**
- `MlmCalculator.ComputePayouts(decimal orderAmount, IReadOnlyList<MlmRule> rules, int downlineStep, decimal multiplier, IReadOnlyList<(Guid memberId, int downlines)> uplineChain) : IReadOnlyList<Payout>` — `record Payout(Guid MemberId, int Level, decimal Factor, long Amount)`; `Amount = (long)Math.Round(orderAmount * rule.Percentage / 100m * factor, MidpointRounding.AwayFromZero)`; `factor = 1m + Math.Floor((decimal)downlines / downlineStep) * multiplier`; chain dipotong `rules.Count` level, `downlineStep <= 0` → factor 1.
- `SettlementService.SettleAsync(string orderId) : Task<bool>` — false bila order bukan pending (idempotent); true jika settlement dijalankan. Dipakai webhook & inquiry.
- `POST /api/webhooks/midtrans` — anonim; `GET /api/orders/{id}/status` (auth, owner/admin) → status terkini.

- [ ] **Step 1: Unit test MlmCalculator (failing)**

```csharp
public class MlmCalculatorTests
{
    private static readonly MlmRule[] Rules = [new() { Level = 1, Percentage = 5m }, new() { Level = 2, Percentage = 3m }, new() { Level = 3, Percentage = 1.5m }];

    [Fact] public void Tiga_level_tanpa_multiplier()
    {
        var chain = new[] { (Guid.NewGuid(), 0), (Guid.NewGuid(), 0), (Guid.NewGuid(), 0) };
        var payouts = MlmCalculator.ComputePayouts(100_000m, Rules, 2, 0.5m, chain);
        Assert.Equal([50_000L, 30_000L, 15_000L], payouts.Select(p => p.Amount));
    }

    [Fact] public void Multiplier_bertingkat()
    {   // upline L1 punya 4 downline, step 2, mult 0.5 → factor 2.0 → 5% × 2 × 100000 = 10000
        var chain = new[] { (Guid.NewGuid(), 4), (Guid.NewGuid(), 0), (Guid.NewGuid(), 0) };
        var payouts = MlmCalculator.ComputePayouts(100_000m, Rules, 2, 0.5m, chain);
        Assert.Equal(10_000L, payouts[0].Amount);
        Assert.Equal(2.0m, payouts[0].Factor);
    }

    [Fact] public void Chain_lebih_pendek_dari_rules_hanya_hitung_yang_ada()
    {
        var chain = new[] { (Guid.NewGuid(), 0) };
        Assert.Single(MlmCalculator.ComputePayouts(100_000m, Rules, 2, 0.5m, chain));
    }

    [Fact] public void Pembulatan_away_from_zero()
    {   // 999 × 1.5% = 14.985 → 15
        var chain = new[] { (Guid.NewGuid(), 0) };
        var payouts = MlmCalculator.ComputePayouts(999m, [new MlmRule { Level = 1, Percentage = 1.5m }], 2, 0m, chain);
        Assert.Equal(15L, payouts[0].Amount);
    }

    [Fact] public void Payout_nol_tidak_dikembalikan()
    {
        var chain = new[] { (Guid.NewGuid(), 0) };
        Assert.Empty(MlmCalculator.ComputePayouts(100m, [new MlmRule { Level = 1, Percentage = 0m }], 2, 0.5m, chain));
    }
}
```

- [ ] **Step 2: Run → fail (class belum ada). Implement MlmCalculator → pass.**

- [ ] **Step 3: Integration test webhook (failing)**

```csharp
[Fact] public async Task Webhook_signature_valid_settlement_dan_idempotent()
{
    var (client, orderId, buyerId) = await BuatOrderPendingAsync(); // helper: register+order
    var notif = MidtransNotificationUntuk(orderId, gross: 100_000); // record helper di test
    var respons1 = await client.PostAsJsonAsync("/api/webhooks/midtrans", notif);
    var respons2 = await client.PostAsJsonAsync("/api/webhooks/midtrans", notif); // replay
    Assert.True(respons1.IsSuccessStatusCode); Assert.True(respons2.IsSuccessStatusCode);
    // saldo buyer +100000 (value voucher), ledger topup ada 1, order status settlement
    using var scope = _factory.CreateAdminScope();
    var saldo = scope.Db.Members.Single(m => m.Id == buyerId).Balance;
    var ledgerTopup = scope.Db.Ledgers.Count(l => l.OrderId == orderId && l.Type == "topup");
    Assert.Equal(100_000, saldo); Assert.Equal(1, ledgerTopup);
}
[Fact] public async Task Webhook_signature_salah_400_dan_tidak_settle() { }
[Fact] public async Task Inquiry_status_juga_settle_order_pending() { /* FakeMidtransClient.GetTransactionStatusAsync → "settlement" → GET /api/orders/{id}/status → settlement */ }
```

`MidtransNotificationUntuk` membangun signature benar: `SHA256Hex(order_id + status_code + gross_amount + serverKey)` — serverKey test dari `Jwt/test config` `Midtrans:ServerKey = "SB-Mid-server-TEST"` (set di TestApiFactory.UseSetting). Signature helper hitung di test dengan `Convert.ToHexString(SHA256.HashData(Encoding.ASCII(payload)))`.

- [ ] **Step 4: Implementasi**

`SettlementService.SettleAsync` — inti (dijaga < 300 baris total file):

```csharp
public async Task<bool> SettleAsync(string orderId)
{
    using var tx = await _db.Database.BeginTransactionAsync();
    var order = await _db.Orders.FirstOrDefaultAsync(o => o.Id == orderId);
    if (order is null || order.Status != "pending") return false;   // idempotent

    order.Status = "settlement";
    var buyer = await _db.Members.SingleAsync(m => m.Id == order.MemberId);
    buyer.Balance += order.Value;
    var voucher = await _db.Vouchers.SingleAsync(v => v.Id == order.VoucherId);
    _db.VouchersOwned.Add(new VoucherOwned { Id = Guid.NewGuid(), MemberId = buyer.Id, Title = voucher.Title,
        Value = order.Value, OrderId = order.Id, CreatedAt = DateTime.UtcNow });
    TambahLedger(buyer.Id, "topup", $"Top-Up {voucher.Title}", order.Value, order.Id);

    var chain = await MuatUplineChainAsync(buyer);                 // walk ParentId sampai habis
    var setting = await _db.MlmSettings.AsNoTracking().SingleAsync(s => s.Id == 1);
    var rules = await _db.MlmRules.AsNoTracking().OrderBy(r => r.Level).ToListAsync();
    foreach (var payout in MlmCalculator.ComputePayouts(order.Amount, rules, setting.DownlineStep, setting.Multiplier, chain))
    {
        var upline = await _db.Members.SingleAsync(m => m.Id == payout.MemberId);
        upline.Balance += payout.Amount;
        TambahLedger(upline.Id, "mlm_cashback", $"Cashback Level {payout.Level} ×{payout.Factor:0.00} dari {buyer.Name}", payout.Amount, order.Id);
    }
    await _db.SaveChangesAsync();
    await tx.CommitAsync();
    return true;
}
```

`PaymentEndpoints`: webhook — bind body `MidtransNotification(OrderId, StatusCode, GrossAmount, TransactionStatus, FraudStatus?, SignatureKey)`; verifikasi signature (mismatch → `Results.BadRequest(new { error = "Signature tidak valid" })` tanpa side effect); `settlement`/(`capture` + fraud `accept`) → `SettleAsync`; `cancel`/`deny`/`expire` → set status (`cancel`/`expire`) bila masih pending; selalu balas 200 agar Midtrans tidak retry tanpa henti (kecuali signature invalid). Inquiry: order pending → `GetTransactionStatusAsync` → logic sama → balik status.

- [ ] **Step 5: Semua test pass → commit `feat(payments): webhook Midtrans terverifikasi, settlement MLM idempotent, inquiry fallback` + push.**

---

### Task 6: Wallet + Referrals

**Files:**
- Create: `VoucherUmrohHaji/service/Features/Wallet/WalletEndpoints.cs`, `Features/Referrals/ReferralEndpoints.cs`
- Test: `WalletTests.cs`, `ReferralTests.cs`

**Interfaces:**
- `GET /api/wallet` → `{balance, owned:[{title,value,orderId,createdAt}], ledger:[{type,title,amount,orderId,createdAt}]}` — milik sendiri, ledger terbaru dulu max 50.
- `GET /api/referral/me` → `{referralCode, downlines, directDownlines:[{name}], factorPreview, uplineName?, rules:[{level,percentage}]}` (`factorPreview = 1 + ⌊downlines/step⌋ × multiplier`).
- `POST /api/referral/bind {"referralCode"}` → pakai `ReferralService.BindUplineAsync` (Task 2).

- [ ] **Step 1: Failing tests** — wallet menampilkan saldo+ledger setelah settlement (buat order → webhook → GET wallet); referral bind: buyer A kode → buyer B bind → `referral/me` B menampilkan uplineName A, A.downlines=1; bind ulang → 400; kode sendiri → 400; kode bikin siklus → 400 (A→B→A: butuh 3 member via DbScope set ParentId manual lalu bind).
- [ ] **Step 2: run fail. Step 3: implementasi** (semua query filter `MemberId == user.MemberId()`; `AsNoTracking`; admin melihat wallet sendiri saja).
- [ ] **Step 4: pass. Step 5: commit `feat(wallet,referrals): dompet, mutasi, jaringan referral, bind upline` + push.**

---

### Task 7: Withdrawals + Endpoint Admin Lainnya

**Files:**
- Create: `VoucherUmrohHaji/service/Features/Withdrawals/WithdrawalEndpoints.cs`, `Features/Admin/AdminEndpoints.cs`
- Test: `WithdrawalTests.cs`, `AdminTests.cs`

**Interfaces:**
- `POST /api/withdrawals {"amount","bank","account","holder"}` (buyer; `0 < amount <= balance`, `account.Length >= 5`; saldo dikurangi, withdrawal `pending`, ledger `withdraw` negatif — dalam 1 transaction).
- `GET /api/withdrawals` — milik sendiri; `GET /api/admin/withdrawals` — semua, pending dulu.
- `POST /api/admin/withdrawals/{id}/approve` → status `approved` (dari pending; selain itu 400). `POST .../reject` → `rejected` + saldo dikembalikan + ledger `refund` (idempotent-guard: hanya pending).
- `GET /api/admin/members?page=1&pageSize=20` (urut nama; body ringkas: id,name,email,role,referralCode,balance,downlines,parentId).
- `PUT /api/admin/mlm-config {"levels":[5,3,1.5],"downlineStep":2,"multiplier":0.5}` — validasi sama Swift: 1–20 level, tiap 0–100, step>0, multiplier 0–100; replace rules + update setting.

- [ ] **Step 1: Failing tests** — ajukan withdraw saldo cukup → saldo berkurang & pending; saldo kurang → 400; admin approve → approved; reject → saldo kembali + ledger refund; reject dua kali → 400; buyer akses endpoint admin → 403; mlm-config invalid (21 level / persen 150) → 400; mlm-config valid mengubah perhitungan payout berikutnya (set 1 level 10%, order baru → cashback 10%).
- [ ] **Step 2: run fail. Step 3: implementasi. Step 4: pass. Step 5: commit `feat(withdrawals,admin): pengajuan withdraw hold, approval admin, konfigurasi MLM, daftar anggota` + push.**

---

### Task 8: API Docs + Pembersihan Akhir

**Files:**
- Modify: `VoucherUmrohHaji/service/Program.cs` (OpenAPI tags/summary), `README.md` (bagian API)

- [ ] **Step 1:** Tambah `.WithTags("Auth"|"Vouchers"|"Orders"|"Payments"|"Wallet"|"Referrals"|"Withdrawals"|"Admin")` + `.WithSummary(...)` per endpoint; pastikan `GET /openapi/v1.json` memuat semua grup.
- [ ] **Step 2:** README.md root — tambah bagian "Backend API": cara run (docker Postgres, user-secrets: AdminUser:Password, Jwt:Key, Midtrans:ServerKey), tabel endpoint ringkas, cara set webhook URL di Midtrans dashboard (`https://<host-public>/api/webhooks/midtrans`, pakai ngrok/dev tunnel saat dev lokal).
- [ ] **Step 3:** `dotnet build` (0 error, periksa warning baru) + `dotnet test` semua hijau.
- [ ] **Step 4:** commit `docs(api): dokumentasi endpoint dan setup backend` + push.

---

## Plan Flutter
Sudah tersedia: `docs/superpowers/plans/2026-10-27-flutter-app.md` — eksekusi berurutan setelah plan ini selesai (butuh API hidup). Bentuk respons API yang diharapkan Flutter tercantum di plan itu; bila implementasi backend menyimpang, sesuaikan backend ke bentuk tersebut.
