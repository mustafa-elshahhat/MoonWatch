using WatchParty.Shared.Protocol.Payloads;

namespace WatchParty.Server.Models;

public class Room
{
    public string RoomCode { get; }

    public RoomState State { get; set; } = RoomState.Created;

    public RoomParticipant? Host { get; set; }

    public RoomParticipant? Guest { get; set; }

    public IptvContentDescriptor? ContentDescriptor { get; set; }

    public SemaphoreSlim Lock { get; } = new(1, 1);

    public CancellationTokenSource? GuestGraceCts { get; set; }

    public DateTimeOffset CreatedAt { get; } = DateTimeOffset.UtcNow;

    public DateTimeOffset LastActivityAt { get; set; } = DateTimeOffset.UtcNow;

    public long HostPositionMs { get; set; }

    public bool HostIsPlaying { get; set; }

    public bool WasPlayingBeforeBuffering { get; set; }
    public int BufferingEpisodeId { get; set; }

    public bool IsBuffering => (Host?.BufferingState == BufferingState.Stalled) || (Guest?.BufferingState == BufferingState.Stalled);

    public int HostRttMs { get; set; }

    public int HostPlaybackSeqNo { get; set; }

    public long HostPositionUpdatedAtMs { get; set; }

    public bool GuestAway { get; set; }

    public double PlaybackRate { get; set; } = 1.0;

    public Room(string roomCode)
    {
        RoomCode = roomCode;
    }
}
