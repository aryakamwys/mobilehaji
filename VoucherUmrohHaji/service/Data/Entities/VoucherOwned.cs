namespace VoucherUmrohHaji.Service.Data.Entities;

public class VoucherOwned
{
    public Guid Id { get; set; }
    public Guid MemberId { get; set; }
    public string Title { get; set; } = string.Empty;
    public long Value { get; set; }
    public string OrderId { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
