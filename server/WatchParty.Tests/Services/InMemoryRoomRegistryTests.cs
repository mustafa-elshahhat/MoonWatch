using WatchParty.Server.Models;
using WatchParty.Server.Services;

namespace WatchParty.Tests.Services;

/// <summary>
/// Unit tests for InMemoryRoomRegistry per SV-06.
/// </summary>
public class InMemoryRoomRegistryTests
{
    [Fact]
    public void TryAdd_ReturnsTrueForNewCode()
    {
        var registry = new InMemoryRoomRegistry();
        var room = new Room("ABC123");
        Assert.True(registry.TryAdd("ABC123", room));
    }

    [Fact]
    public void TryAdd_ReturnsFalseForDuplicateCode()
    {
        var registry = new InMemoryRoomRegistry();
        registry.TryAdd("ABC123", new Room("ABC123"));
        Assert.False(registry.TryAdd("ABC123", new Room("ABC123")));
    }

    [Fact]
    public void TryGet_ReturnsRoomIfExists()
    {
        var registry = new InMemoryRoomRegistry();
        var room = new Room("XYZ789");
        registry.TryAdd("XYZ789", room);

        Assert.True(registry.TryGet("XYZ789", out var found));
        Assert.Same(room, found);
    }

    [Fact]
    public void TryGet_ReturnsFalseIfNotFound()
    {
        var registry = new InMemoryRoomRegistry();
        Assert.False(registry.TryGet("NOPE42", out _));
    }

    [Fact]
    public void TryGet_IsCaseInsensitive()
    {
        var registry = new InMemoryRoomRegistry();
        registry.TryAdd("ABC123", new Room("ABC123"));
        Assert.True(registry.TryGet("abc123", out _));
    }

    [Fact]
    public void TryRemove_RemovesAndReturnsRoom()
    {
        var registry = new InMemoryRoomRegistry();
        var room = new Room("DEL456");
        registry.TryAdd("DEL456", room);

        Assert.True(registry.TryRemove("DEL456", out var removed));
        Assert.Same(room, removed);
        Assert.False(registry.TryGet("DEL456", out _));
    }

    [Fact]
    public void TryRemove_ReturnsFalseIfNotFound()
    {
        var registry = new InMemoryRoomRegistry();
        Assert.False(registry.TryRemove("NOPE42", out _));
    }

    [Fact]
    public void GetAll_ReturnsAllRooms()
    {
        var registry = new InMemoryRoomRegistry();
        registry.TryAdd("R1", new Room("R1"));
        registry.TryAdd("R2", new Room("R2"));

        var all = registry.GetAll();
        Assert.Equal(2, all.Count);
    }

    [Fact]
    public void FindByConnectionId_FindsHostConnection()
    {
        var registry = new InMemoryRoomRegistry();
        var room = new Room("FIND01");
        room.Host = new RoomParticipant { ConnectionId = "conn-host", Role = ParticipantRole.Host };
        registry.TryAdd("FIND01", room);
        registry.RegisterConnection("conn-host", "FIND01");

        var found = registry.FindByConnectionId("conn-host");
        Assert.NotNull(found);
        Assert.Equal("FIND01", found.RoomCode);
    }

    [Fact]
    public void FindByConnectionId_FindsGuestConnection()
    {
        var registry = new InMemoryRoomRegistry();
        var room = new Room("FIND02");
        room.Guest = new RoomParticipant { ConnectionId = "conn-guest", Role = ParticipantRole.Guest };
        registry.TryAdd("FIND02", room);
        registry.RegisterConnection("conn-guest", "FIND02");

        var found = registry.FindByConnectionId("conn-guest");
        Assert.NotNull(found);
        Assert.Equal("FIND02", found.RoomCode);
    }

    [Fact]
    public void FindByConnectionId_ReturnsNullIfNotFound()
    {
        var registry = new InMemoryRoomRegistry();
        Assert.Null(registry.FindByConnectionId("nonexistent"));
    }

    [Fact]
    public async Task ThreadSafety_ConcurrentAddRemove()
    {
        var registry = new InMemoryRoomRegistry();
        var tasks = new List<Task>();

        // Add 100 rooms concurrently
        for (int i = 0; i < 100; i++)
        {
            var code = $"R{i:D5}";
            tasks.Add(Task.Run(() => registry.TryAdd(code, new Room(code))));
        }

        await Task.WhenAll(tasks);
        Assert.Equal(100, registry.GetAll().Count);

        // Remove 50 rooms concurrently
        tasks.Clear();
        for (int i = 0; i < 50; i++)
        {
            var code = $"R{i:D5}";
            tasks.Add(Task.Run(() => registry.TryRemove(code, out _)));
        }

        await Task.WhenAll(tasks);
        Assert.Equal(50, registry.GetAll().Count);
    }
}
