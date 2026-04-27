namespace WatchParty.Shared.Protocol;

/// <summary>
/// Canonical SignalR event name constants for the WatchParty room protocol.
/// These are the exact strings used in SignalR SendAsync and On calls.
/// Do not use any other strings — always reference these constants.
/// </summary>
public static class RoomEvents
{
    // ── Room lifecycle (server → client) ──────────────────────────────────────
    public const string RoomJoined = "room:joined";
    public const string RoomGuestJoined = "room:guest_joined";
    public const string RoomGuestLeft = "room:guest_left";
    public const string RoomGuestReconnected = "room:guest_reconnected";
    public const string RoomClosed = "room:closed";
    public const string RoomContentSet = "room:content_set";
    public const string RoomError = "room:error";
    public const string PlayerReady = "player:ready";

    // ── Playback commands (server → client) ───────────────────────────────────
    public const string PlaybackPlay = "playback:play";
    public const string PlaybackPause = "playback:pause";
    public const string PlaybackSeek = "playback:seek";
    public const string PlaybackStateSync = "playback:state_sync";

    // ── Buffering coordination (server → client) ──────────────────────────────
    public const string BufferingStall = "buffering:stall";
    public const string BufferingReady = "buffering:ready";
    public const string BufferingResume = "buffering:resume";

    // ── Latency measurement ───────────────────────────────────────────────────
    public const string Pong = "pong";

    // ── Hub method names (client → server calls) ──────────────────────────────
    // These are the method names declared on RoomHub.
    public const string HubCreateRoom = "CreateRoom";
    public const string HubJoinRoom = "JoinRoom";
    public const string HubLeaveRoom = "LeaveRoom";
    public const string HubSetContent = "SetContent";
    public const string HubPlay = "Play";
    public const string HubPause = "Pause";
    public const string HubSeek = "Seek";
    public const string HubNotifyBufferingStall = "NotifyBufferingStall";
    public const string HubNotifyBufferingReady = "NotifyBufferingReady";
    public const string HubNotifyPlayerReady = "NotifyPlayerReady";
    public const string HubPing = "Ping";
}
