using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.Options;
using WatchParty.Server.Configuration;
using WatchParty.Server.Hubs;
using WatchParty.Server.Models;
using WatchParty.Shared.Protocol;
using WatchParty.Shared.Protocol.Payloads;

namespace WatchParty.Server.Services;

/// <summary>
/// Background service that sweeps expired rooms every 60 seconds.
/// Implements room expiry rules:
/// - Created, no host connect within CreationExpiryMinutes (5 min) → Closed
/// - Waiting, no guest joined within WaitingExpiryMinutes (30 min) → Closed
/// - Active, no playback events within ActiveExpiryHours (2 hr) → Closed
/// </summary>
public class RoomExpiryService : BackgroundService
{
    private readonly IRoomRegistry _registry;
    private readonly ILogger<RoomExpiryService> _logger;
    private readonly IOptionsMonitor<WatchPartyOptions> _options;
    private readonly IHubContext<RoomHub> _hubContext;
    private readonly StateSyncTimerService _stateSyncTimer;

    private static readonly TimeSpan SweepInterval = TimeSpan.FromSeconds(60);

    public RoomExpiryService(
        IRoomRegistry registry,
        ILogger<RoomExpiryService> logger,
        IOptionsMonitor<WatchPartyOptions> options,
        IHubContext<RoomHub> hubContext,
        StateSyncTimerService stateSyncTimer)
    {
        _registry = registry;
        _logger = logger;
        _options = options;
        _hubContext = hubContext;
        _stateSyncTimer = stateSyncTimer;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("RoomExpiryService started. Sweep interval: {IntervalSeconds}s", SweepInterval.TotalSeconds);

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await Task.Delay(SweepInterval, stoppingToken);
            }
            catch (OperationCanceledException)
            {
                break;
            }

            try
            {
                await SweepExpiredRoomsAsync();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error during room expiry sweep");
            }
        }

        _logger.LogInformation("RoomExpiryService stopped");
    }

    internal async Task<int> SweepExpiredRoomsAsync()
    {
        var now = DateTimeOffset.UtcNow;
        var roomOptions = _options.CurrentValue.Room;
        var rooms = _registry.GetAll();
        var expiredCount = 0;

        foreach (var room in rooms)
        {
            if (IsExpired(room, now, roomOptions))
            {
                var sendTasks = new List<Task>();
                string? hostId = null;
                string? guestId = null;
                RoomClosedPayload? closedPayload = null;

                await room.Lock.WaitAsync();
                try
                {
                    // Check again after lock — room may have been updated
                    if (room.State == RoomState.Closed)
                    {
                        // Defensive: remove Closed rooms that shouldn't be in registry 
                        _registry.TryRemove(room.RoomCode, out _);
                        continue;
                    }

                    if (!IsExpired(room, now, roomOptions))
                        continue;

                    var previousState = room.State;

                    // Cancel guest grace period if active
                    if (room.GuestGraceCts != null)
                    {
                        room.GuestGraceCts.Cancel();
                        room.GuestGraceCts.Dispose();
                        room.GuestGraceCts = null;
                    }

                    // Stop state sync timer for this room
                    _stateSyncTimer.StopForRoom(room.RoomCode);

                    // Snapshot connection IDs and payload data for async sending outside the lock
                    hostId = room.Host?.ConnectionId;
                    guestId = (room.Guest?.ConnectionId != null && !room.GuestAway) ? room.Guest.ConnectionId : null;
                    var serverTimestampMs = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
                    closedPayload = new RoomClosedPayload("room_expired", serverTimestampMs);

                    room.State = RoomState.Closed;
                    _registry.TryRemove(room.RoomCode, out _);
                    expiredCount++;

                    _logger.LogWarning("Room expired {Event} {RoomId} {PreviousState}",
                        "room.expired", room.RoomCode, previousState);
                }
                finally
                {
                    room.Lock.Release();
                }

                // Create tasks outside the lock block
                if (closedPayload != null)
                {
                    if (hostId != null)
                    {
                        sendTasks.Add(_hubContext.Clients.Client(hostId)
                            .SendAsync(RoomEvents.RoomClosed, closedPayload));
                    }
                    if (guestId != null)
                    {
                        sendTasks.Add(_hubContext.Clients.Client(guestId)
                            .SendAsync(RoomEvents.RoomClosed, closedPayload));
                    }
                }

                if (sendTasks.Count > 0)
                {
                    try
                    {
                        await Task.WhenAll(sendTasks);
                    }
                    catch (Exception ex)
                    {
                        _logger.LogError(ex, "Failed to send room closed events for room {RoomId}", room.RoomCode);
                    }
                }


            }
        }

        if (expiredCount > 0)
        {
            _logger.LogInformation("Room expiry sweep complete {Event} {ExpiredCount} {TotalRooms}",
                "room.expired", expiredCount, rooms.Count);
        }

        return expiredCount;
    }

    private static bool IsExpired(Room room, DateTimeOffset now, RoomOptions options)
    {
        return room.State switch
        {
            // Host created room but never connected via SignalR → 5 minutes
            RoomState.Created =>
                now - room.CreatedAt > TimeSpan.FromMinutes(options.CreationExpiryMinutes),

            // Room is in Waiting state (no guest ever joined) → 30 minutes from host connection
            RoomState.Waiting =>
                now - room.LastActivityAt > TimeSpan.FromMinutes(options.WaitingExpiryMinutes),

            // Room is in Active state with no playback events → 2 hours from last activity
            RoomState.Active =>
                now - room.LastActivityAt > TimeSpan.FromHours(options.ActiveExpiryHours),

            // Joined state: same as Waiting (no guest activity yet beyond joining)
            RoomState.Joined =>
                now - room.LastActivityAt > TimeSpan.FromMinutes(options.WaitingExpiryMinutes),

            // Closed rooms should already be removed, but handle anyway
            RoomState.Closed => true,

            _ => false,
        };
    }
}
