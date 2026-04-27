using Microsoft.Extensions.Diagnostics.HealthChecks;
using WatchParty.Server.Services;

namespace WatchParty.Server.Health;

/// <summary>
/// Custom health check that reports active room count.
/// Returns {"status":"healthy","activeRooms":N} per .
/// </summary>
public class RoomHealthCheck : IHealthCheck
{
    private readonly IRoomRegistry _registry;

    public RoomHealthCheck(IRoomRegistry registry)
    {
        _registry = registry;
    }

    public Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        var activeRooms = _registry.GetAll().Count;
        var data = new Dictionary<string, object>
        {
            { "activeRooms", activeRooms },
        };

        return Task.FromResult(HealthCheckResult.Healthy("Healthy", data));
    }
}
