namespace WatchParty.Server.Configuration;





public class WatchPartyOptions
{
    public RoomOptions Room { get; set; } = new();
    public SignalROptions SignalR { get; set; } = new();
    public SyncOptions Sync { get; set; } = new();
    public CorsOptions Cors { get; set; } = new();
    public PublicRoomListingOptions PublicRoomListing { get; set; } = new();
    public RateLimitOptions RoomCreationRateLimit { get; set; } = new();
    public RateLimitOptions RoomJoinRateLimit { get; set; } = new() { MaxRequests = 30 };
    public RateLimitOptions RoomStatusRateLimit { get; set; } = new() { MaxRequests = 60 };
    public RateLimitOptions RoomListRateLimit { get; set; } = new() { MaxRequests = 30 };
}

public class RoomOptions
{
    public int CodeLength { get; set; } = 6;
    public int CreationExpiryMinutes { get; set; } = 5;
    public int WaitingExpiryMinutes { get; set; } = 30;
    public int ActiveExpiryHours { get; set; } = 2;
    public int GuestGracePeriodSeconds { get; set; } = 30;

    /// <summary>
    /// Seconds the room is kept alive after the host's connection drops, so the
    /// host can rebind a new SignalR connection id (auto-reconnect) without the
    /// room being destroyed. Mirrors <see cref="GuestGracePeriodSeconds"/>.
    /// </summary>
    public int HostGracePeriodSeconds { get; set; } = 30;
}

public class SignalROptions
{
    public int KeepAliveIntervalSeconds { get; set; } = 10;
    public int ClientTimeoutSeconds { get; set; } = 20;
    public int MaximumParallelInvocationsPerClient { get; set; } = 1;
}

public class SyncOptions
{
    public int StateSyncIntervalSeconds { get; set; } = 5;
}

public class CorsOptions
{
    /// <summary>
    /// Explicit browser origins allowed to call the REST API and negotiate
    /// SignalR. Native clients (Flutter dio/signalr_netcore) are not CORS-bound
    /// and are unaffected. A packaged Tizen widget sends a fixed Origin (or the
    /// literal "null"); capture it on hardware and add it here. The literal
    /// value "null" is supported for widget/sandboxed origins, but credentials
    /// are never combined with a wildcard or null origin (see AllowCredentials).
    /// </summary>
    public string[] AllowedOrigins { get; set; } = [];

    /// <summary>
    /// Whether to send Access-Control-Allow-Credentials. Only honored when all
    /// AllowedOrigins are explicit (never "*"/"null"). The browser TV client
    /// uses no cookies, so this can be set false when allowing a null origin.
    /// </summary>
    public bool AllowCredentials { get; set; } = true;
}

public class PublicRoomListingOptions
{
    /// <summary>
    /// When true (default), GET /api/v1/rooms returns safe public summaries of
    /// active rooms so the Samsung TV "Join Room" screen can list them. Set to
    /// false in production to disable public room discovery; the endpoint then
    /// returns an empty list. Never includes credentials or playback URLs.
    /// </summary>
    public bool Enabled { get; set; } = true;
}

public class RateLimitOptions
{
    public int MaxRequests { get; set; } = 10;
    public int WindowSeconds { get; set; } = 60;
}
