using Microsoft.AspNetCore.SignalR;
using WatchParty.Server.Exceptions;
using WatchParty.Server.Services;
using WatchParty.Shared.Protocol;
using WatchParty.Shared.Protocol.Payloads;

namespace WatchParty.Server.Hubs;





public class RoomHub : Hub
{
    private readonly IRoomService _roomService;
    private readonly StateSyncTimerService _stateSyncTimer;
    private readonly ILogger<RoomHub> _logger;

    public RoomHub(IRoomService roomService, StateSyncTimerService stateSyncTimer, ILogger<RoomHub> logger)
    {
        _roomService = roomService;
        _stateSyncTimer = stateSyncTimer;
        _logger = logger;
    }

    
    public async Task CreateRoom()
    {
        try
        {
            _logger.LogDebug("CreateRoom invoked {ConnectionId}", Context.ConnectionId);

            var roomCode = _roomService.CreateRoom();
            var result = await _roomService.HandleJoinRoom(Context.ConnectionId, roomCode, "host");

            await Groups.AddToGroupAsync(Context.ConnectionId, result.RoomCode);

            var serverTimestampMs = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();

            await Clients.Caller.SendAsync(RoomEvents.RoomJoined, new RoomJoinedPayload(
                result.RoomCode,
                result.Role,
                result.GuestPresent,
                result.ContentDescriptor,
                serverTimestampMs,
                result.PlaybackRate ?? 1.0));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error in CreateRoom {ConnectionId}", Context.ConnectionId);
            await SendError("internal_error", "An unexpected error occurred.");
        }
    }

    
    public async Task JoinRoom(string roomCode, string role)
    {
        try
        {
            _logger.LogDebug("JoinRoom invoked {RoomId} {ConnectionId} {Role}",
                roomCode, Context.ConnectionId, role);

            var result = await _roomService.HandleJoinRoom(Context.ConnectionId, roomCode, role);

            await Groups.AddToGroupAsync(Context.ConnectionId, result.RoomCode);

            var serverTimestampMs = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();

            
            await Clients.Caller.SendAsync(RoomEvents.RoomJoined, new RoomJoinedPayload(
                result.RoomCode,
                result.Role,
                result.GuestPresent,
                result.ContentDescriptor,
                serverTimestampMs,
                result.PlaybackRate ?? 1.0));

            
            if (result.Role == "guest" && result.IsNewGuest)
            {
                await Clients.GroupExcept(result.RoomCode, Context.ConnectionId)
                    .SendAsync(RoomEvents.RoomGuestJoined, new RoomGuestJoinedPayload(serverTimestampMs));

                
                
                
                if (result.HostPositionMs.HasValue && result.HostIsPlaying.HasValue)
                {
                    
                    
                    var estimatedPositionMs = result.HostPositionMs.Value;
                    if (result.HostIsPlaying.Value && result.HostPositionUpdatedAtMs.HasValue && result.HostPositionUpdatedAtMs.Value > 0)
                    {
                        var elapsedMs = serverTimestampMs - result.HostPositionUpdatedAtMs.Value;
                        estimatedPositionMs += (long)(elapsedMs * (result.PlaybackRate ?? 1.0));
                    }

                    _logger.LogDebug("Sending immediate state_sync to new guest {ConnectionId} " +
                        "HostPositionMs={HostPositionMs} EstimatedPositionMs={EstimatedPositionMs} HostIsPlaying={HostIsPlaying} SeqNo={SeqNo}",
                        Context.ConnectionId, result.HostPositionMs.Value,
                        estimatedPositionMs,
                        result.HostIsPlaying.Value, result.HostPlaybackSeqNo ?? 0);

                    await Clients.Caller.SendAsync(RoomEvents.PlaybackStateSync, new PlaybackStateSyncPayload(
                        estimatedPositionMs,
                        result.HostIsPlaying.Value,
                        serverTimestampMs,
                        result.HostPlaybackSeqNo ?? 0,
                        result.PlaybackRate ?? 1.0));
                }
            }
            else if (result.Role == "guest" && !result.IsNewGuest)
            {
                
                await Clients.GroupExcept(result.RoomCode, Context.ConnectionId)
                    .SendAsync(RoomEvents.RoomGuestReconnected, new RoomGuestReconnectedPayload(serverTimestampMs));

                
                if (result.HostPositionMs.HasValue && result.HostIsPlaying.HasValue)
                {
                    
                    var estimatedPositionMs = result.HostPositionMs.Value;
                    if (result.HostIsPlaying.Value && result.HostPositionUpdatedAtMs.HasValue && result.HostPositionUpdatedAtMs.Value > 0)
                    {
                        var elapsedMs = serverTimestampMs - result.HostPositionUpdatedAtMs.Value;
                        estimatedPositionMs += (long)(elapsedMs * (result.PlaybackRate ?? 1.0));
                    }

                    await Clients.Caller.SendAsync(RoomEvents.PlaybackStateSync, new PlaybackStateSyncPayload(
                        estimatedPositionMs,
                        result.HostIsPlaying.Value,
                        serverTimestampMs,
                        result.HostPlaybackSeqNo ?? 0,
                        result.PlaybackRate ?? 1.0));
                }
            }
        }
        catch (RoomNotFoundException ex)
        {
            _logger.LogWarning(ex, "JoinRoom: room not found {RoomId} {ConnectionId}", ex.RoomId, Context.ConnectionId);
            await SendError("room_not_found", "Room not found.");
        }
        catch (RoomFullException ex)
        {
            _logger.LogWarning(ex, "JoinRoom: room full {RoomId} {ConnectionId}", ex.RoomId, Context.ConnectionId);
            await SendError("room_full", "Room is already full.");
        }
        catch (RoomClosedException ex)
        {
            _logger.LogWarning(ex, "JoinRoom: room closed {RoomId} {ConnectionId}", ex.RoomId, Context.ConnectionId);
            await SendError("room_closed", "Room has been closed.");
        }
        catch (InvalidRoleException ex)
        {
            _logger.LogWarning(ex, "JoinRoom: invalid role {RoomId} {Role} {ConnectionId}", ex.RoomId, ex.Role, Context.ConnectionId);
            await SendError("role_invalid", "Role must be 'host' or 'guest'.");
        }
        catch (AlreadyJoinedException ex)
        {
            _logger.LogWarning(ex, "JoinRoom: already joined {RoomId} {ConnectionId}", ex.RoomId, Context.ConnectionId);
            await SendError("already_joined", "This connection is already in a room.");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error in JoinRoom {ConnectionId}", Context.ConnectionId);
            await SendError("internal_error", "An unexpected error occurred.");
        }
    }

    
    public async Task LeaveRoom()
    {
        try
        {
            _logger.LogDebug("LeaveRoom invoked {ConnectionId}", Context.ConnectionId);

            var result = await _roomService.HandleLeaveRoom(Context.ConnectionId);

            if (result.Role == "host" || result.Reason == "host_left")
            {
                
                _stateSyncTimer.StopForRoom(result.RoomCode);

                if (result.PeerConnectionId != null)
                {
                    await Clients.Client(result.PeerConnectionId)
                        .SendAsync(RoomEvents.RoomClosed, new RoomClosedPayload(
                            "host_left",
                            DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()));
                }
                await Groups.RemoveFromGroupAsync(Context.ConnectionId, result.RoomCode);
            }
            else
            {
                
                if (result.PeerConnectionId != null)
                {
                    await Clients.Client(result.PeerConnectionId)
                        .SendAsync(RoomEvents.RoomGuestLeft, new RoomGuestLeftPayload(
                            DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(), result.GracePeriodSeconds ?? 30));
                }
                await Groups.RemoveFromGroupAsync(Context.ConnectionId, result.RoomCode);
            }
        }
        catch (ConnectionNotInRoomException)
        {
            _logger.LogWarning("LeaveRoom: connection not in any room {ConnectionId}", Context.ConnectionId);
            await SendError("room_not_found", "Not in a room.");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error in LeaveRoom {ConnectionId}", Context.ConnectionId);
            await SendError("internal_error", "An unexpected error occurred.");
        }
    }

    
    public async Task Play(long positionMs, long clientTimestampMs)
    {
        try
        {
            _logger.LogDebug("Play invoked {ConnectionId} {PositionMs}", Context.ConnectionId, positionMs);

            var result = await _roomService.HandlePlay(Context.ConnectionId, positionMs, clientTimestampMs);

            await Clients.Group(result.RoomCode)
                .SendAsync(RoomEvents.PlaybackPlay, new PlaybackPlayPayload(
                    result.PositionMs,
                    result.ServerTimestampMs,
                    result.HostRttMs,
                    result.SeqNo,
                    result.PlaybackRate));

            
            _stateSyncTimer.StartForRoom(result.RoomCode);
        }
        catch (RoleUnauthorizedException ex)
        {
            _logger.LogWarning(ex, "Unauthorized play attempt by {Role} in {RoomId}", ex.Role, ex.RoomId);
            await SendError("role_unauthorized", "Only the host can control playback.");
        }
        catch (ConnectionNotInRoomException)
        {
            await SendError("room_not_found", "Not in a room.");
        }
        catch (RoomClosedException)
        {
            await SendError("room_closed", "Room has been closed.");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error in Play {ConnectionId}", Context.ConnectionId);
            await SendError("internal_error", "An unexpected error occurred.");
        }
    }

    
    public async Task Pause(long positionMs)
    {
        try
        {
            _logger.LogDebug("Pause invoked {ConnectionId} {PositionMs}", Context.ConnectionId, positionMs);

            var result = await _roomService.HandlePause(Context.ConnectionId, positionMs);

            await Clients.Group(result.RoomCode)
                .SendAsync(RoomEvents.PlaybackPause, new PlaybackPausePayload(
                    result.PositionMs,
                    result.ServerTimestampMs,
                    result.SeqNo));

            
            _stateSyncTimer.StopForRoom(result.RoomCode);
        }
        catch (RoleUnauthorizedException ex)
        {
            _logger.LogWarning(ex, "Unauthorized pause attempt by {Role} in {RoomId}", ex.Role, ex.RoomId);
            await SendError("role_unauthorized", "Only the host can control playback.");
        }
        catch (ConnectionNotInRoomException)
        {
            await SendError("room_not_found", "Not in a room.");
        }
        catch (RoomClosedException)
        {
            await SendError("room_closed", "Room has been closed.");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error in Pause {ConnectionId}", Context.ConnectionId);
            await SendError("internal_error", "An unexpected error occurred.");
        }
    }

    
    public async Task Seek(long targetPositionMs)
    {
        try
        {
            _logger.LogDebug("Seek invoked {ConnectionId} {TargetPositionMs}", Context.ConnectionId, targetPositionMs);

            var result = await _roomService.HandleSeek(Context.ConnectionId, targetPositionMs);

            await Clients.Group(result.RoomCode)
                .SendAsync(RoomEvents.PlaybackSeek, new PlaybackSeekPayload(
                    result.TargetPositionMs,
                    result.ServerTimestampMs,
                    result.SeqNo,
                    result.IsPlaying));
        }
        catch (RoleUnauthorizedException ex)
        {
            _logger.LogWarning(ex, "Unauthorized seek attempt by {Role} in {RoomId}", ex.Role, ex.RoomId);
            await SendError("role_unauthorized", "Only the host can control playback.");
        }
        catch (ConnectionNotInRoomException)
        {
            await SendError("room_not_found", "Not in a room.");
        }
        catch (RoomClosedException)
        {
            await SendError("room_closed", "Room has been closed.");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error in Seek {ConnectionId}", Context.ConnectionId);
            await SendError("internal_error", "An unexpected error occurred.");
        }
    }
    
    public async Task SetPlaybackSpeed(double speed)
    {
        try
        {
            _logger.LogDebug("SetPlaybackSpeed invoked {ConnectionId} {Speed}", Context.ConnectionId, speed);

            var result = await _roomService.HandleSetPlaybackSpeed(Context.ConnectionId, speed);

            await Clients.Group(result.RoomCode)
                .SendAsync(RoomEvents.PlaybackSpeed, new PlaybackSpeedPayload(
                    result.Speed,
                    result.ServerTimestampMs));
        }
        catch (RoleUnauthorizedException ex)
        {
            _logger.LogWarning(ex, "Unauthorized SetPlaybackSpeed attempt by {Role} in {RoomId}", ex.Role, ex.RoomId);
            await SendError("role_unauthorized", "Only the host can control playback speed.");
        }
        catch (ConnectionNotInRoomException)
        {
            await SendError("room_not_found", "Not in a room.");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error in SetPlaybackSpeed {ConnectionId}", Context.ConnectionId);
            await SendError("internal_error", "An unexpected error occurred.");
        }
    }

    
    public async Task SetContent(IptvContentDescriptor descriptor)
    {
        try
        {
            _logger.LogDebug("SetContent invoked {ConnectionId} {ContentType} {StreamId}",
                Context.ConnectionId, descriptor.ContentType, descriptor.StreamId);

            var result = await _roomService.HandleSetContent(Context.ConnectionId, descriptor);
            _stateSyncTimer.StopForRoom(result.RoomCode);

            
            if (result.GuestConnectionId != null)
            {
                var serverTimestampMs = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
                await Clients.Client(result.GuestConnectionId)
                    .SendAsync(RoomEvents.RoomContentSet, new RoomContentSetPayload(
                        result.ContentDescriptor,
                        serverTimestampMs));
            }
        }
        catch (RoleUnauthorizedException ex)
        {
            _logger.LogWarning(ex, "Unauthorized SetContent by {Role} in {RoomId}", ex.Role, ex.RoomId);
            await SendError("role_unauthorized", "Only the host can set content.");
        }
        catch (ConnectionNotInRoomException)
        {
            await SendError("room_not_found", "Not in a room.");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error in SetContent {ConnectionId}", Context.ConnectionId);
            await SendError("internal_error", "An unexpected error occurred.");
        }
    }

    
    public async Task Ping(long clientTimestampMs, int clientMeasuredRttMs = 0)
    {
        try
        {
            var result = await _roomService.HandlePing(Context.ConnectionId, clientTimestampMs, clientMeasuredRttMs);

            await Clients.Caller.SendAsync(RoomEvents.Pong, new PongPayload(
                result.ClientTimestampMs,
                result.ServerTimestampMs));
        }
        catch (ConnectionNotInRoomException)
        {
            await SendError("room_not_found", "Not in a room.");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error in Ping {ConnectionId}", Context.ConnectionId);
            await SendError("internal_error", "An unexpected error occurred.");
        }
    }

    
    public async Task NotifyBufferingStall(long positionMs, int episodeId)
    {
        try
        {
            _logger.LogDebug("NotifyBufferingStall invoked {ConnectionId} {PositionMs} {EpisodeId}",
                Context.ConnectionId, positionMs, episodeId);

            var result = await _roomService.HandleNotifyBufferingStall(Context.ConnectionId, positionMs, episodeId);

            
            _stateSyncTimer.StopForRoom(result.RoomCode);

            
            if (result.PeerConnectionId != null)
            {
                var serverTimestampMs = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
                await Clients.Client(result.PeerConnectionId)
                    .SendAsync(RoomEvents.BufferingStall, new BufferingStallBroadcastPayload(
                        result.CallerRole,
                        result.PositionMs,
                        serverTimestampMs,
                        episodeId));
            }
        }
        catch (ConnectionNotInRoomException)
        {
            await SendError("room_not_found", "Not in a room.");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error in NotifyBufferingStall {ConnectionId}", Context.ConnectionId);
            await SendError("internal_error", "An unexpected error occurred.");
        }
    }

    
    public async Task NotifyPlayerReady(string contentKey)
    {
        try
        {
            _logger.LogDebug("NotifyPlayerReady invoked {ConnectionId} {ContentKey}", Context.ConnectionId, contentKey);

            var result = await _roomService.HandleNotifyPlayerReady(Context.ConnectionId, contentKey);

            if (!result.ShouldBroadcast)
            {
                return;
            }

            var serverTimestampMs = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();

            await Clients.Group(result.RoomCode)
                .SendAsync(RoomEvents.PlayerReady, new PlayerReadyPayload(
                    result.GateOpened,
                    result.CallerRole,
                    serverTimestampMs,
                    result.ContentKey));
        }
        catch (ConnectionNotInRoomException)
        {
            await SendError("room_not_found", "Not in a room.");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error in NotifyPlayerReady {ConnectionId}", Context.ConnectionId);
            await SendError("internal_error", "An unexpected error occurred.");
        }
    }

    
    public async Task NotifyBufferingReady(int episodeId)
    {
        try
        {
            _logger.LogDebug("NotifyBufferingReady invoked {ConnectionId} {EpisodeId}", Context.ConnectionId, episodeId);

            var result = await _roomService.HandleNotifyBufferingReady(Context.ConnectionId, episodeId);

            if (result.GateOpened)
            {
                
                if (result.IsPlaying)
                {
                    _stateSyncTimer.StartForRoom(result.RoomCode);
                }

                
                var serverTimestampMs = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
                await Clients.Group(result.RoomCode)
                    .SendAsync(RoomEvents.BufferingResume, new BufferingResumePayload(
                        serverTimestampMs,
                        result.ResumePositionMs,
                        episodeId,
                        result.IsPlaying));
            }
        }
        catch (ConnectionNotInRoomException)
        {
            await SendError("room_not_found", "Not in a room.");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error in NotifyBufferingReady {ConnectionId}", Context.ConnectionId);
            await SendError("internal_error", "An unexpected error occurred.");
        }
    }

    
    public override async Task OnDisconnectedAsync(Exception? exception)
    {
        try
        {
            _logger.LogDebug("OnDisconnectedAsync {ConnectionId}", Context.ConnectionId);

            var result = await _roomService.HandleDisconnected(Context.ConnectionId);

            if (result != null)
            {
                if (result.Role == "host")
                {
                    
                    _stateSyncTimer.StopForRoom(result.RoomCode);

                    if (result.PeerConnectionId != null)
                    {
                        await Clients.Client(result.PeerConnectionId)
                            .SendAsync(RoomEvents.RoomClosed, new RoomClosedPayload(
                                result.Reason,
                                DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()));
                    }
                }
                else if (result.Role == "guest")
                {
                    
                    if (result.PeerConnectionId != null)
                    {
                        await Clients.Client(result.PeerConnectionId)
                            .SendAsync(RoomEvents.RoomGuestLeft, new RoomGuestLeftPayload(
                                DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(),
                                result.GracePeriodSeconds ?? 30));
                    }
                }

                await Groups.RemoveFromGroupAsync(Context.ConnectionId, result.RoomCode);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error handling disconnect {ConnectionId}", Context.ConnectionId);
        }

        await base.OnDisconnectedAsync(exception);
    }

    private async Task SendError(string code, string message)
    {
        var serverTimestampMs = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
        await Clients.Caller.SendAsync(RoomEvents.RoomError, new ErrorPayload(code, message, serverTimestampMs));
    }
}
