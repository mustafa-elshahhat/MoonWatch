namespace WatchParty.Server.Middleware;

/// <summary>
/// Global error handling middleware per ERROR_HANDLING.md.
/// Catches unhandled exceptions and returns structured JSON. Never returns stack traces.
/// </summary>
public class ErrorHandlingMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<ErrorHandlingMiddleware> _logger;

    public ErrorHandlingMiddleware(RequestDelegate next, ILogger<ErrorHandlingMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await _next(context);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unhandled exception in request pipeline {Method} {Path}",
                context.Request.Method, context.Request.Path);

            if (context.Response.HasStarted)
            {
                _logger.LogWarning("Response already started — cannot write error body for {Method} {Path}",
                    context.Request.Method, context.Request.Path);
                return;
            }

            context.Response.StatusCode = 500;
            context.Response.ContentType = "application/json";

            await context.Response.WriteAsJsonAsync(new
            {
                error = "internal_error",
                message = "An unexpected error occurred. Please try again.",
            });
        }
    }
}
