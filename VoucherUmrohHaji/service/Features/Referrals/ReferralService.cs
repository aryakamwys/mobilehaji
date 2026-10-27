using Microsoft.EntityFrameworkCore;
using VoucherUmrohHaji.Service.Common;
using VoucherUmrohHaji.Service.Data;
using VoucherUmrohHaji.Service.Data.Entities;

namespace VoucherUmrohHaji.Service.Features.Referrals;

/// <summary>Pencarian kode referral dan pengikatan upline (dipakai register dan Task 6).</summary>
public class ReferralService(AppDbContext db)
{
    /// <summary>Hanya buyer yang boleh jadi upline — kode admin tidak dapat diikat (rujukan Store.swift register/bindReferral).</summary>
    public Task<Member?> FindByCodeAsync(string code)
    {
        var normalized = code.Trim().ToUpperInvariant();
        return db.Members.SingleOrDefaultAsync(m => m.Role == "buyer" && m.ReferralCode.ToUpper() == normalized);
    }

    public async Task BindUplineAsync(Member child, string referralCode)
    {
        if (child.Role != "buyer") throw new DomainException("Admin tidak dapat memiliki upline");
        if (child.ParentId is not null) throw new DomainException("Member sudah memiliki upline");
        var parent = await FindByCodeAsync(referralCode)
            ?? throw new DomainException("Kode referral tidak ditemukan");
        if (parent.Id == child.Id) throw new DomainException("Tidak dapat menggunakan kode referral sendiri");

        // Naik dari parent ke root: cek siklus sekaligus tambah Downlines tiap ancestor.
        var visited = new HashSet<Guid>();
        var ancestor = parent;
        while (ancestor is not null && visited.Add(ancestor.Id))
        {
            if (ancestor.Id == child.Id) throw new DomainException("Kode referral tidak valid: membentuk siklus");
            ancestor.Downlines++;
            ancestor = ancestor.ParentId is null ? null : await db.Members.FindAsync(ancestor.ParentId);
        }
        child.ParentId = parent.Id;
        await db.SaveChangesAsync();
    }
}
