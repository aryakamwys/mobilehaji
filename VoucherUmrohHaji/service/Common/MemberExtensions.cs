using VoucherUmrohHaji.Service.Data.Entities;
using VoucherUmrohHaji.Service.Features.Auth;

namespace VoucherUmrohHaji.Service.Common;

public static class MemberExtensions
{
    public static MemberDto ToDto(this Member member) =>
        new(member.Id, member.Name, member.Email, member.Role, member.ReferralCode,
            member.Balance, member.Downlines, member.ParentId);
}
