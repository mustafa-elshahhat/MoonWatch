using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Moq;
using WatchParty.Server.Configuration;
using WatchParty.Server.Controllers;
using WatchParty.Server.Models;
using WatchParty.Server.Services;

namespace WatchParty.Tests.Controllers;

public class RoomsControllerTests
{
    private static RoomsController CreateController(IRoomRegistry registry, WatchPartyOptions? options = null) =>
        new(
            Mock.Of<IRoomService>(),
            registry,
            Mock.Of<ILogger<RoomsController>>(),
            Options.Create(options ?? new WatchPartyOptions()));

    [Fact]
    public void ListRooms_ReturnsAllActiveRooms()
    {
        var registry = new InMemoryRoomRegistry();

        var waiting = new Room("WAIT01")
        {
            State = RoomState.Waiting,
            Host = new RoomParticipant { ConnectionId = "host-1", Role = ParticipantRole.Host },
        };
        registry.TryAdd(waiting.RoomCode, waiting);

        var guestAway = new Room("AWAY01")
        {
            State = RoomState.Active,
            Host = new RoomParticipant { ConnectionId = "host-2", Role = ParticipantRole.Host },
            Guest = new RoomParticipant { ConnectionId = "guest-2", Role = ParticipantRole.Guest },
            GuestAway = true,
        };
        registry.TryAdd(guestAway.RoomCode, guestAway);

        var full = new Room("FULL01")
        {
            State = RoomState.Active,
            Host = new RoomParticipant { ConnectionId = "host-3", Role = ParticipantRole.Host },
            Guest = new RoomParticipant { ConnectionId = "guest-3", Role = ParticipantRole.Guest },
        };
        registry.TryAdd(full.RoomCode, full);

        var created = new Room("CREA01")
        {
            State = RoomState.Created,
        };
        registry.TryAdd(created.RoomCode, created);

        var closed = new Room("CLOS01")
        {
            State = RoomState.Closed,
            Host = new RoomParticipant { ConnectionId = "host-4", Role = ParticipantRole.Host },
        };
        registry.TryAdd(closed.RoomCode, closed);

        var hostMissing = new Room("MISS01")
        {
            State = RoomState.Waiting,
        };
        registry.TryAdd(hostMissing.RoomCode, hostMissing);

        var controller = CreateController(registry);

        var result = controller.ListRooms();

        var ok = Assert.IsType<OkObjectResult>(result);
        using var json = JsonDocument.Parse(JsonSerializer.Serialize(ok.Value));
        var rooms = json.RootElement.GetProperty("rooms");
        var codes = rooms.EnumerateArray()
            .Select(r => r.GetProperty("roomCode").GetString())
            .ToList();

        Assert.Contains("WAIT01", codes);
        Assert.Contains("AWAY01", codes);
        Assert.Contains("FULL01", codes);
        Assert.DoesNotContain("CREA01", codes);
        Assert.DoesNotContain("CLOS01", codes);
        Assert.Contains("MISS01", codes);

        // BE-004: the public summary must not leak internal latency state.
        foreach (var room in rooms.EnumerateArray())
        {
            Assert.False(room.TryGetProperty("hostRtt", out _), "hostRtt must not be in the public room summary.");
        }
    }

    [Fact]
    public void ListRooms_WhenPublicListingDisabled_ReturnsEmpty()
    {
        var registry = new InMemoryRoomRegistry();
        var waiting = new Room("WAIT01")
        {
            State = RoomState.Waiting,
            Host = new RoomParticipant { ConnectionId = "host-1", Role = ParticipantRole.Host },
        };
        registry.TryAdd(waiting.RoomCode, waiting);

        var options = new WatchPartyOptions();
        options.PublicRoomListing.Enabled = false;
        var controller = CreateController(registry, options);

        var result = controller.ListRooms();

        var ok = Assert.IsType<OkObjectResult>(result);
        using var json = JsonDocument.Parse(JsonSerializer.Serialize(ok.Value));
        var rooms = json.RootElement.GetProperty("rooms");
        Assert.Empty(rooms.EnumerateArray());
    }
}
