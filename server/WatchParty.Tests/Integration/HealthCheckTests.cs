using System.Net;
using System.Net.Http.Json;
using Microsoft.AspNetCore.Mvc.Testing;

namespace WatchParty.Tests.Integration;

public class HealthCheckTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;

    public HealthCheckTests(WebApplicationFactory<Program> factory)
    {
        _client = factory.CreateClient();
    }

    [Fact]
    public async Task GetHealth_Returns200WithJson()
    {
        var response = await _client.GetAsync("/health");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var json = await response.Content.ReadFromJsonAsync<HealthResponse>();
        Assert.NotNull(json);
        Assert.Equal("healthy", json!.Status);
        Assert.True(json.ActiveRooms >= 0);
    }

    [Fact]
    public async Task GetHealth_ReturnsActiveRoomCount()
    {
        // Create a room via API, then check health
        await _client.PostAsync("/api/v1/rooms", null);

        var response = await _client.GetAsync("/health");
        var json = await response.Content.ReadFromJsonAsync<HealthResponse>();

        Assert.NotNull(json);
        Assert.True(json!.ActiveRooms >= 1);
    }

    private record HealthResponse(string Status, int ActiveRooms);
}
