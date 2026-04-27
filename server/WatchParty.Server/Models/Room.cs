using WatchParty.Shared.Protocol.Payloads;

namespace WatchParty.Server.Models;

/// <summary>
/// Room aggregate. Contains all state for a single watch-party room.
/// 
/// </summary>
public class Room
{
    /// <summary>6-character room code (uppercase alphanumeric, 32-char set).</summary>
    public string RoomCode { get; }

    /// <summary>Current lifecycle state.</summary>
    public RoomState State { get; set; } = RoomState.Created;

    /// <summary>Host participant (null until host connects via SignalR).</summary>
    public RoomParticipant? Host { get; set; }

    /// <summary>Guest participant (null until guest connects).</summary>
    public RoomParticipant? Guest { get; set; }

    /// <summary>Content descriptor set by the host. Null until SetContent is called.</summary>
    public IptvContentDescriptor? ContentDescriptor { get; set; }

    /// <summary>Per-room semaphore for serializing state mutations (ADR-007).</summary>
    public SemaphoreSlim Lock { get; } = new(1, 1);

    /// <summary>Cancellation token source for the guest grace period timer.</summary>
    public CancellationTokenSource? GuestGraceCts { get; set; }

    /// <summary>UTC timestamp when the room was created.</summary>
    public DateTimeOffset CreatedAt { get; } = DateTimeOffset.UtcNow;

    /// <summary>UTC timestamp of the last activity (playback command or join).</summary>
    public DateTimeOffset LastActivityAt { get; set; } = DateTimeOffset.UtcNow;

    /// <summary>Host's last known playback position in milliseconds.</summary>
    public long HostPositionMs { get; set; }

    /// <summary>Whether the host is currently playing.</summary>
    public bool HostIsPlaying { get; set; }

    /// <summary>Host's last measured RTT in milliseconds.</summary>
    public int HostRttMs { get; set; }

    /// <summary>
    /// Monotonically increasing sequence counter incremented on every Play, Pause, or Seek command.
    /// Broadcast to clients so they can reject stale commands that arrive out of order.
    /// </summary>
    public int HostPlaybackSeqNo { get; set; }

    /// <summary>
    /// UTC Unix timestamp (ms) when HostPositionMs was last set (on Play, Pause, or Seek).
    /// Used to estimate the host's current position during state_sync emission:
    /// estimatedPosition = HostPositionMs + (nowMs - HostPositionUpdatedAtMs) when HostIsPlaying.
    /// </summary>
    public long HostPositionUpdatedAtMs { get; set; }

    /// <summary>Whether the guest slot is held by a disconnected guest (grace period active).</summary>
    public bool GuestAway { get; set; }

    public Room(string roomCode)
    {
        RoomCode = roomCode;
    }
}
