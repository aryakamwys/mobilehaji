namespace VoucherUmrohHaji.Service.Data.Entities;

public class RefreshToken
{
    public Guid Id { get; set; }
    public Guid MemberId { get; set; }
    public string TokenHash { get; set; } = string.Empty;
    public DateTime ExpiresAt { get; set; }
    public bool Revoked { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
