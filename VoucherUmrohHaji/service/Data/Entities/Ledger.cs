namespace VoucherUmrohHaji.Service.Data.Entities;

public class Ledger
{
    public Guid Id { get; set; }
    public Guid MemberId { get; set; }
    public string Type { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public long Amount { get; set; }
    public string OrderId { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
