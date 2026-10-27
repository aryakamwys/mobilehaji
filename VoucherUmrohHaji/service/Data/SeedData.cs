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
