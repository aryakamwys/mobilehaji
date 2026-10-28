using VoucherUmrohHaji.Service.Data.Entities;

namespace VoucherUmrohHaji.Service.Features.Payments;

public record Payout(Guid MemberId, int Level, decimal Factor, long Amount);

/// <summary>Perhitungan cashback MLM murni tanpa akses DB — mudah diuji unit.</summary>
public static class MlmCalculator
{
    /// <param name="uplineChain">Upline tingkat 1 (langsung) lebih dulu, beserta jumlah downline-nya.</param>
    public static IReadOnlyList<Payout> ComputePayouts(decimal orderAmount, IReadOnlyList<MlmRule> rules,
        int downlineStep, decimal multiplier, IReadOnlyList<(Guid memberId, int downlines)> uplineChain)
    {
        var payouts = new List<Payout>();
        var levels = rules.OrderBy(r => r.Level).Take(uplineChain.Count).ToList();
        for (var i = 0; i < levels.Count; i++)
        {
            var (memberId, downlines) = uplineChain[i];
            var factor = downlineStep <= 0
                ? 1m
                : 1m + Math.Floor((decimal)downlines / downlineStep) * multiplier;
            var amount = (long)Math.Round(orderAmount * levels[i].Percentage / 100m * factor, MidpointRounding.AwayFromZero);
            if (amount != 0) payouts.Add(new Payout(memberId, levels[i].Level, factor, amount));
        }
        return payouts;
    }
}
