using Microsoft.AspNetCore.Diagnostics;

namespace VoucherUmrohHaji.Service.Common;

public class DomainExceptionHandler : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(HttpContext httpContext, Exception exception, CancellationToken cancellationToken)
    {
        if (exception is not DomainException domainException) return false;

        httpContext.Response.StatusCode = StatusCodes.Status400BadRequest;
        await httpContext.Response.WriteAsJsonAsync(new { error = domainException.Message }, cancellationToken);
        return true;
    }
}
