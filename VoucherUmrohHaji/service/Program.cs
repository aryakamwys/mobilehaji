using System.Text;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using VoucherUmrohHaji.Service.Common;
using VoucherUmrohHaji.Service.Data;
using VoucherUmrohHaji.Service.Features.Admin;
using VoucherUmrohHaji.Service.Features.Auth;
using VoucherUmrohHaji.Service.Features.Orders;
using VoucherUmrohHaji.Service.Features.Payments;
using VoucherUmrohHaji.Service.Features.Referrals;
using VoucherUmrohHaji.Service.Features.Vouchers;
using VoucherUmrohHaji.Service.Features.Wallet;
using VoucherUmrohHaji.Service.Features.Withdrawals;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddDbContext<AppDbContext>(o =>
    o.UseNpgsql(builder.Configuration.GetConnectionString("Default")));
builder.Services.AddExceptionHandler<DomainExceptionHandler>();
builder.Services.AddProblemDetails();
builder.Services.AddOpenApi();
builder.Services.AddScoped<TokenService>();
builder.Services.AddScoped<ReferralService>();
builder.Services.AddScoped<SettlementService>();
builder.Services.Configure<MidtransOptions>(builder.Configuration.GetSection(MidtransOptions.SectionName));
builder.Services.AddHttpClient<IMidtransClient, MidtransClient>(c => c.Timeout = TimeSpan.FromSeconds(10));

// fail-fast: tanpa kunci yang valid semua terbitan token (login/register) gagal runtime —
// lebih baik menolak menyala. Test factory juga set Jwt:Key via UseSetting, jadi guard ini netral bagi test.
var jwtKey = builder.Configuration["Jwt:Key"];
if (string.IsNullOrWhiteSpace(jwtKey) || jwtKey.Length < 32)
    throw new InvalidOperationException("Jwt:Key belum dikonfigurasi atau kurang dari 32 karakter (user-secrets).");

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(o => o.TokenValidationParameters = new TokenValidationParameters
    {
        ValidIssuer = builder.Configuration["Jwt:Issuer"],
        ValidAudience = builder.Configuration["Jwt:Audience"],
        IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(builder.Configuration["Jwt:Key"] ?? string.Empty)),
        ValidateIssuer = true,
        ValidateAudience = true,
        ValidateIssuerSigningKey = true,
        ValidateLifetime = true,
        ClockSkew = TimeSpan.FromSeconds(30)
    });
builder.Services.AddAuthorization();

// CORS untuk admin web (dev: Vite di 5173). Produksi: set "Cors:Origins" (comma-separated).
builder.Services.AddCors(o => o.AddDefaultPolicy(p => p
    .WithOrigins((builder.Configuration["Cors:Origins"] ?? "http://localhost:5173")
        .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
    .AllowAnyHeader().AllowAnyMethod()));

builder.Services.AddRateLimiter(o =>
{
    o.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    o.OnRejected = async (ctx, _) => await ctx.HttpContext.Response.WriteAsJsonAsync(
        new { error = "Terlalu banyak percobaan, coba lagi sebentar" }); // kontrak body untuk SnackBar Flutter
    o.AddPolicy("login", ctx => RateLimitPartition.GetFixedWindowLimiter(
        ctx.Connection.RemoteIpAddress?.ToString() ?? "anon",
        _ => new FixedWindowRateLimiterOptions { PermitLimit = 5, Window = TimeSpan.FromMinutes(1) }));
});

var app = builder.Build();
app.UseExceptionHandler();
app.UseCors();
// di belakang reverse proxy (produksi) IP klien & skema asli datang dari header X-Forwarded-*
if (!app.Environment.IsDevelopment())
    app.UseForwardedHeaders(new ForwardedHeadersOptions { ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto });
app.UseRateLimiter();
app.UseAuthentication();
app.UseAuthorization();
if (app.Environment.IsDevelopment()) app.MapOpenApi();

app.MapGet("/api/health", () => Results.Ok(new { status = "ok" })).WithTags("Health").WithSummary("Health check");
app.MapAuthEndpoints();
app.MapVoucherEndpoints();
app.MapOrderEndpoints();
app.MapPaymentEndpoints();
app.MapWalletEndpoints();
app.MapReferralEndpoints();
app.MapWithdrawalEndpoints();
app.MapAdminEndpoints();

using (var scope = app.Services.CreateScope())
    await SeedData.InitializeAsync(scope.ServiceProvider.GetRequiredService<AppDbContext>(), app.Configuration);

app.Run();
public partial class Program { }
