using System.Collections.Concurrent;
using Microsoft.AspNetCore.SignalR;
using WatchParty.Server.Hubs;
using WatchParty.Server.Models;
using WatchParty.Shared.Protocol;
using WatchParty.Shared.Protocol.Payloads;

namespace WatchParty.Server.Services;

/// <summary>
/// Manages per-room periodic playback:state_sync emission.
/// Per SYNC_ENGINE.md §Server-Side Sync Responsibilities:
/// the server must emit playback:state_sync every kStateSyncIntervalMs (5000ms)
/// while the room is Active and HostIsPlaying == true.
///
/// Registered as a singleton IHostedService for clean lifecycle management.
/// </summary>
public class StateSyncTimerService : IHostedService, IDisposable
{
    private readonly IHubContext<RoomHub> _hubContext;
    private readonly IRoomRegistry _roomRegistry;
    private readonly IConfiguration _configuration;
    private readonly ILogger<StateSyncTimerService> _logger;

    private readonly ConcurrentDictionary<string, Timer> _timers = new();

    public StateSyncTimerService(
        IHubContext<RoomHub> hubContext,
        IRoomRegistry roomRegistry,
        IConfiguration configuration,
        ILogger<StateSyncTimerService> logger)
    {
        _hubContext = hubContext;
        _roomRegistry = roomRegistry;
        _configuration = configuration;
        _logger = logger;
    }

    public Task StartAsync(CancellationToken cancellationToken) => Task.CompletedTask;

    public Task StopAsync(CancellationToken cancellationToken)
    {
        StopAll();
        return Task.CompletedTask;
    }

    /// <summary>
    /// Start periodic state_sync for a room. Idempotent — stops existing timer if any.
    /// Called when the host sends a Play command.
    /// </summary>
    public void StartForRoom(string roomCode)
    {
        StopForRoom(roomCode);

        var intervalSeconds = _configuration.GetValue("WatchParty:Sync:StateSyncIntervalSeconds", 5);
        var interval = TimeSpan.FromSeconds(intervalSeconds);

        var timer = new Timer(
            callback: _ => _ = EmitStateSyncAsync(roomCode),
            state: null,
            dueTime: interval,
            period: interval);

        _timers[roomCode] = timer;

        _logger.LogDebug("State sync timer started for room {RoomId}, interval={IntervalSeconds}s",
            roomCode, intervalSeconds);
    }

    /// <summary>
    /// Stop periodic state_sync for a room. Idempotent.
    /// Called when the host sends a Pause command, or when the room is closed/removed.
    /// </summary>
    public void StopForRoom(string roomCode)
    {
        if (_timers.TryRemove(roomCode, out var timer))
        {
            timer.Dispose();
            _logger.LogDebug("State sync timer stopped for room {RoomId}", roomCode);
        }
    }

    private async Task EmitStateSyncAsync(string roomCode)
    {
        try
        {
            if (!_roomRegistry.TryGet(roomCode, out var room) || room == null)
            {
                // Room was removed — stop the timer
                StopForRoom(roomCode);
                return;
            }

            // Only emit if room is Active and host is playing
            if (room.State != RoomState.Active || !room.HostIsPlaying)
            {
                return;
            }

            var serverTimestampMs = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();

            // Compute estimated host position: advance from last-known anchor
            // by elapsed playback time since the anchor was set.
            var estimatedPositionMs = room.HostPositionMs;
            if (room.HostIsPlaying && room.HostPositionUpdatedAtMs > 0)
            {
                estimatedPositionMs += serverTimestampMs - room.HostPositionUpdatedAtMs;
            }

            await _hubContext.Clients.Group(roomCode)
                .SendAsync(RoomEvents.PlaybackStateSync, new PlaybackStateSyncPayload(
                    estimatedPositionMs,
                    room.HostIsPlaying,
                    serverTimestampMs,
                    room.HostPlaybackSeqNo));

            _logger.LogDebug("State sync emitted {Event} {RoomId} {HostPositionMs} {EstimatedPositionMs} {IsPlaying}",
                "playback.state_sync", roomCode, room.HostPositionMs, estimatedPositionMs, room.HostIsPlaying);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error emitting state sync for room {RoomId}", roomCode);
        }
    }

    private void StopAll()
    {
        foreach (var kvp in _timers)
        {
            kvp.Value.Dispose();
        }
        _timers.Clear();
    }

    public void Dispose()
    {
        StopAll();
        GC.SuppressFinalize(this);
    }
}
