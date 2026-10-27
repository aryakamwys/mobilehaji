namespace VoucherUmrohHaji.Service.Data.Entities;

public class Withdrawal
{
    public string Id { get; set; } = string.Empty;
    public Guid MemberId { get; set; }
    public long Amount { get; set; }
    public string Bank { get; set; } = string.Empty;
    public string Account { get; set; } = string.Empty;
    public string Holder { get; set; } = string.Empty;
    public string Status { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
