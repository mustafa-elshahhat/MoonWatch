using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using WatchParty.Server.Services;

namespace WatchParty.Server.Controllers;

/// <summary>
/// REST controller for room operations per API_CONTRACTS.md.
/// </summary>
[ApiController]
[Route("api/v1/rooms")]
public class RoomsController : ControllerBase
{
    private readonly IRoomService _roomService;
    private readonly IRoomRegistry _roomRegistry;
    private readonly ILogger<RoomsController> _logger;

    public RoomsController(IRoomService roomService, IRoomRegistry roomRegistry, ILogger<RoomsController> logger)
    {
        _roomService = roomService;
        _roomRegistry = roomRegistry;
        _logger = logger;
    }

    /// <summary>POST /rooms — Create a new room.</summary>
    [HttpPost]
    [EnableRateLimiting("room-creation")]
    public IActionResult CreateRoom()
    {
        try
        {
            var roomCode = _roomService.CreateRoom();

            _logger.LogInformation("Room created via REST {Event} {RoomId}", "room.created", roomCode);

            return StatusCode(201, new
            {
                roomCode,
                createdAt = DateTimeOffset.UtcNow.ToString("o"),
            });
        }
        catch (InvalidOperationException ex) when (ex.Message.Contains("unique room code"))
        {
            _logger.LogError(ex, "Failed to generate room code — too many collisions");
            return StatusCode(503, new
            {
                error = "service_unavailable",
                message = "Unable to create room. Please try again.",
            });
        }
    }

    /// <summary>POST /rooms/{code}/join — Pre-check that room exists and has space.</summary>
    [HttpPost("{code}/join")]
    [EnableRateLimiting("room-join")]
    public IActionResult JoinRoom(string code)
    {
        code = code.ToUpperInvariant();

        if (!_roomRegistry.TryGet(code, out var room) || room == null)
        {
            return NotFound(new
            {
                error = "room_not_found",
                message = $"No active room with code {code}.",
            });
        }

        if (room.State == Models.RoomState.Closed)
        {
            return StatusCode(410, new
            {
                error = "room_closed",
                message = $"Room {code} has been closed.",
            });
        }

        if (room.Guest != null && !room.GuestAway)
        {
            return StatusCode(409, new
            {
                error = "room_full",
                message = $"Room {code} already has a guest.",
            });
        }

        var status = room.ContentDescriptor != null ? "ready" : "waiting_for_host_content";
        return Ok(new
        {
            roomCode = code,
            status,
        });
    }

    /// <summary>GET /rooms/{code}/status — Room status for diagnostics.</summary>
    [HttpGet("{code}/status")]
    [EnableRateLimiting("room-status")]
    public IActionResult GetStatus(string code)
    {
        code = code.ToUpperInvariant();

        if (!_roomRegistry.TryGet(code, out var room) || room == null)
        {
            return NotFound(new
            {
                error = "room_not_found",
                message = $"No active room with code {code}.",
            });
        }

        return Ok(new
        {
            roomCode = code,
            state = room.State.ToString().ToLowerInvariant(),
            hostConnected = room.Host != null,
            guestConnected = room.Guest != null && !room.GuestAway,
            guestBuffering = room.Guest?.BufferingState == Models.BufferingState.Stalled,
            contentSet = room.ContentDescriptor != null,
            createdAt = room.CreatedAt.ToString("o"),
        });
    }

    /// <summary>GET /rooms — List active, joinable rooms.</summary>
    [HttpGet]
    public IActionResult ListRooms()
    {
        var rooms = _roomRegistry.GetAll()
            .Where(r => r.State != Models.RoomState.Closed
                        && r.State != Models.RoomState.Created)
            .OrderByDescending(r => r.CreatedAt)
            .Select(r => new
            {
                roomCode = r.RoomCode,
                state = r.State.ToString().ToLowerInvariant(),
                hostConnected = r.Host != null,
                hasGuest = r.Guest != null && !r.GuestAway,
                isJoinable = r.Guest == null || r.GuestAway,
                createdAt = r.CreatedAt.ToString("o"),
                contentSet = r.ContentDescriptor != null,
                contentType = r.ContentDescriptor?.ContentType.ToLowerInvariant(),
                hostRtt = r.HostRttMs,
            })
            .ToList();

        return Ok(new { rooms });
    }
}
