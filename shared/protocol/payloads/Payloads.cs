namespace WatchParty.Shared.Protocol.Payloads;

// ── Content descriptor ───────────────────────────────────────────────────────

/// Identifies IPTV content without embedding credentials.
/// Each client resolves the final playback URL locally using its own account.
public record IptvContentDescriptor(
    string ContentType,          // "live" | "movie" | "episode"
    string StreamId,
    string? ContainerExtension,
    string Title)
{
    public string ContentKey => $"{ContentType}|{StreamId}|{ContainerExtension ?? string.Empty}";
}

// ── Client → Server payloads ──────────────────────────────────────────────────

public record JoinRoomPayload(string RoomCode, string Role);

public record SetContentPayload(IptvContentDescriptor Descriptor);

public record PlayPayload(long PositionMs, long ClientTimestampMs);

public record PausePayload(long PositionMs);

public record SeekPayload(long TargetPositionMs);

public record BufferingStallPayload(long PositionMs);

public record PingPayload(long ClientTimestampMs);

// ── Server → Client payloads ──────────────────────────────────────────────────

public record RoomJoinedPayload(
    string RoomCode,
    string Role,
    bool GuestPresent,
    IptvContentDescriptor? ContentDescriptor,
    long ServerTimestampMs);

public record RoomGuestJoinedPayload(long ServerTimestampMs);

public record RoomGuestLeftPayload(long ServerTimestampMs, int GracePeriodSeconds);

public record RoomGuestReconnectedPayload(long ServerTimestampMs);

public record RoomClosedPayload(string Reason, long ServerTimestampMs);

public record RoomContentSetPayload(IptvContentDescriptor Descriptor, long ServerTimestampMs);

public record ErrorPayload(string Code, string Message, long ServerTimestampMs);

/// <param name="SeqNo">Monotonically increasing room playback command counter. Clients reject stale commands.</param>
public record PlaybackPlayPayload(long PositionMs, long ServerTimestampMs, int HostRttMs, int SeqNo);

/// <param name="SeqNo">Monotonically increasing room playback command counter.</param>
public record PlaybackPausePayload(long PositionMs, long ServerTimestampMs, int SeqNo);

/// <param name="SeqNo">Monotonically increasing room playback command counter.</param>
/// <param name="IsPlaying">Whether host was playing immediately before the seek. Guest uses this to decide whether to resume after seek.</param>
public record PlaybackSeekPayload(long TargetPositionMs, long ServerTimestampMs, int SeqNo, bool IsPlaying);

/// <param name="SeqNo">Room playback command counter at time of emission. Clients use this to detect stale state_sync.</param>
public record PlaybackStateSyncPayload(long HostPositionMs, bool IsPlaying, long ServerTimestampMs, int SeqNo);

public record BufferingStallBroadcastPayload(string Role, long PositionMs, long ServerTimestampMs, int EpisodeId);

public record BufferingResumePayload(long ServerTimestampMs, long ResumePositionMs, int EpisodeId);

public record PlayerReadyPayload(bool BothReady, string ReadyRole, long ServerTimestampMs, string ContentKey);

public record PongPayload(long ClientTimestampMs, long ServerTimestampMs);
