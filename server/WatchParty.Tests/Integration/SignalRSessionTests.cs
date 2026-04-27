using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.SignalR.Client;

namespace WatchParty.Tests.Integration;





public class SignalRSessionTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly WebApplicationFactory<Program> _factory;

    public SignalRSessionTests(WebApplicationFactory<Program> factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task FullSession_HostAndGuestJoinPlayPause()
    {
        
        var httpClient = _factory.CreateClient();
        var createRes = await httpClient.PostAsync("/api/v1/rooms", null);
        createRes.EnsureSuccessStatusCode();
        var createBody = await createRes.Content.ReadFromJsonAsync<JsonElement>();
        var roomCode = createBody.GetProperty("roomCode").GetString()!;

        
        var hostConnection = CreateHubConnection();
        var guestConnection = CreateHubConnection();

        try
        {
            
            var guestJoinedOnHost = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
            var streamSetOnGuest = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
            var playOnGuest = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
            var pauseOnGuest = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);

            hostConnection.On<JsonElement>("room:guest_joined", _ => guestJoinedOnHost.TrySetResult());
            guestConnection.On<JsonElement>("room:content_set", _ => streamSetOnGuest.TrySetResult());
            guestConnection.On<JsonElement>("playback:play", _ => playOnGuest.TrySetResult());
            guestConnection.On<JsonElement>("playback:pause", _ => pauseOnGuest.TrySetResult());

            
            await hostConnection.StartAsync();
            await guestConnection.StartAsync();

            
            await hostConnection.InvokeAsync("JoinRoom", roomCode, "host");

            
            await guestConnection.InvokeAsync("JoinRoom", roomCode, "guest");
            await WaitFor(guestJoinedOnHost, "room:guest_joined on host");

            
            await hostConnection.InvokeAsync("SetContent", new { ContentType = "live", StreamId = "12345", ContainerExtension = (string?)null, Title = "Test Channel" });
            await WaitFor(streamSetOnGuest, "room:content_set on guest");

            
            await hostConnection.InvokeAsync("Play", 0L, DateTimeOffset.UtcNow.ToUnixTimeMilliseconds());
            await WaitFor(playOnGuest, "playback:play on guest");

            
            await hostConnection.InvokeAsync("Pause", 5000L);
            await WaitFor(pauseOnGuest, "playback:pause on guest");

            
            var statusRes = await httpClient.GetAsync($"/api/v1/rooms/{roomCode}/status");
            var statusBody = await statusRes.Content.ReadFromJsonAsync<JsonElement>();
            Assert.Equal("active", statusBody.GetProperty("state").GetString());
        }
        finally
        {
            await hostConnection.DisposeAsync();
            await guestConnection.DisposeAsync();
        }
    }

    private HubConnection CreateHubConnection()
    {
        return new HubConnectionBuilder()
            .WithUrl(
                "http://localhost/hubs/room",
                o => o.HttpMessageHandlerFactory = _ => _factory.Server.CreateHandler())
            .Build();
    }

    private static async Task WaitFor(TaskCompletionSource tcs, string description)
    {
        var completed = await Task.WhenAny(tcs.Task, Task.Delay(5000));
        if (completed != tcs.Task)
            throw new TimeoutException($"Timed out waiting for: {description}");
    }
}
