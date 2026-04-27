namespace WatchParty.Shared.Protocol;






public static class RoomEvents
{
    
    public const string RoomJoined = "room:joined";
    public const string RoomGuestJoined = "room:guest_joined";
    public const string RoomGuestLeft = "room:guest_left";
    public const string RoomGuestReconnected = "room:guest_reconnected";
    public const string RoomClosed = "room:closed";
    public const string RoomContentSet = "room:content_set";
    public const string RoomError = "room:error";
    public const string PlayerReady = "player:ready";

    
    public const string PlaybackPlay = "playback:play";
    public const string PlaybackPause = "playback:pause";
    public const string PlaybackSeek = "playback:seek";
    public const string PlaybackStateSync = "playback:state_sync";

    
    public const string BufferingStall = "buffering:stall";
    public const string BufferingReady = "buffering:ready";
    public const string BufferingResume = "buffering:resume";

    
    public const string Pong = "pong";

    
    
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
