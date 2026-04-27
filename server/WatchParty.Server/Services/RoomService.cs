using WatchParty.Server.Exceptions;
using WatchParty.Server.Models;
using WatchParty.Shared.Protocol.Payloads;

namespace WatchParty.Server.Services;

/// <summary>
/// Room business logic. Room lifecycle business logic.
/// Uses per-room SemaphoreSlim to serialize concurrent state mutations.
/// </summary>
public class RoomService : IRoomService
{
    private readonly IRoomRegistry _registry;
    private readonly ILogger<RoomService> _logger;
    private readonly IConfiguration _configuration;

    public RoomService(IRoomRegistry registry, ILogger<RoomService> logger, IConfiguration configuration)
    {
        _registry = registry;
        _logger = logger;
        _configuration = configuration;
    }

    /// <inheritdoc />
    public string CreateRoom()
    {
        var code = RoomCodeGenerator.Generate(c => _registry.TryGet(c, out _));
        var room = new Room(code);
        if (!_registry.TryAdd(code, room))
        {
            throw new InvalidOperationException("Failed to add room to registry after code generation.");
        }

        _logger.LogInformation("Room created {Event} {RoomId}", "room.created", code);
        return code;
    }

    /// <inheritdoc />
    public async Task<JoinResult> HandleJoinRoom(string connectionId, string roomCode, string role)
    {
        roomCode = roomCode.ToUpperInvariant();

        if (role != "host" && role != "guest")
            throw new InvalidRoleException(roomCode, role);

        // Check if connection is already in a room before anything else
        var existing = _registry.FindByConnectionId(connectionId);
        if (existing != null)
            throw new AlreadyJoinedException(connectionId, existing.RoomCode);

        if (!_registry.TryGet(roomCode, out var room) || room == null)
            throw new RoomNotFoundException(roomCode, connectionId);

        await room.Lock.WaitAsync();
        try
        {
            if (room.State == RoomState.Closed)
                throw new RoomClosedException(roomCode);

            if (role == "host")
            {
                return HandleHostJoin(room, connectionId);
            }
            else
            {
                return HandleGuestJoin(room, connectionId);
            }
        }
        finally
        {
            room.Lock.Release();
        }
    }

    private JoinResult HandleHostJoin(Room room, string connectionId)
    {
        if (room.State != RoomState.Created)
            throw new RoomFullException(room.RoomCode);

        room.Host = new RoomParticipant
        {
            ConnectionId = connectionId,
            Role = ParticipantRole.Host,
        };
        room.State = RoomState.Waiting;
        room.LastActivityAt = DateTimeOffset.UtcNow;

        _registry.RegisterConnection(connectionId, room.RoomCode);

        _logger.LogInformation("Host joined {Event} {RoomId} {ConnectionId} {Role}",
            "room.joined", room.RoomCode, connectionId, "host");

        return new JoinResult(room.RoomCode, "host", GuestPresent: false, room.ContentDescriptor, IsNewGuest: false);
    }

    private JoinResult HandleGuestJoin(Room room, string connectionId)
    {
        if (room.State == RoomState.Created)
            throw new RoomNotFoundException(room.RoomCode, connectionId);

        // Cancel guest grace period if active (reconnection)
        bool isGraceRejoin = false;
        if (room.GuestGraceCts != null)
        {
            room.GuestGraceCts.Cancel();
            room.GuestGraceCts.Dispose();
            room.GuestGraceCts = null;
            isGraceRejoin = true;
            // GuestAway is reset below when new guest is assigned
        }

        if (room.Guest != null && !room.GuestAway)
            throw new RoomFullException(room.RoomCode);

        room.Guest = new RoomParticipant
        {
            ConnectionId = connectionId,
            Role = ParticipantRole.Guest,
        };
        room.GuestAway = false;
        room.LastActivityAt = DateTimeOffset.UtcNow;

        _registry.RegisterConnection(connectionId, room.RoomCode);

        // Only a grace-period rejoin is a reconnection;
        // a new guest joining an Active room after grace expiry is a first join.
        bool isReconnect = false;

        // Expose host playback state to any guest if host has started playing.
        // This allows a new guest (not just reconnects) to immediately seek into the right
        // position after their local player initializes, without waiting for the next state_sync.
        bool hostHasPlaybackState = room.HostIsPlaying || room.HostPositionMs > 0;

        // Transition state based on current state and stream URL
        if (room.State == RoomState.Waiting || room.State == RoomState.Joined)
        {
            room.State = room.ContentDescriptor != null ? RoomState.Active : RoomState.Joined;
        }
        else if (room.State == RoomState.Active)
        {
            isReconnect = isGraceRejoin;
        }

        if (isReconnect)
        {
            _logger.LogInformation("Guest reconnected {Event} {RoomId} {ConnectionId}",
                "room.guest_reconnected", room.RoomCode, connectionId);
        }
        else
        {
            _logger.LogInformation("Guest joined {Event} {RoomId} {ConnectionId} {Role}",
                "room.guest_joined", room.RoomCode, connectionId, "guest");
        }

        return new JoinResult(
            room.RoomCode,
            "guest",
            GuestPresent: true,
            room.ContentDescriptor,
            IsNewGuest: !isReconnect,
            HostPositionMs: (isReconnect || hostHasPlaybackState) ? room.HostPositionMs : null,
            HostIsPlaying: (isReconnect || hostHasPlaybackState) ? room.HostIsPlaying : null,
            HostPlaybackSeqNo: (isReconnect || hostHasPlaybackState) ? room.HostPlaybackSeqNo : null,
            HostPositionUpdatedAtMs: (isReconnect || hostHasPlaybackState) ? room.HostPositionUpdatedAtMs : null);
    }

    /// <inheritdoc />
    public async Task<LeaveResult> HandleLeaveRoom(string connectionId)
    {
        var room = _registry.FindByConnectionId(connectionId)
            ?? throw new ConnectionNotInRoomException(connectionId);

        await room.Lock.WaitAsync();
        try
        {
            if (room.Host?.ConnectionId == connectionId)
            {
                return CloseRoom(room, "host_left", "host");
            }
            else
            {
                return HandleGuestLeave(room, connectionId, "guest_left");
            }
        }
        finally
        {
            room.Lock.Release();
        }
    }

    /// <inheritdoc />
    public async Task<DisconnectResult?> HandleDisconnected(string connectionId)
    {
        var room = _registry.FindByConnectionId(connectionId);
        if (room == null)
            return null;

        await room.Lock.WaitAsync();
        try
        {
            if (room.State == RoomState.Closed)
                return null;

            if (room.Host?.ConnectionId == connectionId)
            {
                // Host disconnect → close room immediately (ADR-003)
                var leave = CloseRoom(room, "host_disconnected", "host");
                _logger.LogInformation("Host disconnected, room closed {Event} {RoomId} {ConnectionId}",
                    "room.closed", room.RoomCode, connectionId);
                return new DisconnectResult(leave.RoomCode, leave.Role, leave.Reason, leave.PeerConnectionId, null);
            }
            else if (room.Guest?.ConnectionId == connectionId)
            {
                // Guest disconnect → start grace period
                return HandleGuestDisconnect(room, connectionId);
            }

            return null;
        }
        finally
        {
            room.Lock.Release();
        }
    }

    /// Shared grace period logic for guest disconnect/leave.
    /// Sets GuestAway, transitions state, starts cancellable timer.
    /// Returns the configured grace period in seconds.
    private int StartGuestGracePeriod(Room room)
    {
        var gracePeriodSeconds = _configuration.GetValue("WatchParty:Room:GuestGracePeriodSeconds", 30);

        room.GuestAway = true;
        room.LastActivityAt = DateTimeOffset.UtcNow;
        if (room.Guest != null)
        {
            room.Guest.IsPlayerReady = false;
            room.Guest.BufferingState = BufferingState.Ready;
        }

        if (room.State == RoomState.Joined)
        {
            room.State = RoomState.Waiting;
        }

        room.GuestGraceCts = new CancellationTokenSource();
        var cts = room.GuestGraceCts;
        var roomCode = room.RoomCode;

        _ = Task.Run(async () =>
        {
            try
            {
                await Task.Delay(TimeSpan.FromSeconds(gracePeriodSeconds), cts.Token);
                await room.Lock.WaitAsync();
                try
                {
                    if (room.GuestAway && room.GuestGraceCts == cts)
                    {
                        room.Guest = null;
                        room.GuestAway = false;
                        room.GuestGraceCts = null;
                        _logger.LogInformation("Guest grace period expired {Event} {RoomId}",
                            "room.guest_left", roomCode);
                    }
                }
                finally
                {
                    room.Lock.Release();
                }
            }
            catch (TaskCanceledException)
            {
                // Guest reconnected before grace period expired
            }
        });

        return gracePeriodSeconds;
    }

    private DisconnectResult HandleGuestDisconnect(Room room, string connectionId)
    {
        // Unregister immediately — the physical connection is gone.
        _registry.UnregisterConnection(connectionId);
        var gracePeriodSeconds = StartGuestGracePeriod(room);

        _logger.LogInformation("Guest disconnected, grace period started {Event} {RoomId} {ConnectionId} {GracePeriodSeconds}",
            "room.guest_left", room.RoomCode, connectionId, gracePeriodSeconds);

        return new DisconnectResult(
            room.RoomCode,
            "guest",
            "guest_disconnected",
            room.Host?.ConnectionId,
            gracePeriodSeconds);
    }

    private LeaveResult CloseRoom(Room room, string reason, string callerRole)
    {
        var peerConnectionId = callerRole == "host"
            ? room.Guest?.ConnectionId
            : room.Host?.ConnectionId;

        room.State = RoomState.Closed;

        // Cancel guest grace period if active
        if (room.GuestGraceCts != null)
        {
            room.GuestGraceCts.Cancel();
            room.GuestGraceCts.Dispose();
            room.GuestGraceCts = null;
        }

        // Unregister all participant connections from reverse index
        if (room.Host?.ConnectionId != null)
            _registry.UnregisterConnection(room.Host.ConnectionId);
        if (room.Guest?.ConnectionId != null)
            _registry.UnregisterConnection(room.Guest.ConnectionId);

        _registry.TryRemove(room.RoomCode, out _);

        _logger.LogInformation("Room closed {Event} {RoomId} {Reason}",
            "room.closed", room.RoomCode, reason);

        return new LeaveResult(room.RoomCode, callerRole, reason, peerConnectionId);
    }

    private LeaveResult HandleGuestLeave(Room room, string connectionId, string reason)
    {
        var hostConnectionId = room.Host?.ConnectionId;

        // Unregister immediately
        _registry.UnregisterConnection(connectionId);

        // Fully remove the guest immediately for an explicit leave
        room.Guest = null;
        room.GuestAway = false;

        if (room.GuestGraceCts != null)
        {
            room.GuestGraceCts.Cancel();
            room.GuestGraceCts.Dispose();
            room.GuestGraceCts = null;
        }

        // Room becomes Waiting if it was Active or Joined
        if (room.State == RoomState.Active || room.State == RoomState.Joined)
        {
            room.State = RoomState.Waiting;
        }

        room.LastActivityAt = DateTimeOffset.UtcNow;

        _logger.LogInformation("Guest explicitly left {Event} {RoomId} {ConnectionId}",
            "room.guest_left", room.RoomCode, connectionId);

        return new LeaveResult(room.RoomCode, "guest", reason, hostConnectionId, 0); // Grace period 0 means permanent
    }

    /// <inheritdoc />
    public async Task<PlayBroadcast> HandlePlay(string connectionId, long positionMs, long clientTimestampMs)
    {
        var room = FindRoom(connectionId);

        await room.Lock.WaitAsync();
        try
        {
            ValidateHostAction(room, connectionId, RoomState.Active);

            var serverTimestampMs = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();

            room.HostPositionMs = positionMs;
            room.HostIsPlaying = true;
            room.HostPositionUpdatedAtMs = serverTimestampMs;
            room.LastActivityAt = DateTimeOffset.UtcNow;
            room.HostPlaybackSeqNo++;

            _logger.LogInformation("Playback play {Event} {RoomId} {ConnectionId} {Role} {PositionMs} {SeqNo}",
                "playback.play", room.RoomCode, connectionId, "host", positionMs, room.HostPlaybackSeqNo);

            return new PlayBroadcast(room.RoomCode, positionMs, serverTimestampMs, room.HostRttMs, room.HostPlaybackSeqNo);
        }
        finally
        {
            room.Lock.Release();
        }
    }

    /// <inheritdoc />
    public async Task<PauseBroadcast> HandlePause(string connectionId, long positionMs)
    {
        var room = FindRoom(connectionId);

        await room.Lock.WaitAsync();
        try
        {
            ValidateHostAction(room, connectionId, RoomState.Active);

            var serverTimestampMs = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();

            room.HostPositionMs = positionMs;
            room.HostIsPlaying = false;
            room.HostPositionUpdatedAtMs = serverTimestampMs;
            room.LastActivityAt = DateTimeOffset.UtcNow;
            room.HostPlaybackSeqNo++;

            _logger.LogInformation("Playback pause {Event} {RoomId} {ConnectionId} {Role} {PositionMs} {SeqNo}",
                "playback.pause", room.RoomCode, connectionId, "host", positionMs, room.HostPlaybackSeqNo);

            return new PauseBroadcast(room.RoomCode, positionMs, serverTimestampMs, room.HostPlaybackSeqNo);
        }
        finally
        {
            room.Lock.Release();
        }
    }

    /// <inheritdoc />
    public async Task<SeekBroadcast> HandleSeek(string connectionId, long targetPositionMs)
    {
        var room = FindRoom(connectionId);

        await room.Lock.WaitAsync();
        try
        {
            ValidateHostAction(room, connectionId, RoomState.Active);

            var serverTimestampMs = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();

            room.HostPositionMs = targetPositionMs;
            room.HostPositionUpdatedAtMs = serverTimestampMs;
            room.LastActivityAt = DateTimeOffset.UtcNow;
            room.HostPlaybackSeqNo++;

            _logger.LogInformation("Playback seek {Event} {RoomId} {ConnectionId} {Role} {TargetPositionMs} {SeqNo}",
                "playback.seek", room.RoomCode, connectionId, "host", targetPositionMs, room.HostPlaybackSeqNo);

            return new SeekBroadcast(room.RoomCode, targetPositionMs, serverTimestampMs, room.HostPlaybackSeqNo, room.HostIsPlaying);
        }
        finally
        {
            room.Lock.Release();
        }
    }

    /// <inheritdoc />
    public async Task<SetContentResult> HandleSetContent(string connectionId, IptvContentDescriptor descriptor)
    {
        var room = FindRoom(connectionId);

        await room.Lock.WaitAsync();
        try
        {
            ValidateHostAction(room, connectionId, RoomState.Waiting, RoomState.Joined, RoomState.Active);

            room.ContentDescriptor = descriptor;
            room.LastActivityAt = DateTimeOffset.UtcNow;

            // Reset player readiness for the new content
            if (room.Host != null)
            {
                room.Host.IsPlayerReady = false;
                room.Host.PlayerReadyContentKey = null;
                room.Host.BufferingState = BufferingState.Ready;
            }
            if (room.Guest != null)
            {
                room.Guest.IsPlayerReady = false;
                room.Guest.PlayerReadyContentKey = null;
                room.Guest.BufferingState = BufferingState.Ready;
            }

            room.HostIsPlaying = false;
            room.HostPositionMs = 0;
            room.HostPositionUpdatedAtMs = 0;

            bool transitioned = false;
            if (room.State == RoomState.Joined && room.Guest != null && !room.GuestAway)
            {
                room.State = RoomState.Active;
                transitioned = true;
            }

            _logger.LogInformation("Content set {Event} {RoomId} {ConnectionId} {ContentType} {StreamId}",
                "room.content_set", room.RoomCode, connectionId, descriptor.ContentType, descriptor.StreamId);

            return new SetContentResult(
                room.RoomCode,
                room.Guest?.ConnectionId,
                descriptor,
                transitioned);
        }
        finally
        {
            room.Lock.Release();
        }
    }

    /// <inheritdoc />
    public async Task<PingResult> HandlePing(string connectionId, long clientTimestampMs, int clientMeasuredRttMs = 0)
    {
        var room = _registry.FindByConnectionId(connectionId)
            ?? throw new ConnectionNotInRoomException(connectionId);

        await room.Lock.WaitAsync();
        try
        {
            var serverTimestampMs = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();

            // Store host RTT from client-measured round-trip time (measured by
            // LatencyEstimator on the client, not estimated from clock difference).
            if (room.Host?.ConnectionId == connectionId && clientMeasuredRttMs > 0 && clientMeasuredRttMs < 10000)
            {
                if (room.HostRttMs <= 0)
                {
                    // Seed first measurement directly.
                    room.HostRttMs = clientMeasuredRttMs;
                }
                else
                {
                    // EMA smoothing (α = 0.3) to prevent single-spike corruption.
                    room.HostRttMs = (int)(0.3 * clientMeasuredRttMs + 0.7 * room.HostRttMs);
                }
            }

            return new PingResult(connectionId, clientTimestampMs, serverTimestampMs);
        }
        finally
        {
            room.Lock.Release();
        }
    }

    /// <inheritdoc />
    public async Task<BufferingStallResult> HandleNotifyBufferingStall(string connectionId, long positionMs, int episodeId)
    {
        var room = FindRoom(connectionId);

        await room.Lock.WaitAsync();
        try
        {
            var (participant, role) = FindParticipant(room, connectionId);

            // Idempotent: if already Stalled, ignore
            if (participant.BufferingState == BufferingState.Stalled)
            {
                _logger.LogDebug("Duplicate buffering stall ignored {RoomId} {Role}", room.RoomCode, role);
                return new BufferingStallResult(room.RoomCode, role, null, positionMs);
            }

            participant.BufferingState = BufferingState.Stalled;
            room.LastActivityAt = DateTimeOffset.UtcNow;

            var peer = role == "host" ? room.Guest : room.Host;
            var peerConnectionId = peer?.ConnectionId;

            _logger.LogInformation("Buffering stall received {Event} {RoomId} {ConnectionId} {Role} {PositionMs}",
                "buffering.stall", room.RoomCode, connectionId, role, positionMs);

            return new BufferingStallResult(room.RoomCode, role, peerConnectionId, positionMs);
        }
        finally
        {
            room.Lock.Release();
        }
    }

    /// <inheritdoc />
    public async Task<BufferingReadyResult> HandleNotifyBufferingReady(string connectionId, int episodeId)
    {
        var room = FindRoom(connectionId);

        await room.Lock.WaitAsync();
        try
        {
            var (participant, role) = FindParticipant(room, connectionId);

            // Guard against out-of-sequence ready
            if (participant.BufferingState == BufferingState.Ready)
            {
                _logger.LogDebug("Out-of-sequence buffering ready ignored {RoomId} {Role}", room.RoomCode, role);
                return new BufferingReadyResult(room.RoomCode, role, GateOpened: false, ResumePositionMs: 0);
            }

            participant.BufferingState = BufferingState.Ready;
            room.LastActivityAt = DateTimeOffset.UtcNow;

            // Check if both participants are now Ready (gate opens)
            var hostReady = room.Host?.BufferingState == BufferingState.Ready;
            var guestReady = room.Guest?.BufferingState == BufferingState.Ready;
            var gateOpened = hostReady && guestReady && room.Guest != null && !room.GuestAway;

            if (gateOpened)
            {
                _logger.LogInformation("Buffering gate opened, resume {Event} {RoomId} {ResumePositionMs}",
                    "buffering.resume", room.RoomCode, room.HostPositionMs);
            }
            else
            {
                _logger.LogInformation("Buffering ready received, waiting for peer {Event} {RoomId} {Role}",
                    "buffering.ready", room.RoomCode, role);
            }

            return new BufferingReadyResult(room.RoomCode, role, gateOpened, room.HostPositionMs);
        }
        finally
        {
            room.Lock.Release();
        }
    }

    /// <inheritdoc />
    public async Task<PlayerReadyResult> HandleNotifyPlayerReady(string connectionId, string contentKey)
    {
        var room = FindRoom(connectionId);

        await room.Lock.WaitAsync();
        try
        {
            var (participant, role) = FindParticipant(room, connectionId);
            var activeContentKey = room.ContentDescriptor?.ContentKey;

            if (room.State != RoomState.Active || string.IsNullOrWhiteSpace(activeContentKey))
            {
                _logger.LogDebug("Player ready ignored without active content {RoomId} {Role}",
                    room.RoomCode, role);
                return new PlayerReadyResult(room.RoomCode, role, GateOpened: false, ContentKey: string.Empty, ShouldBroadcast: false);
            }

            if (!string.Equals(contentKey, activeContentKey, StringComparison.Ordinal))
            {
                _logger.LogDebug("Stale player ready ignored {RoomId} {Role} {ContentKey} {ActiveContentKey}",
                    room.RoomCode, role, contentKey, activeContentKey);
                return new PlayerReadyResult(room.RoomCode, role, GateOpened: false, ContentKey: activeContentKey, ShouldBroadcast: false);
            }

            if (participant.IsPlayerReady &&
                string.Equals(participant.PlayerReadyContentKey, activeContentKey, StringComparison.Ordinal))
            {
                _logger.LogDebug("Duplicate player ready ignored {RoomId} {Role}", room.RoomCode, role);
                return new PlayerReadyResult(room.RoomCode, role, GateOpened: false, ContentKey: activeContentKey, ShouldBroadcast: false);
            }

            participant.IsPlayerReady = true;
            participant.PlayerReadyContentKey = activeContentKey;
            room.LastActivityAt = DateTimeOffset.UtcNow;

            var hostReady = room.Host?.IsPlayerReady == true;
            var guestReady = room.Guest?.IsPlayerReady == true;
            var gateOpened = hostReady && guestReady && room.Guest != null && !room.GuestAway;

            if (gateOpened)
            {
                _logger.LogInformation("Both players ready {Event} {RoomId}",
                    "player.ready", room.RoomCode);
            }
            else
            {
                _logger.LogInformation("Player ready received, waiting for peer {Event} {RoomId} {Role}",
                    "player.ready", room.RoomCode, role);
            }

            return new PlayerReadyResult(room.RoomCode, role, gateOpened, activeContentKey, ShouldBroadcast: true);
        }
        finally
        {
            room.Lock.Release();
        }
    }

    private (RoomParticipant participant, string role) FindParticipant(Room room, string connectionId)
    {
        if (room.Host?.ConnectionId == connectionId)
            return (room.Host, "host");
        if (room.Guest?.ConnectionId == connectionId)
            return (room.Guest, "guest");
        throw new ConnectionNotInRoomException(connectionId);
    }

    private Room FindRoom(string connectionId)
    {
        return _registry.FindByConnectionId(connectionId)
            ?? throw new ConnectionNotInRoomException(connectionId);
    }

    /// <summary>Validates host action preconditions. Must be called while holding room.Lock.</summary>
    private static void ValidateHostAction(Room room, string connectionId, params RoomState[] allowedStates)
    {
        if (room.State == RoomState.Closed)
            throw new RoomClosedException(room.RoomCode);

        if (!allowedStates.Contains(room.State))
            throw new InvalidOperationException($"Room '{room.RoomCode}' is not in an allowed state. Current: {room.State}, Allowed: {string.Join(", ", allowedStates)}.");

        if (room.Host?.ConnectionId != connectionId)
            throw new RoleUnauthorizedException(room.RoomCode, "guest", connectionId);
    }

}
