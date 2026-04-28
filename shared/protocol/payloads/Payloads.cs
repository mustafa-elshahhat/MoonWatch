namespace WatchParty.Shared.Protocol.Payloads;





public record IptvContentDescriptor(
    string ContentType,          
    string StreamId,
    string? ContainerExtension,
    string Title)
{
    public string ContentKey => $"{ContentType}|{StreamId}|{ContainerExtension ?? string.Empty}";
}



public record JoinRoomPayload(string RoomCode, string Role);

public record SetContentPayload(IptvContentDescriptor Descriptor);

public record PlayPayload(long PositionMs, long ClientTimestampMs);

public record PausePayload(long PositionMs);

public record SeekPayload(long TargetPositionMs);

public record BufferingStallPayload(long PositionMs);

public record PingPayload(long ClientTimestampMs);
public record SetPlaybackSpeedPayload(double Speed);



public record RoomJoinedPayload(
    string RoomCode,
    string Role,
    bool GuestPresent,
    IptvContentDescriptor? ContentDescriptor,
    long ServerTimestampMs,
    double PlaybackRate = 1.0);

public record RoomGuestJoinedPayload(long ServerTimestampMs);

public record RoomGuestLeftPayload(long ServerTimestampMs, int GracePeriodSeconds);

public record RoomGuestReconnectedPayload(long ServerTimestampMs);

public record RoomClosedPayload(string Reason, long ServerTimestampMs);

public record RoomContentSetPayload(IptvContentDescriptor Descriptor, long ServerTimestampMs);

public record ErrorPayload(string Code, string Message, long ServerTimestampMs);


public record PlaybackPlayPayload(long PositionMs, long ServerTimestampMs, int HostRttMs, int SeqNo, double PlaybackRate = 1.0);


public record PlaybackPausePayload(long PositionMs, long ServerTimestampMs, int SeqNo);



public record PlaybackSeekPayload(long TargetPositionMs, long ServerTimestampMs, int SeqNo, bool IsPlaying);


public record PlaybackStateSyncPayload(long HostPositionMs, bool IsPlaying, long ServerTimestampMs, int SeqNo, double PlaybackRate = 1.0);

public record PlaybackSpeedPayload(double Speed, long ServerTimestampMs);

public record BufferingStallBroadcastPayload(string Role, long PositionMs, long ServerTimestampMs, int EpisodeId);

public record BufferingResumePayload(long ServerTimestampMs, long ResumePositionMs, int EpisodeId, bool IsPlaying);

public record PlayerReadyPayload(bool BothReady, string ReadyRole, long ServerTimestampMs, string ContentKey);

public record PongPayload(long ClientTimestampMs, long ServerTimestampMs);
