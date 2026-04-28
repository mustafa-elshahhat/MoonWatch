using WatchParty.Server.Exceptions;
using WatchParty.Server.Models;
using WatchParty.Shared.Protocol.Payloads;

namespace WatchParty.Server.Services;





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

    
    public async Task<JoinResult> HandleJoinRoom(string connectionId, string roomCode, string role)
    {
        roomCode = roomCode.ToUpperInvariant();

        if (role != "host" && role != "guest")
            throw new InvalidRoleException(roomCode, role);

        
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

        return new JoinResult(room.RoomCode, "host", GuestPresent: false, room.ContentDescriptor, IsNewGuest: false, PlaybackRate: room.PlaybackRate);
    }

    private JoinResult HandleGuestJoin(Room room, string connectionId)
    {
        if (room.State == RoomState.Created)
            throw new RoomNotFoundException(room.RoomCode, connectionId);

        
        bool isGraceRejoin = false;
        if (room.GuestGraceCts != null)
        {
            room.GuestGraceCts.Cancel();
            room.GuestGraceCts.Dispose();
            room.GuestGraceCts = null;
            isGraceRejoin = true;
            
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

        
        
        bool isReconnect = false;

        
        
        
        bool hostHasPlaybackState = room.HostIsPlaying || room.HostPositionMs > 0;

        
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
            HostPositionUpdatedAtMs: (isReconnect || hostHasPlaybackState) ? room.HostPositionUpdatedAtMs : null,
            PlaybackRate: room.PlaybackRate);
    }

    
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
                
                var leave = CloseRoom(room, "host_disconnected", "host");
                _logger.LogInformation("Host disconnected, room closed {Event} {RoomId} {ConnectionId}",
                    "room.closed", room.RoomCode, connectionId);
                return new DisconnectResult(leave.RoomCode, leave.Role, leave.Reason, leave.PeerConnectionId, null);
            }
            else if (room.Guest?.ConnectionId == connectionId)
            {
                
                return HandleGuestDisconnect(room, connectionId);
            }

            return null;
        }
        finally
        {
            room.Lock.Release();
        }
    }

    
    
    
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
                
            }
        });

        return gracePeriodSeconds;
    }

    private DisconnectResult HandleGuestDisconnect(Room room, string connectionId)
    {
        
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

        
        if (room.GuestGraceCts != null)
        {
            room.GuestGraceCts.Cancel();
            room.GuestGraceCts.Dispose();
            room.GuestGraceCts = null;
        }

        
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

        
        _registry.UnregisterConnection(connectionId);

        
        room.Guest = null;
        room.GuestAway = false;

        if (room.GuestGraceCts != null)
        {
            room.GuestGraceCts.Cancel();
            room.GuestGraceCts.Dispose();
            room.GuestGraceCts = null;
        }

        
        if (room.State == RoomState.Active || room.State == RoomState.Joined)
        {
            room.State = RoomState.Waiting;
        }

        room.LastActivityAt = DateTimeOffset.UtcNow;

        _logger.LogInformation("Guest explicitly left {Event} {RoomId} {ConnectionId}",
            "room.guest_left", room.RoomCode, connectionId);

        return new LeaveResult(room.RoomCode, "guest", reason, hostConnectionId, 0); 
    }

    
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

            return new PlayBroadcast(room.RoomCode, positionMs, serverTimestampMs, room.HostRttMs, room.HostPlaybackSeqNo, room.PlaybackRate);
        }
        finally
        {
            room.Lock.Release();
        }
    }

    
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
    public async Task<SetContentResult> HandleSetContent(string connectionId, IptvContentDescriptor descriptor)
    {
        var room = FindRoom(connectionId);

        await room.Lock.WaitAsync();
        try
        {
            ValidateHostAction(room, connectionId, RoomState.Waiting, RoomState.Joined, RoomState.Active);

            room.ContentDescriptor = descriptor;
            room.LastActivityAt = DateTimeOffset.UtcNow;
            room.PlaybackRate = 1.0;
            room.WasPlayingBeforeBuffering = false;
            room.BufferingEpisodeId = 0;
            room.HostIsPlaying = false;
            room.HostPositionMs = 0;
            room.HostPositionUpdatedAtMs = 0;

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
    public async Task<PingResult> HandlePing(string connectionId, long clientTimestampMs, int clientMeasuredRttMs = 0)
    {
        var room = _registry.FindByConnectionId(connectionId)
            ?? throw new ConnectionNotInRoomException(connectionId);

        await room.Lock.WaitAsync();
        try
        {
            var serverTimestampMs = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
            if (room.Host?.ConnectionId == connectionId && clientMeasuredRttMs > 0 && clientMeasuredRttMs < 10000)
            {
                if (room.HostRttMs <= 0)
                {
                    room.HostRttMs = clientMeasuredRttMs;
                }
                else
                {
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
    public async Task<BufferingStallResult> HandleNotifyBufferingStall(string connectionId, long positionMs, int episodeId)
    {
        var room = FindRoom(connectionId);

        await room.Lock.WaitAsync();
        try
        {
            var (participant, role) = FindParticipant(room, connectionId);

            if (participant.BufferingState == BufferingState.Stalled)
            {
                _logger.LogDebug("Duplicate buffering stall ignored {RoomId} {Role}", room.RoomCode, role);
                return new BufferingStallResult(room.RoomCode, role, null, positionMs);
            }

            var now = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
            if (!room.IsBuffering)
            {
                room.WasPlayingBeforeBuffering = room.HostIsPlaying;
                room.BufferingEpisodeId = episodeId;
            }

            if (role == "host")
            {
                room.HostPositionMs = positionMs;
                room.HostIsPlaying = false;
                room.HostPositionUpdatedAtMs = now;
            }
            else if (room.HostIsPlaying && room.HostPositionUpdatedAtMs > 0)
            {
                var elapsed = now - room.HostPositionUpdatedAtMs;
                if (elapsed > 0)
                {
                    room.HostPositionMs += (long)(elapsed * room.PlaybackRate);
                }
                room.HostPositionUpdatedAtMs = now;
            }

            participant.BufferingState = BufferingState.Stalled;
            room.LastActivityAt = DateTimeOffset.UtcNow;

            var peer = role == "host" ? room.Guest : room.Host;
            var peerConnectionId = peer?.ConnectionId;

            _logger.LogInformation("Buffering stall received {Event} {RoomId} {ConnectionId} {Role} {PositionMs} {EpisodeId}",
                "buffering.stall", room.RoomCode, connectionId, role, room.HostPositionMs, episodeId);

            return new BufferingStallResult(room.RoomCode, role, peerConnectionId, room.HostPositionMs);
        }
        finally
        {
            room.Lock.Release();
        }
    }
    public async Task<BufferingReadyResult> HandleNotifyBufferingReady(string connectionId, int episodeId)
    {
        var room = FindRoom(connectionId);

        await room.Lock.WaitAsync();
        try
        {
            var (participant, role) = FindParticipant(room, connectionId);

            if (participant.BufferingState == BufferingState.Ready || episodeId != room.BufferingEpisodeId)
            {
                _logger.LogDebug("Stale/Duplicate buffering ready ignored {RoomId} {Role} {EpisodeId} (Room has {BufferingEpisodeId})", 
                    room.RoomCode, role, episodeId, room.BufferingEpisodeId);
                return new BufferingReadyResult(room.RoomCode, role, GateOpened: false, ResumePositionMs: 0, IsPlaying: false);
            }

            participant.BufferingState = BufferingState.Ready;
            room.LastActivityAt = DateTimeOffset.UtcNow;

            var hostReady = room.Host?.BufferingState == BufferingState.Ready;
            var guestReady = room.Guest?.BufferingState == BufferingState.Ready;
            var gateOpened = hostReady && guestReady && room.Guest != null && !room.GuestAway;

            if (gateOpened)
            {
                room.HostIsPlaying = room.WasPlayingBeforeBuffering;
                if (room.HostIsPlaying)
                {
                    room.HostPositionUpdatedAtMs = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
                }

                _logger.LogInformation("Buffering gate opened, resume {Event} {RoomId} {ResumePositionMs} {IsPlaying}",
                    "buffering.resume", room.RoomCode, room.HostPositionMs, room.HostIsPlaying);
            }
            else
            {
                _logger.LogInformation("Buffering ready received, waiting for peer {Event} {RoomId} {Role}",
                    "buffering.ready", room.RoomCode, role);
            }

            return new BufferingReadyResult(room.RoomCode, role, gateOpened, room.HostPositionMs, room.HostIsPlaying);
        }
        finally
        {
            room.Lock.Release();
        }
    }

    
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

    public async Task<PlaybackSpeedBroadcast> HandleSetPlaybackSpeed(string connectionId, double speed)
    {
        var room = FindRoom(connectionId);
        await room.Lock.WaitAsync();
        try
        {
            var (_, role) = FindParticipant(room, connectionId);
            if (role != "host")
                throw new RoleUnauthorizedException(room.RoomCode, role);

            // Valid speeds
            double[] allowed = { 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0 };
            if (!allowed.Contains(speed))
            {
                if (speed < 0.5) speed = 0.5;
                else if (speed > 2.0) speed = 2.0;
                else speed = allowed.OrderBy(a => Math.Abs(a - speed)).First();
            }

            var now = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
            if (room.HostIsPlaying && room.HostPositionUpdatedAtMs > 0)
            {
                long elapsed = now - room.HostPositionUpdatedAtMs;
                room.HostPositionMs += (long)(elapsed * room.PlaybackRate);
            }

            room.PlaybackRate = speed;
            room.HostPositionUpdatedAtMs = now;
            room.LastActivityAt = DateTimeOffset.UtcNow;

            _logger.LogInformation("Playback speed changed {Event} {RoomId} {Speed} at {Position}ms",
                "playback.speed", room.RoomCode, speed, room.HostPositionMs);

            return new PlaybackSpeedBroadcast(room.RoomCode, speed, now);
        }
        finally
        {
            room.Lock.Release();
        }
    }

    private Room FindRoom(string connectionId)
    {
        return _registry.FindByConnectionId(connectionId)
            ?? throw new ConnectionNotInRoomException(connectionId);
    }

    
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
