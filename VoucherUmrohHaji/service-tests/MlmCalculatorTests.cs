using VoucherUmrohHaji.Service.Data.Entities;
using VoucherUmrohHaji.Service.Features.Payments;

public class MlmCalculatorTests
{
    private static readonly MlmRule[] Rules = [new() { Level = 1, Percentage = 5m }, new() { Level = 2, Percentage = 3m }, new() { Level = 3, Percentage = 1.5m }];

    [Fact] public void Tiga_level_tanpa_multiplier()
    {
        var chain = new[] { (Guid.NewGuid(), 0), (Guid.NewGuid(), 0), (Guid.NewGuid(), 0) };
        var payouts = MlmCalculator.ComputePayouts(100_000m, Rules, 2, 0.5m, chain);
        Assert.Equal([5_000L, 3_000L, 1_500L], payouts.Select(p => p.Amount));
    }

    [Fact] public void Multiplier_bertingkat()
    {   // upline L1 punya 4 downline, step 2, mult 0.5 → factor 2.0 → 5% × 2 × 100000 = 10000
        var chain = new[] { (Guid.NewGuid(), 4), (Guid.NewGuid(), 0), (Guid.NewGuid(), 0) };
        var payouts = MlmCalculator.ComputePayouts(100_000m, Rules, 2, 0.5m, chain);
        Assert.Equal(10_000L, payouts[0].Amount);
        Assert.Equal(2.0m, payouts[0].Factor);
    }

    [Fact] public void Chain_lebih_pendek_dari_rules_hanya_hitung_yang_ada()
    {
        var chain = new[] { (Guid.NewGuid(), 0) };
        Assert.Single(MlmCalculator.ComputePayouts(100_000m, Rules, 2, 0.5m, chain));
    }

    [Fact] public void Pembulatan_away_from_zero()
    {   // 999 × 1.5% = 14.985 → 15
        var chain = new[] { (Guid.NewGuid(), 0) };
        var payouts = MlmCalculator.ComputePayouts(999m, [new MlmRule { Level = 1, Percentage = 1.5m }], 2, 0m, chain);
        Assert.Equal(15L, payouts[0].Amount);
    }

    [Fact] public void Payout_nol_tidak_dikembalikan()
    {
        var chain = new[] { (Guid.NewGuid(), 0) };
        Assert.Empty(MlmCalculator.ComputePayouts(100m, [new MlmRule { Level = 1, Percentage = 0m }], 2, 0.5m, chain));
    }
}
