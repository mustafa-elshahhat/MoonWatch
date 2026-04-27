using WatchParty.Server.Models;
using WatchParty.Shared.Protocol.Payloads;

namespace WatchParty.Server.Services;

/// <summary>
/// Room service interface. Encapsulates all business logic for room operations.
/// The hub calls IRoomService; the hub never mutates room state directly.
/// </summary>
public interface IRoomService
{
    /// <summary>Create a new room. Returns room code.</summary>
    string CreateRoom();

    /// <summary>Handle JoinRoom hub method. Returns join result.</summary>
    Task<JoinResult> HandleJoinRoom(string connectionId, string roomCode, string role);

    /// <summary>Handle LeaveRoom hub method.</summary>
    Task<LeaveResult> HandleLeaveRoom(string connectionId);

    /// <summary>Handle host disconnection from OnDisconnectedAsync. Idempotent.</summary>
    Task<DisconnectResult?> HandleDisconnected(string connectionId);

    /// <summary>Handle Play command from host.</summary>
    Task<PlayBroadcast> HandlePlay(string connectionId, long positionMs, long clientTimestampMs);

    /// <summary>Handle Pause command from host.</summary>
    Task<PauseBroadcast> HandlePause(string connectionId, long positionMs);

    /// <summary>Handle Seek command from host.</summary>
    Task<SeekBroadcast> HandleSeek(string connectionId, long targetPositionMs);

    /// <summary>Handle SetContent from host.</summary>
    Task<SetContentResult> HandleSetContent(string connectionId, IptvContentDescriptor descriptor);

    /// <summary>Handle Ping from a participant.</summary>
    Task<PingResult> HandlePing(string connectionId, long clientTimestampMs, int clientMeasuredRttMs = 0);

    /// <summary>Handle NotifyBufferingStall from a participant. Returns stall broadcast info.</summary>
    Task<BufferingStallResult> HandleNotifyBufferingStall(string connectionId, long positionMs, int episodeId);

    /// <summary>Handle NotifyBufferingReady from a participant. Returns resume info if gate opens.</summary>
    Task<BufferingReadyResult> HandleNotifyBufferingReady(string connectionId, int episodeId);

    /// <summary>Handle NotifyPlayerReady from a participant. Returns ready info if both are ready.</summary>
    Task<PlayerReadyResult> HandleNotifyPlayerReady(string connectionId, string contentKey);
}

/// <summary>Result from HandleNotifyBufferingStall.</summary>
public record BufferingStallResult(
    string RoomCode,
    string CallerRole,
    string? PeerConnectionId,
    long PositionMs);

/// <summary>Result from HandleNotifyBufferingReady.</summary>
public record BufferingReadyResult(
    string RoomCode,
    string CallerRole,
    bool GateOpened,
    long ResumePositionMs);

/// <summary>Result from HandleNotifyPlayerReady.</summary>
public record PlayerReadyResult(
    string RoomCode,
    string CallerRole,
    bool GateOpened,
    string ContentKey,
    bool ShouldBroadcast);

/// <summary>Result from JoinRoom.</summary>
public record JoinResult(
    string RoomCode,
    string Role,
    bool GuestPresent,
    IptvContentDescriptor? ContentDescriptor,
    bool IsNewGuest,
    long? HostPositionMs = null,
    bool? HostIsPlaying = null,
    int? HostPlaybackSeqNo = null,
    long? HostPositionUpdatedAtMs = null);

/// <summary>Result from LeaveRoom.</summary>
public record LeaveResult(
    string RoomCode,
    string Role,
    string Reason,
    string? PeerConnectionId,
    int? GracePeriodSeconds = null);

/// <summary>Result from HandleDisconnected.</summary>
public record DisconnectResult(
    string RoomCode,
    string Role,
    string Reason,
    string? PeerConnectionId,
    int? GracePeriodSeconds);

/// <summary>Broadcast data for Play.</summary>
public record PlayBroadcast(
    string RoomCode,
    long PositionMs,
    long ServerTimestampMs,
    int HostRttMs,
    int SeqNo);

/// <summary>Broadcast data for Pause.</summary>
public record PauseBroadcast(
    string RoomCode,
    long PositionMs,
    long ServerTimestampMs,
    int SeqNo);

/// <summary>Broadcast data for Seek.</summary>
public record SeekBroadcast(
    string RoomCode,
    long TargetPositionMs,
    long ServerTimestampMs,
    int SeqNo,
    bool IsPlaying);

/// <summary>Result from SetContent.</summary>
public record SetContentResult(
    string RoomCode,
    string? GuestConnectionId,
    IptvContentDescriptor ContentDescriptor,
    bool TransitionedToActive);

/// <summary>Result from Ping.</summary>
public record PingResult(
    string ConnectionId,
    long ClientTimestampMs,
    long ServerTimestampMs);
