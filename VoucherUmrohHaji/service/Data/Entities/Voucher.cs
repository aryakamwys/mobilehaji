namespace VoucherUmrohHaji.Service.Data.Entities;

public class Voucher
{
    public Guid Id { get; set; }
    public string Title { get; set; } = string.Empty;
    public long Price { get; set; }
    public long Value { get; set; }
    public bool IsActive { get; set; }
}
