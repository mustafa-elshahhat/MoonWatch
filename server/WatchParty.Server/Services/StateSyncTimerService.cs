using System.Collections.Concurrent;
using Microsoft.AspNetCore.SignalR;
using WatchParty.Server.Hubs;
using WatchParty.Server.Models;
using WatchParty.Shared.Protocol;
using WatchParty.Shared.Protocol.Payloads;

namespace WatchParty.Server.Services;









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
                
                StopForRoom(roomCode);
                return;
            }

            long estimatedPositionMs = 0;
            bool hostIsPlaying = false;
            long serverTimestampMs = 0;
            int hostPlaybackSeqNo = 0;
            long hostPositionMs = 0;
            bool shouldEmit = false;

            await room.Lock.WaitAsync();
            try
            {
                
                if (room.State == RoomState.Active && room.HostIsPlaying)
                {
                    shouldEmit = true;
                    serverTimestampMs = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
                    hostIsPlaying = room.HostIsPlaying;
                    hostPlaybackSeqNo = room.HostPlaybackSeqNo;
                    hostPositionMs = room.HostPositionMs;

                    estimatedPositionMs = hostPositionMs;
                    if (room.HostPositionUpdatedAtMs > 0)
                    {
                        var elapsedMs = serverTimestampMs - room.HostPositionUpdatedAtMs;
                        estimatedPositionMs += (long)(elapsedMs * room.PlaybackRate);
                    }
                }
            }
            finally
            {
                room.Lock.Release();
            }

            if (!shouldEmit)
            {
                return;
            }

            await _hubContext.Clients.Group(roomCode)
                .SendAsync(RoomEvents.PlaybackStateSync, new PlaybackStateSyncPayload(
                    estimatedPositionMs,
                    hostIsPlaying,
                    serverTimestampMs,
                    hostPlaybackSeqNo,
                    room.PlaybackRate));

            _logger.LogDebug("State sync emitted {Event} {RoomId} {HostPositionMs} {EstimatedPositionMs} {IsPlaying}",
                "playback.state_sync", roomCode, hostPositionMs, estimatedPositionMs, hostIsPlaying);
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
