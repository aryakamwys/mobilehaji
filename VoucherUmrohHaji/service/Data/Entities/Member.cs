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
