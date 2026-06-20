using WatchParty.Server.Models;
using WatchParty.Shared.Protocol.Payloads;

namespace WatchParty.Server.Services;





public interface IRoomService
{
    
    string CreateRoom();

    
    Task<JoinResult> HandleJoinRoom(string connectionId, string roomCode, string role);

    
    Task<LeaveResult> HandleLeaveRoom(string connectionId);

    
    Task<DisconnectResult?> HandleDisconnected(string connectionId);

    
    Task<PlayBroadcast> HandlePlay(string connectionId, long positionMs, long clientTimestampMs);

    
    Task<PauseBroadcast> HandlePause(string connectionId, long positionMs);

    
    Task<SeekBroadcast> HandleSeek(string connectionId, long targetPositionMs);

    
    Task<SetContentResult> HandleSetContent(string connectionId, IptvContentDescriptor descriptor);

    
    Task<PingResult> HandlePing(string connectionId, long clientTimestampMs, int clientMeasuredRttMs = 0);

    
    Task<BufferingStallResult> HandleNotifyBufferingStall(string connectionId, long positionMs, int episodeId);

    
    Task<BufferingReadyResult> HandleNotifyBufferingReady(string connectionId, int episodeId);

    
    Task<PlayerReadyResult> HandleNotifyPlayerReady(string connectionId, string contentKey);
    
    Task<PlaybackSpeedBroadcast> HandleSetPlaybackSpeed(string connectionId, double speed);
}


public record BufferingStallResult(
    string RoomCode,
    string CallerRole,
    string? PeerConnectionId,
    long PositionMs);


public record BufferingReadyResult(
    string RoomCode,
    string CallerRole,
    bool GateOpened,
    long ResumePositionMs,
    bool IsPlaying);


public record PlayerReadyResult(
    string RoomCode,
    string CallerRole,
    bool GateOpened,
    string ContentKey,
    bool ShouldBroadcast);


public record JoinResult(
    string RoomCode,
    string Role,
    bool GuestPresent,
    IptvContentDescriptor? ContentDescriptor,
    bool IsNewGuest,
    long? HostPositionMs = null,
    bool? HostIsPlaying = null,
    int? HostPlaybackSeqNo = null,
    long? HostPositionUpdatedAtMs = null,
    double? PlaybackRate = null,
    bool IsHostReconnect = false);


public record LeaveResult(
    string RoomCode,
    string Role,
    string Reason,
    string? PeerConnectionId,
    int? GracePeriodSeconds = null);


public record DisconnectResult(
    string RoomCode,
    string Role,
    string Reason,
    string? PeerConnectionId,
    int? GracePeriodSeconds);


public record PlayBroadcast(
    string RoomCode,
    long PositionMs,
    long ServerTimestampMs,
    int HostRttMs,
    int SeqNo,
    double PlaybackRate);


public record PauseBroadcast(
    string RoomCode,
    long PositionMs,
    long ServerTimestampMs,
    int SeqNo);

public record PlaybackSpeedBroadcast(
    string RoomCode,
    double Speed,
    long ServerTimestampMs);


public record SeekBroadcast(
    string RoomCode,
    long TargetPositionMs,
    long ServerTimestampMs,
    int SeqNo,
    bool IsPlaying);


public record SetContentResult(
    string RoomCode,
    string? GuestConnectionId,
    IptvContentDescriptor ContentDescriptor,
    bool TransitionedToActive);


public record PingResult(
    string ConnectionId,
    long ClientTimestampMs,
    long ServerTimestampMs);
