namespace VoucherUmrohHaji.Service.Data.Entities;

public class Order
{
    public string Id { get; set; } = string.Empty;
    public Guid MemberId { get; set; }
    public Guid VoucherId { get; set; }
    public long Amount { get; set; }
    public long Value { get; set; }
    public string Status { get; set; } = string.Empty;
    public string? SnapToken { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
