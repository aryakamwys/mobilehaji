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
