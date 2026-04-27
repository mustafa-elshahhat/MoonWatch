using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Moq;
using WatchParty.Server.Exceptions;
using WatchParty.Server.Models;
using WatchParty.Server.Services;
using WatchParty.Shared.Protocol.Payloads;

namespace WatchParty.Tests.Services;

/// <summary>
/// Unit tests for RoomService per  and .
/// Tests all state transitions and role authorization.
/// </summary>
public class RoomServiceTests
{
    private readonly IRoomRegistry _registry;
    private readonly RoomService _service;

    public RoomServiceTests()
    {
        _registry = new InMemoryRoomRegistry();
        var logger = Mock.Of<ILogger<RoomService>>();
        var config = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["WatchParty:Room:GuestGracePeriodSeconds"] = "30"
            })
            .Build();
        _service = new RoomService(_registry, logger, config);
    }

    // ── CreateRoom ───────────────────────────────────────────────────────────

    [Fact]
    public void CreateRoom_ReturnsValidCode()
    {
        var code = _service.CreateRoom();
        Assert.Equal(6, code.Length);
        Assert.True(_registry.TryGet(code, out var room));
        Assert.Equal(RoomState.Created, room!.State);
    }

    // ── JoinRoom — Host ──────────────────────────────────────────────────────

    [Fact]
    public async Task JoinRoom_HostJoinsCreatedRoom_TransitionsToWaiting()
    {
        var code = _service.CreateRoom();
        var result = await _service.HandleJoinRoom("host-conn", code, "host");

        Assert.Equal(code, result.RoomCode);
        Assert.Equal("host", result.Role);

        _registry.TryGet(code, out var room);
        Assert.Equal(RoomState.Waiting, room!.State);
        Assert.Equal("host-conn", room.Host!.ConnectionId);
    }

    [Fact]
    public async Task JoinRoom_SecondHostJoin_ThrowsRoomFull()
    {
        var code = _service.CreateRoom();
        await _service.HandleJoinRoom("host-conn", code, "host");

        await Assert.ThrowsAsync<RoomFullException>(() =>
            _service.HandleJoinRoom("host2-conn", code, "host"));
    }

    // ── JoinRoom — Guest ─────────────────────────────────────────────────────

    [Fact]
    public async Task JoinRoom_GuestJoinsWaitingRoom_NoContent_TransitionsToJoined()
    {
        var code = _service.CreateRoom();
        await _service.HandleJoinRoom("host-conn", code, "host");

        var result = await _service.HandleJoinRoom("guest-conn", code, "guest");
        Assert.Equal("guest", result.Role);
        Assert.True(result.IsNewGuest);

        _registry.TryGet(code, out var room);
        Assert.Equal(RoomState.Joined, room!.State);
    }

    [Fact]
    public async Task JoinRoom_GuestJoinsWaitingRoom_WithContent_TransitionsToActive()
    {
        var code = _service.CreateRoom();
        await _service.HandleJoinRoom("host-conn", code, "host");

        _registry.TryGet(code, out var room);
        room!.ContentDescriptor = new IptvContentDescriptor("live", "12345", "ts", "Test Channel");

        var result = await _service.HandleJoinRoom("guest-conn", code, "guest");
        Assert.Equal(RoomState.Active, room.State);
    }

    [Fact]
    public async Task JoinRoom_GuestJoinsCreatedRoom_ThrowsNotFound()
    {
        var code = _service.CreateRoom();
        await Assert.ThrowsAsync<RoomNotFoundException>(() =>
            _service.HandleJoinRoom("guest-conn", code, "guest"));
    }

    [Fact]
    public async Task JoinRoom_GuestJoinsFullRoom_ThrowsRoomFull()
    {
        var code = _service.CreateRoom();
        await _service.HandleJoinRoom("host-conn", code, "host");
        await _service.HandleJoinRoom("guest1-conn", code, "guest");

        await Assert.ThrowsAsync<RoomFullException>(() =>
            _service.HandleJoinRoom("guest2-conn", code, "guest"));
    }

    [Fact]
    public async Task JoinRoom_InvalidRole_ThrowsInvalidRole()
    {
        var code = _service.CreateRoom();
        await Assert.ThrowsAsync<InvalidRoleException>(() =>
            _service.HandleJoinRoom("conn", code, "admin"));
    }

    [Fact]
    public async Task JoinRoom_NonexistentRoom_ThrowsNotFound()
    {
        await Assert.ThrowsAsync<RoomNotFoundException>(() =>
            _service.HandleJoinRoom("conn", "NOPE42", "host"));
    }

    [Fact]
    public async Task JoinRoom_AlreadyJoined_ThrowsAlreadyJoined()
    {
        var code = _service.CreateRoom();
        await _service.HandleJoinRoom("host-conn", code, "host");

        await Assert.ThrowsAsync<AlreadyJoinedException>(() =>
            _service.HandleJoinRoom("host-conn", "ANOTHER", "guest"));
    }

    [Fact]
    public async Task JoinRoom_ClosedRoom_ThrowsClosed()
    {
        var code = _service.CreateRoom();
        await _service.HandleJoinRoom("host-conn", code, "host");

        _registry.TryGet(code, out var room);
        room!.State = RoomState.Closed;

        await Assert.ThrowsAsync<RoomClosedException>(() =>
            _service.HandleJoinRoom("guest-conn", code, "guest"));
    }

    // ── SetContent ───────────────────────────────────────────────────────────

    [Fact]
    public async Task SetContent_ValidDescriptor_TransitionsJoinedToActive()
    {
        var code = _service.CreateRoom();
        await _service.HandleJoinRoom("host-conn", code, "host");
        await _service.HandleJoinRoom("guest-conn", code, "guest");

        _registry.TryGet(code, out var room);
        Assert.Equal(RoomState.Joined, room!.State);

        var descriptor = new IptvContentDescriptor("live", "12345", "ts", "Test Channel");
        var result = await _service.HandleSetContent("host-conn", descriptor);
        Assert.True(result.TransitionedToActive);
        Assert.Equal(RoomState.Active, room.State);
    }

    // ── Play/Pause/Seek ──────────────────────────────────────────────────────

    [Fact]
    public async Task Play_HostPlays_UpdatesPositionAndReturnsData()
    {
        var (code, room) = await SetupActiveRoom();

        var result = await _service.HandlePlay("host-conn", 42000, 1000000);
        Assert.Equal(42000, result.PositionMs);
        Assert.Equal(code, result.RoomCode);
        Assert.True(room.HostIsPlaying);
        Assert.Equal(42000, room.HostPositionMs);
    }

    [Fact]
    public async Task Pause_HostPauses_UpdatesState()
    {
        var (code, room) = await SetupActiveRoom();
        room.HostIsPlaying = true;

        var result = await _service.HandlePause("host-conn", 50000);
        Assert.Equal(50000, result.PositionMs);
        Assert.False(room.HostIsPlaying);
    }

    [Fact]
    public async Task Seek_HostSeeks_UpdatesPosition()
    {
        var (code, room) = await SetupActiveRoom();

        var result = await _service.HandleSeek("host-conn", 120000);
        Assert.Equal(120000, result.TargetPositionMs);
        Assert.Equal(120000, room.HostPositionMs);
    }

    // ── Role Authorization  ───────────────────────────────────────────

    [Fact]
    public async Task Play_GuestCalling_ThrowsRoleUnauthorized()
    {
        await SetupActiveRoom();
        await Assert.ThrowsAsync<RoleUnauthorizedException>(() =>
            _service.HandlePlay("guest-conn", 42000, 1000000));
    }

    [Fact]
    public async Task Pause_GuestCalling_ThrowsRoleUnauthorized()
    {
        await SetupActiveRoom();
        await Assert.ThrowsAsync<RoleUnauthorizedException>(() =>
            _service.HandlePause("guest-conn", 42000));
    }

    [Fact]
    public async Task Seek_GuestCalling_ThrowsRoleUnauthorized()
    {
        await SetupActiveRoom();
        await Assert.ThrowsAsync<RoleUnauthorizedException>(() =>
            _service.HandleSeek("guest-conn", 120000));
    }

    [Fact]
    public async Task SetContent_GuestCalling_ThrowsRoleUnauthorized()
    {
        await SetupActiveRoom();
        var descriptor = new IptvContentDescriptor("live", "99999", "ts", "New Channel");
        await Assert.ThrowsAsync<RoleUnauthorizedException>(() =>
            _service.HandleSetContent("guest-conn", descriptor));
    }

    [Fact]
    public async Task Play_ConnectionNotInRoom_ThrowsNotInRoom()
    {
        await Assert.ThrowsAsync<ConnectionNotInRoomException>(() =>
            _service.HandlePlay("random-conn", 42000, 1000000));
    }

    // ── Host Disconnect ──────────────────────────────────────────────────────

    [Fact]
    public async Task HostDisconnect_ClosesRoom()
    {
        var (code, room) = await SetupActiveRoom();
        var result = await _service.HandleDisconnected("host-conn");

        Assert.NotNull(result);
        Assert.Equal("host_disconnected", result!.Reason);
        Assert.Equal("guest-conn", result.PeerConnectionId);
        Assert.Equal(RoomState.Closed, room.State);
        Assert.False(_registry.TryGet(code, out _));
    }

    [Fact]
    public async Task HostDisconnect_IsIdempotent()
    {
        var (code, _) = await SetupActiveRoom();
        await _service.HandleDisconnected("host-conn");
        var result = await _service.HandleDisconnected("host-conn");
        Assert.Null(result);
    }

    // ── Guest Disconnect ─────────────────────────────────────────────────────

    [Fact]
    public async Task GuestDisconnect_StartsGracePeriod()
    {
        var (code, room) = await SetupActiveRoom();
        var result = await _service.HandleDisconnected("guest-conn");

        Assert.NotNull(result);
        Assert.Equal("guest", result!.Role);
        Assert.Equal(30, result.GracePeriodSeconds);
        Assert.True(room.GuestAway);
        Assert.Equal(RoomState.Active, room.State);
    }

    [Fact]
    public async Task GuestDisconnect_FromJoined_TransitionsToWaiting()
    {
        var code = _service.CreateRoom();
        await _service.HandleJoinRoom("host-conn", code, "host");
        await _service.HandleJoinRoom("guest-conn", code, "guest");

        _registry.TryGet(code, out var room);
        Assert.Equal(RoomState.Joined, room!.State);

        var result = await _service.HandleDisconnected("guest-conn");
        Assert.Equal(RoomState.Waiting, room.State);
    }

    // ── LeaveRoom ────────────────────────────────────────────────────────────

    [Fact]
    public async Task LeaveRoom_HostLeaves_ClosesRoom()
    {
        var (code, room) = await SetupActiveRoom();
        var result = await _service.HandleLeaveRoom("host-conn");

        Assert.Equal("host_left", result.Reason);
        Assert.Equal(RoomState.Closed, room.State);
    }

    [Fact]
    public async Task LeaveRoom_GuestLeaves_RemovesGuestImmediately()
    {
        var (code, room) = await SetupActiveRoom();
        var result = await _service.HandleLeaveRoom("guest-conn");

        Assert.Equal("guest_left", result.Reason);
        Assert.Null(room.Guest);
        Assert.False(room.GuestAway);
        Assert.Equal(RoomState.Waiting, room.State);
    }

    // ── Ping ─────────────────────────────────────────────────────────────────

    [Fact]
    public async Task Ping_ReturnsTimestamps()
    {
        await SetupActiveRoom();
        var result = await _service.HandlePing("host-conn", 1000000, 150);
        Assert.Equal(1000000, result.ClientTimestampMs);
        Assert.True(result.ServerTimestampMs > 0);
    }

    // ── Buffering Coordination ,  ───────────────────────────────

    [Fact]
    public async Task BufferingStall_GuestStalls_SetsGuestToStalled()
    {
        var (code, room) = await SetupActiveRoom();

        var result = await _service.HandleNotifyBufferingStall("guest-conn", 42000, 1);

        Assert.Equal("guest", result.CallerRole);
        Assert.Equal("host-conn", result.PeerConnectionId);
        Assert.Equal(42000, result.PositionMs);
        Assert.Equal(BufferingState.Stalled, room.Guest!.BufferingState);
        Assert.Equal(BufferingState.Ready, room.Host!.BufferingState);
    }

    [Fact]
    public async Task BufferingStall_HostStalls_SetsHostToStalled()
    {
        var (code, room) = await SetupActiveRoom();

        var result = await _service.HandleNotifyBufferingStall("host-conn", 50000, 1);

        Assert.Equal("host", result.CallerRole);
        Assert.Equal("guest-conn", result.PeerConnectionId);
        Assert.Equal(BufferingState.Stalled, room.Host!.BufferingState);
        Assert.Equal(BufferingState.Ready, room.Guest!.BufferingState);
    }

    [Fact]
    public async Task BufferingStall_DuplicateStall_IsIdempotent()
    {
        var (code, room) = await SetupActiveRoom();

        await _service.HandleNotifyBufferingStall("guest-conn", 42000, 1);
        var result = await _service.HandleNotifyBufferingStall("guest-conn", 43000, 1);

        // Duplicate stall returns no peer (ignored)
        Assert.Null(result.PeerConnectionId);
        Assert.Equal(BufferingState.Stalled, room.Guest!.BufferingState);
    }

    [Fact]
    public async Task BufferingReady_OutOfSequence_IsIgnored()
    {
        var (code, room) = await SetupActiveRoom();

        // Guest is already Ready (default) — sending ready is out-of-sequence
        var result = await _service.HandleNotifyBufferingReady("guest-conn", 1);

        Assert.False(result.GateOpened);
        Assert.Equal(BufferingState.Ready, room.Guest!.BufferingState);
    }

    /// <summary>
    /// Full buffering gate sequence: guest stalls, host stalls, guest ready (gate stays closed),
    /// then host ready opens the gate.
    /// </summary>
    [Fact]
    public async Task BufferingGate_BothStall_GateOpensOnlyWhenBothReady()
    {
        var (code, room) = await SetupActiveRoom();
        room.HostPositionMs = 60000; // Set host position for resume

        // 1. Guest stalls
        await _service.HandleNotifyBufferingStall("guest-conn", 58000, 1);
        Assert.Equal(BufferingState.Stalled, room.Guest!.BufferingState);
        Assert.Equal(BufferingState.Ready, room.Host!.BufferingState);

        // 2. Host stalls
        await _service.HandleNotifyBufferingStall("host-conn", 60000, 1);
        Assert.Equal(BufferingState.Stalled, room.Host!.BufferingState);
        Assert.Equal(BufferingState.Stalled, room.Guest!.BufferingState);

        // 3. Guest becomes ready — gate should NOT open (host still stalled)
        var guestReadyResult = await _service.HandleNotifyBufferingReady("guest-conn", 1);
        Assert.False(guestReadyResult.GateOpened);
        Assert.Equal(BufferingState.Ready, room.Guest!.BufferingState);
        Assert.Equal(BufferingState.Stalled, room.Host!.BufferingState);

        // 4. Host becomes ready — gate OPENS
        var hostReadyResult = await _service.HandleNotifyBufferingReady("host-conn", 1);
        Assert.True(hostReadyResult.GateOpened);
        Assert.Equal(60000, hostReadyResult.ResumePositionMs);
        Assert.Equal(BufferingState.Ready, room.Host!.BufferingState);
        Assert.Equal(BufferingState.Ready, room.Guest!.BufferingState);
    }

    /// <summary>
    /// Guest stalls while host was playing — buffering:stall is sent to host.
    /// Guest ready → gate does not open until host also ready.
    /// (In this scenario host never stalls — peer stays Ready on server.)
    /// </summary>
    [Fact]
    public async Task BufferingGate_GuestStalls_HostStaysReady_GateOpensOnGuestReady()
    {
        var (code, room) = await SetupActiveRoom();
        room.HostPositionMs = 42000;
        room.HostIsPlaying = true;

        // 1. Guest stalls
        var stallResult = await _service.HandleNotifyBufferingStall("guest-conn", 42000, 1);
        Assert.Equal("host-conn", stallResult.PeerConnectionId);
        Assert.Equal(BufferingState.Stalled, room.Guest!.BufferingState);
        Assert.Equal(BufferingState.Ready, room.Host!.BufferingState);

        // 2. Guest becomes ready — host was always Ready → gate opens
        var readyResult = await _service.HandleNotifyBufferingReady("guest-conn", 1);
        Assert.True(readyResult.GateOpened);
        Assert.Equal(42000, readyResult.ResumePositionMs);
    }

    [Fact]
    public async Task BufferingStall_ConnectionNotInRoom_Throws()
    {
        await Assert.ThrowsAsync<ConnectionNotInRoomException>(() =>
            _service.HandleNotifyBufferingStall("random-conn", 42000, 1));
    }

    [Fact]
    public async Task BufferingReady_ConnectionNotInRoom_Throws()
    {
        await Assert.ThrowsAsync<ConnectionNotInRoomException>(() =>
            _service.HandleNotifyBufferingReady("random-conn", 1));
    }

    // ── Guest Reconnection ,  ─────────────────────────────────

    /// <summary>
    /// Guest reconnects within 30s — grace timer cancelled,
    /// guest re-associated, state sync data returned, room stays Active.
    /// </summary>
    [Fact]
    public async Task GuestReconnect_WithinGracePeriod_RestoresState()
    {
        var (code, room) = await SetupActiveRoom();
        room.HostPositionMs = 142000;
        room.HostIsPlaying = true;

        // Guest disconnects
        var disconnectResult = await _service.HandleDisconnected("guest-conn");
        Assert.NotNull(disconnectResult);
        Assert.True(room.GuestAway);
        Assert.NotNull(room.GuestGraceCts);

        // Guest reconnects with a new connection ID
        var rejoinResult = await _service.HandleJoinRoom("guest-conn2", code, "guest");

        Assert.Equal("guest", rejoinResult.Role);
        Assert.False(rejoinResult.IsNewGuest);
        Assert.Equal(142000, rejoinResult.HostPositionMs);
        Assert.True(rejoinResult.HostIsPlaying);
        Assert.Equal(RoomState.Active, room.State);
        Assert.False(room.GuestAway);
        Assert.Null(room.GuestGraceCts);
        Assert.Equal("guest-conn2", room.Guest!.ConnectionId);
    }

    /// <summary>
    /// Reconnecting guest has BufferingState reset to Ready.
    /// </summary>
    [Fact]
    public async Task GuestReconnect_ResetsBufferingStateToReady()
    {
        var (code, room) = await SetupActiveRoom();

        // Guest stalls, then disconnects
        await _service.HandleNotifyBufferingStall("guest-conn", 42000, 1);
        Assert.Equal(BufferingState.Stalled, room.Guest!.BufferingState);

        await _service.HandleDisconnected("guest-conn");

        // Guest reconnects
        var rejoinResult = await _service.HandleJoinRoom("guest-conn2", code, "guest");

        Assert.Equal(BufferingState.Ready, room.Guest!.BufferingState);
    }

    /// <summary>
    /// Guest does not reconnect — grace timer fires, guest slot cleared,
    /// room remains open, host can still receive a new guest.
    /// </summary>
    [Fact]
    public async Task GuestGracePeriodExpiry_ClearsGuestSlot_RoomRemainsOpen()
    {
        // Use a short grace period for testing
        var registry = new InMemoryRoomRegistry();
        var logger = Mock.Of<ILogger<RoomService>>();
        var config = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["WatchParty:Room:GuestGracePeriodSeconds"] = "1"
            })
            .Build();
        var service = new RoomService(registry, logger, config);

        var code = service.CreateRoom();
        await service.HandleJoinRoom("host-conn", code, "host");
        await service.HandleJoinRoom("guest-conn", code, "guest");
        var descriptor = new IptvContentDescriptor("live", "12345", "ts", "Test Channel");
        await service.HandleSetContent("host-conn", descriptor);

        registry.TryGet(code, out var room);

        // Guest disconnects — 1s grace period
        await service.HandleDisconnected("guest-conn");
        Assert.True(room!.GuestAway);

        // Wait for grace period to expire
        await Task.Delay(3000);

        // Guest slot should be cleared
        Assert.Null(room.Guest);
        Assert.False(room.GuestAway);
        Assert.Null(room.GuestGraceCts);

        // Room remains open — host is still connected
        Assert.Equal(RoomState.Active, room.State);
        Assert.True(registry.TryGet(code, out _));

        // A new guest can join
        var newGuestResult = await service.HandleJoinRoom("new-guest-conn", code, "guest");
        Assert.True(newGuestResult.IsNewGuest);
        Assert.Equal("guest", newGuestResult.Role);
    }

    /// <summary>
    /// Guest reconnects from Joined state —
    /// transitions back to Joined (no stream URL) or Active (with stream URL).
    /// </summary>
    [Fact]
    public async Task GuestReconnect_FromWaitingState_RestoresJoinedState()
    {
        var code = _service.CreateRoom();
        await _service.HandleJoinRoom("host-conn", code, "host");
        await _service.HandleJoinRoom("guest-conn", code, "guest");

        _registry.TryGet(code, out var room);
        Assert.Equal(RoomState.Joined, room!.State);

        // Guest disconnects from Joined state → transitions to Waiting
        await _service.HandleDisconnected("guest-conn");
        Assert.Equal(RoomState.Waiting, room.State);
        Assert.True(room.GuestAway);

        // Guest reconnects → should go back to Joined (no stream URL)
        var rejoinResult = await _service.HandleJoinRoom("guest-conn2", code, "guest");
        Assert.Equal(RoomState.Joined, room.State);
        Assert.False(room.GuestAway);
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    [Fact]
    public async Task PlayerReady_ContentSwitch_RequiresFreshReadyForNewContent()
    {
        var (_, room) = await SetupActiveRoom();
        var firstContentKey = room.ContentDescriptor!.ContentKey;

        var hostReadyA = await _service.HandleNotifyPlayerReady("host-conn", firstContentKey);
        Assert.False(hostReadyA.GateOpened);

        var guestReadyA = await _service.HandleNotifyPlayerReady("guest-conn", firstContentKey);
        Assert.True(guestReadyA.GateOpened);

        var nextDescriptor = new IptvContentDescriptor("episode", "928875", "m3u8", "Episode 2");
        await _service.HandleSetContent("host-conn", nextDescriptor);

        Assert.False(room.Host!.IsPlayerReady);
        Assert.False(room.Guest!.IsPlayerReady);

        var hostReadyB = await _service.HandleNotifyPlayerReady("host-conn", nextDescriptor.ContentKey);
        Assert.False(hostReadyB.GateOpened);

        var guestReadyB = await _service.HandleNotifyPlayerReady("guest-conn", nextDescriptor.ContentKey);
        Assert.True(guestReadyB.GateOpened);
    }

    [Fact]
    public async Task PlayerReady_StaleContentKey_IsIgnoredAfterContentSwitch()
    {
        var (_, room) = await SetupActiveRoom();
        var staleContentKey = room.ContentDescriptor!.ContentKey;
        var nextDescriptor = new IptvContentDescriptor("episode", "928875", "m3u8", "Episode 2");

        await _service.HandleSetContent("host-conn", nextDescriptor);

        var staleReady = await _service.HandleNotifyPlayerReady("host-conn", staleContentKey);
        Assert.False(staleReady.ShouldBroadcast);
        Assert.False(staleReady.GateOpened);
        Assert.False(room.Host!.IsPlayerReady);
        Assert.Null(room.Host.PlayerReadyContentKey);

        var guestReady = await _service.HandleNotifyPlayerReady("guest-conn", nextDescriptor.ContentKey);
        Assert.False(guestReady.GateOpened);
    }

    private async Task<(string code, Room room)> SetupActiveRoom()
    {
        var code = _service.CreateRoom();
        await _service.HandleJoinRoom("host-conn", code, "host");
        await _service.HandleJoinRoom("guest-conn", code, "guest");
        var descriptor = new IptvContentDescriptor("live", "12345", "ts", "Test Channel");
        await _service.HandleSetContent("host-conn", descriptor);

        _registry.TryGet(code, out var room);
        return (code, room!);
    }
}
