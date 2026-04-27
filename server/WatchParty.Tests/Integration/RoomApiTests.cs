using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc.Testing;

namespace WatchParty.Tests.Integration;

/// <summary>
/// Integration tests for REST endpoints per SV-35, SV-36.
/// Uses WebApplicationFactory to spin up in-memory test server.
/// Note: POST /rooms/{code}/join is a pre-check endpoint; actual join is via SignalR.
/// </summary>
public class RoomApiTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;

    public RoomApiTests(WebApplicationFactory<Program> factory)
    {
        _client = factory.CreateClient();
    }

    // ── SV-35: POST /api/v1/rooms ────────────────────────────────────────────

    [Fact]
    public async Task CreateRoom_Returns201_WithRoomCode()
    {
        var response = await _client.PostAsync("/api/v1/rooms", null);

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);

        var body = await response.Content.ReadFromJsonAsync<JsonElement>();
        var code = body.GetProperty("roomCode").GetString();
        Assert.NotNull(code);
        Assert.Equal(6, code!.Length);
        Assert.True(body.TryGetProperty("createdAt", out _));
    }

    [Fact]
    public async Task CreateRoom_ReturnsDifferentCodes()
    {
        var r1 = await _client.PostAsync("/api/v1/rooms", null);
        var r2 = await _client.PostAsync("/api/v1/rooms", null);

        var b1 = await r1.Content.ReadFromJsonAsync<JsonElement>();
        var b2 = await r2.Content.ReadFromJsonAsync<JsonElement>();

        Assert.NotEqual(
            b1.GetProperty("roomCode").GetString(),
            b2.GetProperty("roomCode").GetString());
    }

    // ── SV-36: POST /api/v1/rooms/{code}/join ────────────────────────────────

    [Fact]
    public async Task JoinPreCheck_NonexistentCode_Returns404()
    {
        var response = await _client.PostAsync("/api/v1/rooms/ZZZZZZ/join", null);

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        var body = await response.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal("room_not_found", body.GetProperty("error").GetString());
    }

    [Fact]
    public async Task JoinPreCheck_ValidRoom_Returns200WithStatus()
    {
        var createRes = await _client.PostAsync("/api/v1/rooms", null);
        var createBody = await createRes.Content.ReadFromJsonAsync<JsonElement>();
        var code = createBody.GetProperty("roomCode").GetString()!;

        var joinRes = await _client.PostAsync($"/api/v1/rooms/{code}/join", null);

        Assert.Equal(HttpStatusCode.OK, joinRes.StatusCode);
        var joinBody = await joinRes.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(code, joinBody.GetProperty("roomCode").GetString());
        Assert.Equal("waiting_for_host_content", joinBody.GetProperty("status").GetString());
    }

    // ── GET /api/v1/rooms/{code}/status ──────────────────────────────────────

    [Fact]
    public async Task GetStatus_ExistingRoom_Returns200()
    {
        var createRes = await _client.PostAsync("/api/v1/rooms", null);
        var createBody = await createRes.Content.ReadFromJsonAsync<JsonElement>();
        var code = createBody.GetProperty("roomCode").GetString()!;

        var statusRes = await _client.GetAsync($"/api/v1/rooms/{code}/status");

        Assert.Equal(HttpStatusCode.OK, statusRes.StatusCode);
        var statusBody = await statusRes.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal("created", statusBody.GetProperty("state").GetString());
        Assert.False(statusBody.GetProperty("hostConnected").GetBoolean());
        Assert.False(statusBody.GetProperty("guestConnected").GetBoolean());
    }

    [Fact]
    public async Task GetStatus_NonexistentRoom_Returns404()
    {
        var statusRes = await _client.GetAsync("/api/v1/rooms/ZZZZZZ/status");
        Assert.Equal(HttpStatusCode.NotFound, statusRes.StatusCode);
    }
}
