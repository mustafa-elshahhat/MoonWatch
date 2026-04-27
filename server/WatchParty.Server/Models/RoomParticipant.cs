namespace WatchParty.Server.Models;

/// <summary>
/// A participant in a room: host or guest.
/// </summary>
public class RoomParticipant
{
    /// <summary>SignalR connection ID.</summary>
    public string ConnectionId { get; set; } = string.Empty;

    /// <summary>Role: Host or Guest.</summary>
    public ParticipantRole Role { get; set; }

    /// <summary>Buffering state: Ready or Stalled.</summary>
    public BufferingState BufferingState { get; set; } = BufferingState.Ready;

    /// <summary>Is the player ready.</summary>
    public bool IsPlayerReady { get; set; } = false;

    /// <summary>Content key the participant last acknowledged as ready.</summary>
    public string? PlayerReadyContentKey { get; set; }
}
