using System.Threading.RateLimiting;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.AspNetCore.Http.Connections;
using Serilog;
using Serilog.Events;
using WatchParty.Server.Configuration;
using WatchParty.Server.Health;
using WatchParty.Server.Hubs;
using WatchParty.Server.Middleware;
using WatchParty.Server.Services;


var AppStartedAt = DateTimeOffset.UtcNow;
var AppVersion = typeof(Program).Assembly.GetName().Version?.ToString() ?? "unknown";

var LogDir = Path.Combine(AppContext.BaseDirectory, "logs");
var ServerLogPath = Path.Combine(LogDir, "server.log");
try
{
    Directory.CreateDirectory(LogDir);
    if (File.Exists(ServerLogPath)) File.Delete(ServerLogPath);
}
catch (Exception ex)
{
    // Best-effort log reset before the logger exists. Don't crash startup, but
    // surface the problem (e.g. a read-only/misconfigured log dir in production)
    // instead of swallowing it silently.
    Console.Error.WriteLine($"[startup] Could not reset log file '{ServerLogPath}': {ex.Message}");
}



static LoggerConfiguration ConfigureSinks(LoggerConfiguration cfg, string logPath) =>
    cfg.MinimumLevel.Information()
       .MinimumLevel.Override("Microsoft.AspNetCore", LogEventLevel.Warning)
       .Enrich.FromLogContext()
       .Enrich.WithMachineName()
       .Enrich.WithThreadId()
       .WriteTo.Console()
       .WriteTo.File(
           logPath,
           outputTemplate: "{Timestamp:yyyy-MM-dd HH:mm:ss.fff zzz} [{Level:u3}] [{SourceContext}] {Message:lj}{NewLine}{Exception}",
           flushToDiskInterval: TimeSpan.FromSeconds(1));


Log.Logger = ConfigureSinks(new LoggerConfiguration(), ServerLogPath).CreateLogger();

Log.Information("════════════════════════════════════════════════════════════════");
Log.Information("  WatchParty Server — session start");
Log.Information("  Platform: {Platform}, Runtime: {Runtime}", Environment.OSVersion, Environment.Version);
Log.Information("  Timestamp: {Timestamp}", DateTimeOffset.UtcNow.ToString("o"));
Log.Information("════════════════════════════════════════════════════════════════");

try
{
    var builder = WebApplication.CreateBuilder(args);

    
    builder.Host.UseSerilog((context, services, configuration) =>
        ConfigureSinks(
            configuration.ReadFrom.Configuration(context.Configuration).ReadFrom.Services(services),
            ServerLogPath));

    
    var wpOptions = builder.Configuration.GetSection("WatchParty").Get<WatchPartyOptions>() ?? new WatchPartyOptions();
    builder.Services.Configure<WatchPartyOptions>(builder.Configuration.GetSection("WatchParty"));


    builder.Services.AddControllers();
    builder.Services.AddSingleton<IRoomRegistry, InMemoryRoomRegistry>();
    builder.Services.AddSingleton<IRoomService, RoomService>();


    builder.Services.AddSignalR(options =>
    {
        options.KeepAliveInterval = TimeSpan.FromSeconds(wpOptions.SignalR.KeepAliveIntervalSeconds);
        options.ClientTimeoutInterval = TimeSpan.FromSeconds(wpOptions.SignalR.ClientTimeoutSeconds);
        options.MaximumParallelInvocationsPerClient = wpOptions.SignalR.MaximumParallelInvocationsPerClient;
    });


    builder.Services.AddCors(options =>
    {
        options.AddDefaultPolicy(policy =>
        {
            var configuredOrigins = wpOptions.Cors.AllowedOrigins;
            if (configuredOrigins.Length > 0)
            {
                // Explicit origins. This path is used in production. The literal
                // "null" is allowed here for packaged Tizen widgets / sandboxed
                // contexts that send `Origin: null` (WithOrigins matches it).
                policy.WithOrigins(configuredOrigins)
                    .AllowAnyHeader()
                    .AllowAnyMethod();

                // Credentials are only safe with explicit, non-wildcard origins.
                // Never combine credentials with "*" or the literal "null".
                var hasUnsafeOrigin = configuredOrigins.Any(o =>
                    o == "*" || string.Equals(o, "null", StringComparison.OrdinalIgnoreCase));
                var allowCredentials = wpOptions.Cors.AllowCredentials && !hasUnsafeOrigin;
                if (allowCredentials)
                {
                    policy.AllowCredentials();
                }

                Log.Information(
                    "CORS: allowing {Count} configured origin(s); credentials={Credentials}.",
                    configuredOrigins.Length, allowCredentials);
            }
            else if (builder.Environment.IsProduction())
            {
                // Fail safe: no any-origin-with-credentials in production.
                Log.Warning("WatchParty:Cors:AllowedOrigins is empty in Production. " +
                    "Browser-based clients (e.g. the Samsung TV/Tizen app) will be blocked by CORS. " +
                    "Native mobile/desktop clients (Flutter) are unaffected. " +
                    "Set WatchParty:Cors:AllowedOrigins — and, for the packaged Tizen widget, its captured " +
                    "Origin (or the literal \"null\") — in appsettings.Production.json or via environment " +
                    "variables. See docs/DEPLOYMENT.md.");
                policy.WithOrigins(Array.Empty<string>())
                    .AllowAnyHeader()
                    .AllowAnyMethod();
            }
            else
            {
                // Development convenience only — gated on !IsProduction().
                Log.Information("CORS: development mode — allowing any origin with credentials (non-production only).");
                policy.SetIsOriginAllowed(_ => true)
                    .AllowAnyHeader()
                    .AllowAnyMethod()
                    .AllowCredentials();
            }
        });
    });

    
    builder.Services.AddRateLimiter(options =>
    {
        options.RejectionStatusCode = 429;

        options.AddPolicy("room-creation", context =>
            RateLimitPartition.GetFixedWindowLimiter(
                partitionKey: context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
                factory: _ => new FixedWindowRateLimiterOptions
                {
                    PermitLimit = wpOptions.RoomCreationRateLimit.MaxRequests,
                    Window = TimeSpan.FromSeconds(wpOptions.RoomCreationRateLimit.WindowSeconds),
                    QueueLimit = 0,
                }));

        options.AddPolicy("room-join", context =>
            RateLimitPartition.GetFixedWindowLimiter(
                partitionKey: context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
                factory: _ => new FixedWindowRateLimiterOptions
                {
                    PermitLimit = wpOptions.RoomJoinRateLimit.MaxRequests,
                    Window = TimeSpan.FromSeconds(wpOptions.RoomJoinRateLimit.WindowSeconds),
                    QueueLimit = 0,
                }));

        options.AddPolicy("room-status", context =>
            RateLimitPartition.GetFixedWindowLimiter(
                partitionKey: context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
                factory: _ => new FixedWindowRateLimiterOptions
                {
                    PermitLimit = wpOptions.RoomStatusRateLimit.MaxRequests,
                    Window = TimeSpan.FromSeconds(wpOptions.RoomStatusRateLimit.WindowSeconds),
                    QueueLimit = 0,
                }));

        // Throttles GET /api/v1/rooms (active-room enumeration / Join screen poll).
        options.AddPolicy("room-list", context =>
            RateLimitPartition.GetFixedWindowLimiter(
                partitionKey: context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
                factory: _ => new FixedWindowRateLimiterOptions
                {
                    PermitLimit = wpOptions.RoomListRateLimit.MaxRequests,
                    Window = TimeSpan.FromSeconds(wpOptions.RoomListRateLimit.WindowSeconds),
                    QueueLimit = 0,
                }));

        options.OnRejected = async (context, _) =>
        {
            context.HttpContext.Response.ContentType = "application/json";
            
            var path = context.HttpContext.Request.Path.Value ?? "";
            var method = context.HttpContext.Request.Method;
            int retryAfter;
            if (path.EndsWith("/join", StringComparison.OrdinalIgnoreCase))
                retryAfter = wpOptions.RoomJoinRateLimit.WindowSeconds;
            else if (path.Contains("/status", StringComparison.OrdinalIgnoreCase))
                retryAfter = wpOptions.RoomStatusRateLimit.WindowSeconds;
            else if (HttpMethods.IsGet(method))
                // GET /api/v1/rooms — the active-room list endpoint.
                retryAfter = wpOptions.RoomListRateLimit.WindowSeconds;
            else
                retryAfter = wpOptions.RoomCreationRateLimit.WindowSeconds;

            context.HttpContext.Response.Headers.RetryAfter = retryAfter.ToString();
            await context.HttpContext.Response.WriteAsJsonAsync(new
            {
                error = "rate_limit_exceeded",
                message = "Too many requests. Try again later.",
                retryAfterSeconds = retryAfter,
            });
        };
    });

    
    builder.Services.AddHealthChecks()
        .AddCheck<RoomHealthCheck>("rooms");

    
    builder.Services.AddHostedService<RoomExpiryService>();

    
    builder.Services.AddSingleton<StateSyncTimerService>();
    builder.Services.AddHostedService(sp => sp.GetRequiredService<StateSyncTimerService>());

    var app = builder.Build();

    
    app.UseMiddleware<ErrorHandlingMiddleware>();
    app.UseSerilogRequestLogging();
    app.UseCors();
    app.UseRateLimiter();

    app.MapControllers();
    app.MapHub<RoomHub>("/hubs/room", options =>
    {
        
        options.Transports = HttpTransportType.WebSockets |
                             HttpTransportType.ServerSentEvents |
                             HttpTransportType.LongPolling;
    });
    app.MapHealthChecks("/health", new HealthCheckOptions
    {
        ResponseWriter = async (context, report) =>
        {
            context.Response.ContentType = "application/json";
            var activeRooms = report.Entries.TryGetValue("rooms", out var entry)
                && entry.Data.TryGetValue("activeRooms", out var count)
                ? count
                : 0;
            await context.Response.WriteAsJsonAsync(new
            {
                status = report.Status.ToString().ToLowerInvariant(),
                activeRooms,
                // Diagnostics for the single-instance/in-memory deployment model
                // (BE-007): a version/uptime jump signals a process recycle, which
                // is when in-memory rooms are lost.
                version = AppVersion,
                uptimeSeconds = (long)(DateTimeOffset.UtcNow - AppStartedAt).TotalSeconds,
            });
        },
    });

    app.Run();
}
catch (Exception ex) when (ex is not HostAbortedException)
{
    Log.Fatal(ex, "Application terminated unexpectedly");
}
finally
{
    Log.CloseAndFlush();
}


public partial class Program { }
