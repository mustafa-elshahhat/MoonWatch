using System.Diagnostics;
using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.SignalR.Client;
using Microsoft.Extensions.DependencyInjection;

namespace WatchParty.Tests.Performance;




public class LoadTestFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseSetting("WatchParty:RoomCreationRateLimit:MaxRequests", "1000");
        builder.UseSetting("WatchParty:RoomCreationRateLimit:WindowSeconds", "60");
    }
}








public class LoadTests : IClassFixture<LoadTestFactory>
{
    private readonly LoadTestFactory _factory;
    private readonly HttpClient _client;

    public LoadTests(LoadTestFactory factory)
    {
        _factory = factory;
        _client = factory.CreateClient();
    }

    
    
    
    
    [Fact]
    public async Task PF01_Create100Rooms_MemoryPerRoomWithinBudget()
    {
        
        GC.Collect();
        GC.WaitForPendingFinalizers();
        GC.Collect();
        var baselineBytes = GC.GetTotalMemory(forceFullCollection: true);

        const int roomCount = 100;
        var roomCodes = new List<string>(roomCount);

        for (int i = 0; i < roomCount; i++)
        {
            var response = await _client.PostAsync("/api/v1/rooms", null);
            Assert.Equal(HttpStatusCode.Created, response.StatusCode);

            var json = await response.Content.ReadFromJsonAsync<RoomCreatedResponse>();
            Assert.NotNull(json);
            roomCodes.Add(json!.RoomCode);
        }

        Assert.Equal(roomCount, roomCodes.Count);

        
        GC.Collect();
        GC.WaitForPendingFinalizers();
        GC.Collect();
        var afterBytes = GC.GetTotalMemory(forceFullCollection: true);

        var totalBytesUsed = afterBytes - baselineBytes;
        var bytesPerRoom = totalBytesUsed / roomCount;

        
        
        
        
        
        Assert.True(bytesPerRoom < 25_600,
            $"Memory per room: {bytesPerRoom} bytes ({bytesPerRoom / 1024.0:F1} KB). " +
            $"Target: ≤ 5 KB/room (25 KB test margin for in-process overhead). Total: {totalBytesUsed / 1024.0:F1} KB for {roomCount} rooms.");

        
        var healthResponse = await _client.GetAsync("/health");
        var health = await healthResponse.Content.ReadFromJsonAsync<HealthResponse>();
        Assert.NotNull(health);
        Assert.True(health!.ActiveRooms >= roomCount,
            $"Expected at least {roomCount} active rooms, got {health.ActiveRooms}");
    }

    
    
    
    
    
    [Fact]
    public async Task PF02_100ActiveRooms_NoErrors()
    {
        const int roomCount = 100;

        for (int i = 0; i < roomCount; i++)
        {
            var response = await _client.PostAsync("/api/v1/rooms", null);
            Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        }

        
        var sw = Stopwatch.StartNew();
        var healthResponse = await _client.GetAsync("/health");
        sw.Stop();

        Assert.Equal(HttpStatusCode.OK, healthResponse.StatusCode);

        
        Assert.True(sw.ElapsedMilliseconds < 1000,
            $"Health endpoint took {sw.ElapsedMilliseconds}ms with {roomCount} rooms");
    }

    
    
    
    
    
    
    [Fact]
    public async Task PF03_PlayCommandRoundTrip_WithinLatencyTarget()
    {
        
        var createResponse = await _client.PostAsync("/api/v1/rooms", null);
        var roomJson = await createResponse.Content.ReadFromJsonAsync<RoomCreatedResponse>();
        Assert.NotNull(roomJson);
        var roomCode = roomJson!.RoomCode;

        
        var hostConnection = new HubConnectionBuilder()
            .WithUrl("http://localhost/hubs/room",
                o => o.HttpMessageHandlerFactory = _ => _factory.Server.CreateHandler())
            .Build();

        var guestConnection = new HubConnectionBuilder()
            .WithUrl("http://localhost/hubs/room",
                o => o.HttpMessageHandlerFactory = _ => _factory.Server.CreateHandler())
            .Build();

        try
        {
            var guestJoinedOnHost = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
            var streamSetOnGuest = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
            var playReceivedTimestamp = new TaskCompletionSource<long>(TaskCreationOptions.RunContinuationsAsynchronously);

            hostConnection.On<JsonElement>("room:guest_joined", _ => guestJoinedOnHost.TrySetResult());
            guestConnection.On<JsonElement>("room:content_set", _ => streamSetOnGuest.TrySetResult());
            guestConnection.On<JsonElement>("playback:play", _ =>
            {
                playReceivedTimestamp.TrySetResult(Stopwatch.GetTimestamp());
            });

            await hostConnection.StartAsync();
            await guestConnection.StartAsync();

            
            await hostConnection.InvokeAsync("JoinRoom", roomCode, "host");
            await guestConnection.InvokeAsync("JoinRoom", roomCode, "guest");
            await WaitFor(guestJoinedOnHost, "room:guest_joined on host");

            
            await hostConnection.InvokeAsync("SetContent", new { ContentType = "live", StreamId = "12345", ContainerExtension = (string?)null, Title = "Test Channel" });
            await WaitFor(streamSetOnGuest, "room:content_set on guest");

            
            var sendTimestamp = Stopwatch.GetTimestamp();
            await hostConnection.InvokeAsync("Play", 0L, DateTimeOffset.UtcNow.ToUnixTimeMilliseconds());
            await WaitFor(playReceivedTimestamp, "playback:play on guest");

            var receiveTimestamp = await playReceivedTimestamp.Task;
            var elapsedMs = (double)(receiveTimestamp - sendTimestamp) / Stopwatch.Frequency * 1000;

            
            Assert.True(elapsedMs < 200,
                $"Play command round-trip: {elapsedMs:F1}ms. Target: ≤ 200ms.");
        }
        finally
        {
            await hostConnection.DisposeAsync();
            await guestConnection.DisposeAsync();
        }
    }

    private static async Task WaitFor(TaskCompletionSource tcs, string description)
    {
        var completed = await Task.WhenAny(tcs.Task, Task.Delay(5000));
        if (completed != tcs.Task)
            throw new TimeoutException($"Timed out waiting for: {description}");
    }

    private static async Task WaitFor<T>(TaskCompletionSource<T> tcs, string description)
    {
        var completed = await Task.WhenAny(tcs.Task, Task.Delay(5000));
        if (completed != tcs.Task)
            throw new TimeoutException($"Timed out waiting for: {description}");
    }

    private record RoomCreatedResponse(string RoomCode, string CreatedAt);
    private record HealthResponse(string Status, int ActiveRooms);
}
