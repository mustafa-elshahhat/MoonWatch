namespace WatchParty.Server.Configuration;

/// <summary>
/// Strongly-typed configuration model.
/// Bound from appsettings.json section "WatchParty".
/// </summary>
public class WatchPartyOptions
{
    public RoomOptions Room { get; set; } = new();
    public SignalROptions SignalR { get; set; } = new();
    public SyncOptions Sync { get; set; } = new();
    public CorsOptions Cors { get; set; } = new();
    public RateLimitOptions RoomCreationRateLimit { get; set; } = new();
    public RateLimitOptions RoomJoinRateLimit { get; set; } = new() { MaxRequests = 30 };
    public RateLimitOptions RoomStatusRateLimit { get; set; } = new() { MaxRequests = 60 };
}

public class RoomOptions
{
    public int CodeLength { get; set; } = 6;
    public int CreationExpiryMinutes { get; set; } = 5;
    public int WaitingExpiryMinutes { get; set; } = 30;
    public int ActiveExpiryHours { get; set; } = 2;
    public int GuestGracePeriodSeconds { get; set; } = 30;
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
    public string[] AllowedOrigins { get; set; } = [];
}

public class RateLimitOptions
{
    public int MaxRequests { get; set; } = 10;
    public int WindowSeconds { get; set; } = 60;
}
