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


var LogDir = Path.Combine(AppContext.BaseDirectory, "logs");
var ServerLogPath = Path.Combine(LogDir, "server.log");
try
{
    Directory.CreateDirectory(LogDir);
    if (File.Exists(ServerLogPath)) File.Delete(ServerLogPath);
}
catch {  }



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

    
    if (builder.Environment.IsProduction() &&
        (wpOptions.Cors.AllowedOrigins == null || wpOptions.Cors.AllowedOrigins.Length == 0))
    {
        throw new InvalidOperationException(
            "WatchParty:Cors:AllowedOrigins must not be empty in Production. " +
            "Configure explicit origins in appsettings.Production.json.");
    }

    
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
            if (wpOptions.Cors.AllowedOrigins.Length > 0)
            {
                policy.WithOrigins(wpOptions.Cors.AllowedOrigins)
                    .AllowAnyHeader()
                    .AllowAnyMethod()
                    .AllowCredentials();
            }
            else
            {
                
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

        options.OnRejected = async (context, _) =>
        {
            context.HttpContext.Response.ContentType = "application/json";
            
            var path = context.HttpContext.Request.Path.Value ?? "";
            int retryAfter;
            if (path.EndsWith("/join", StringComparison.OrdinalIgnoreCase))
                retryAfter = wpOptions.RoomJoinRateLimit.WindowSeconds;
            else if (path.Contains("/status", StringComparison.OrdinalIgnoreCase))
                retryAfter = wpOptions.RoomStatusRateLimit.WindowSeconds;
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
