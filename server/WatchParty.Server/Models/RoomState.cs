namespace WatchParty.Server.Models;

/// <summary>
/// Room lifecycle states per ROOM_LIFECYCLE.md.
/// </summary>
public enum RoomState
{
    /// <summary>Room code exists. Host HTTP response sent. No SignalR connection yet.</summary>
    Created,

    /// <summary>Host is connected. No guest. Stream URL may or may not be set.</summary>
    Waiting,

    /// <summary>Both participants connected. Stream URL may or may not be set.</summary>
    Joined,

    /// <summary>Both connected, stream URL set. Playback commands accepted.</summary>
    Active,

    /// <summary>Terminal state. Room deallocated from registry.</summary>
    Closed,
}
