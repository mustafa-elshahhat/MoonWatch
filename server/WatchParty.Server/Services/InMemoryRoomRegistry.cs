using System.Collections.Concurrent;
using WatchParty.Server.Models;

namespace WatchParty.Server.Services;

/// <summary>
/// In-memory room registry backed by ConcurrentDictionary.
/// Registered as singleton per ARCHITECTURE.md §3.3.
/// </summary>
public class InMemoryRoomRegistry : IRoomRegistry
{
    private readonly ConcurrentDictionary<string, Room> _rooms = new(StringComparer.OrdinalIgnoreCase);

    /// <summary>Reverse index: connectionId → roomCode for O(1) lookup.</summary>
    private readonly ConcurrentDictionary<string, string> _connectionIndex = new(StringComparer.OrdinalIgnoreCase);

    /// <inheritdoc />
    public bool TryAdd(string roomCode, Room room)
    {
        return _rooms.TryAdd(roomCode, room);
    }

    /// <inheritdoc />
    public bool TryGet(string roomCode, out Room? room)
    {
        var result = _rooms.TryGetValue(roomCode, out var found);
        room = found;
        return result;
    }

    /// <inheritdoc />
    public bool TryRemove(string roomCode, out Room? room)
    {
        var result = _rooms.TryRemove(roomCode, out var removed);
        room = removed;
        return result;
    }

    /// <inheritdoc />
    public IReadOnlyCollection<Room> GetAll()
    {
        return _rooms.Values.ToList().AsReadOnly();
    }

    /// <inheritdoc />
    public Room? FindByConnectionId(string connectionId)
    {
        if (!_connectionIndex.TryGetValue(connectionId, out var roomCode))
            return null;

        _rooms.TryGetValue(roomCode, out var room);
        return room;
    }

    /// <inheritdoc />
    public void RegisterConnection(string connectionId, string roomCode)
    {
        _connectionIndex[connectionId] = roomCode;
    }

    /// <inheritdoc />
    public void UnregisterConnection(string connectionId)
    {
        _connectionIndex.TryRemove(connectionId, out _);
    }
}
