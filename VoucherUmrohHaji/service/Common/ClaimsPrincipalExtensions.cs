using System.Security.Claims;

namespace VoucherUmrohHaji.Service.Common;

public static class ClaimsPrincipalExtensions
{
    /// <summary>Ambil memberId dari klaim token (nameid/sub), sesuai klaim yang diterbitkan TokenService.</summary>
    public static Guid MemberId(this ClaimsPrincipal user)
    {
        var value = user.FindFirstValue(ClaimTypes.NameIdentifier)
            ?? user.FindFirstValue("sub")
            ?? user.FindFirstValue("nameid");
        return Guid.TryParse(value, out var id)
            ? id
            : throw new DomainException("Token tidak berisi identitas member yang valid");
    }
}
