namespace VoucherUmrohHaji.Service.Common;

public class MidtransOptions
{
    public const string SectionName = "Midtrans";
    public string ServerKey { get; set; } = string.Empty;
    public bool IsProduction { get; set; }
}
