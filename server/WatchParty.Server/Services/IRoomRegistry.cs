using WatchParty.Server.Models;

namespace WatchParty.Server.Services;

/// <summary>
/// In-memory room registry interface. Wraps thread-safe room storage.
/// </summary>
public interface IRoomRegistry
{
    /// <summary>Add a room. Returns false if code already exists.</summary>
    bool TryAdd(string roomCode, Room room);

    /// <summary>Get a room by code. Returns false if not found.</summary>
    bool TryGet(string roomCode, out Room? room);

    /// <summary>Remove a room by code. Returns false if not found.</summary>
    bool TryRemove(string roomCode, out Room? room);

    /// <summary>Get all rooms (for expiry sweep).</summary>
    IReadOnlyCollection<Room> GetAll();

    /// <summary>Find a room by connection ID. O(1) via reverse index.</summary>
    Room? FindByConnectionId(string connectionId);

    /// <summary>
    /// Register a connection ID → room code mapping in the reverse index.
    /// Called by RoomService when a participant joins a room.
    /// </summary>
    void RegisterConnection(string connectionId, string roomCode);

    /// <summary>
    /// Unregister a connection ID from the reverse index.
    /// Called by RoomService when a participant leaves or disconnects.
    /// </summary>
    void UnregisterConnection(string connectionId);
}
