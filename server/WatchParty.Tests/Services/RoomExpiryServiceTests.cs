using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Moq;
using WatchParty.Server.Configuration;
using WatchParty.Server.Hubs;
using WatchParty.Server.Models;
using WatchParty.Server.Services;

namespace WatchParty.Tests.Services;

public class RoomExpiryServiceTests
{
    private readonly InMemoryRoomRegistry _registry = new();
    private readonly Mock<ILogger<RoomExpiryService>> _loggerMock = new();
    private readonly WatchPartyOptions _options = new();
    private readonly RoomExpiryService _service;

    public RoomExpiryServiceTests()
    {
        var optionsMonitor = new Mock<IOptionsMonitor<WatchPartyOptions>>();
        optionsMonitor.Setup(o => o.CurrentValue).Returns(_options);

        var hubContext = new Mock<IHubContext<RoomHub>>();
        var mockClients = new Mock<IHubClients>();
        var mockClientProxy = new Mock<ISingleClientProxy>();
        mockClients.Setup(c => c.Client(It.IsAny<string>())).Returns(mockClientProxy.Object);
        hubContext.Setup(h => h.Clients).Returns(mockClients.Object);

        var stateSyncTimer = new StateSyncTimerService(
            hubContext.Object, _registry,
            new Mock<IConfiguration>().Object,
            new Mock<ILogger<StateSyncTimerService>>().Object);

        _service = new RoomExpiryService(_registry, _loggerMock.Object, optionsMonitor.Object,
            hubContext.Object, stateSyncTimer);
    }

    [Fact]
    public async Task SweepExpiredRooms_RemovesCreatedRoomExpired()
    {
        // Created room older than CreationExpiryMinutes (5 min)
        var room = CreateRoom("AAAAAA", RoomState.Created);
        SetCreatedAt(room, DateTimeOffset.UtcNow.AddMinutes(-6));
        _registry.TryAdd(room.RoomCode, room);

        var expired = await _service.SweepExpiredRoomsAsync();

        Assert.Equal(1, expired);
        Assert.False(_registry.TryGet("AAAAAA", out _));
    }

    [Fact]
    public async Task SweepExpiredRooms_DoesNotRemoveRecentCreatedRoom()
    {
        var room = CreateRoom("BBBBBB", RoomState.Created);
        // Created just now — not expired
        _registry.TryAdd(room.RoomCode, room);

        var expired = await _service.SweepExpiredRoomsAsync();

        Assert.Equal(0, expired);
        Assert.True(_registry.TryGet("BBBBBB", out _));
    }

    [Fact]
    public async Task SweepExpiredRooms_RemovesWaitingRoomExpired()
    {
        // Waiting room older than WaitingExpiryMinutes (30 min)
        var room = CreateRoom("CCCCCC", RoomState.Waiting);
        room.LastActivityAt = DateTimeOffset.UtcNow.AddMinutes(-31);
        _registry.TryAdd(room.RoomCode, room);

        var expired = await _service.SweepExpiredRoomsAsync();

        Assert.Equal(1, expired);
        Assert.False(_registry.TryGet("CCCCCC", out _));
    }

    [Fact]
    public async Task SweepExpiredRooms_DoesNotRemoveRecentWaitingRoom()
    {
        var room = CreateRoom("DDDDDD", RoomState.Waiting);
        room.LastActivityAt = DateTimeOffset.UtcNow.AddMinutes(-10);
        _registry.TryAdd(room.RoomCode, room);

        var expired = await _service.SweepExpiredRoomsAsync();

        Assert.Equal(0, expired);
        Assert.True(_registry.TryGet("DDDDDD", out _));
    }

    [Fact]
    public async Task SweepExpiredRooms_RemovesActiveRoomExpired()
    {
        // Active room with no activity for > ActiveExpiryHours (2 hr)
        var room = CreateRoom("EEEEEE", RoomState.Active);
        room.LastActivityAt = DateTimeOffset.UtcNow.AddHours(-3);
        _registry.TryAdd(room.RoomCode, room);

        var expired = await _service.SweepExpiredRoomsAsync();

        Assert.Equal(1, expired);
        Assert.False(_registry.TryGet("EEEEEE", out _));
    }

    [Fact]
    public async Task SweepExpiredRooms_DoesNotRemoveRecentActiveRoom()
    {
        var room = CreateRoom("FFFFFF", RoomState.Active);
        room.LastActivityAt = DateTimeOffset.UtcNow.AddMinutes(-30);
        _registry.TryAdd(room.RoomCode, room);

        var expired = await _service.SweepExpiredRoomsAsync();

        Assert.Equal(0, expired);
        Assert.True(_registry.TryGet("FFFFFF", out _));
    }

    [Fact]
    public async Task SweepExpiredRooms_RemovesJoinedRoomExpired()
    {
        // Joined room older than WaitingExpiryMinutes
        var room = CreateRoom("GGGGGG", RoomState.Joined);
        room.LastActivityAt = DateTimeOffset.UtcNow.AddMinutes(-31);
        _registry.TryAdd(room.RoomCode, room);

        var expired = await _service.SweepExpiredRoomsAsync();

        Assert.Equal(1, expired);
    }

    [Fact]
    public async Task SweepExpiredRooms_CancelsGuestGracePeriod()
    {
        var room = CreateRoom("HHHHHH", RoomState.Active);
        room.LastActivityAt = DateTimeOffset.UtcNow.AddHours(-3);
        room.GuestGraceCts = new CancellationTokenSource();
        _registry.TryAdd(room.RoomCode, room);

        var expired = await _service.SweepExpiredRoomsAsync();

        Assert.Equal(1, expired);
        Assert.Null(room.GuestGraceCts);
    }

    [Fact]
    public async Task SweepExpiredRooms_MultipleMixed()
    {
        // 2 expired, 1 not expired
        var expired1 = CreateRoom("AAAAAA", RoomState.Created);
        SetCreatedAt(expired1, DateTimeOffset.UtcNow.AddMinutes(-6));
        _registry.TryAdd(expired1.RoomCode, expired1);

        var expired2 = CreateRoom("BBBBBB", RoomState.Waiting);
        expired2.LastActivityAt = DateTimeOffset.UtcNow.AddMinutes(-31);
        _registry.TryAdd(expired2.RoomCode, expired2);

        var active = CreateRoom("CCCCCC", RoomState.Active);
        active.LastActivityAt = DateTimeOffset.UtcNow;
        _registry.TryAdd(active.RoomCode, active);

        var count = await _service.SweepExpiredRoomsAsync();

        Assert.Equal(2, count);
        Assert.True(_registry.TryGet("CCCCCC", out _));
    }

    [Fact]
    public async Task SweepExpiredRooms_RemovesAlreadyClosedRoomsFromRegistry()
    {
        var room = CreateRoom("JJJJJJ", RoomState.Closed);
        // Manually add — typically shouldn't be in registry but test the defensive cleanup
        _registry.TryAdd(room.RoomCode, room);

        var expired = await _service.SweepExpiredRoomsAsync();

        // Closed rooms are defensively removed from registry  but not counted as expired
        Assert.Equal(0, expired);
        Assert.False(_registry.TryGet("JJJJJJ", out _));
    }

    private static Room CreateRoom(string code, RoomState state)
    {
        var room = new Room(code) { State = state };
        return room;
    }

    private static void SetCreatedAt(Room room, DateTimeOffset time)
    {
        // Use reflection to set the read-only CreatedAt property for testing
        var field = typeof(Room).GetField("<CreatedAt>k__BackingField",
            System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
        field?.SetValue(room, time);
    }
}
