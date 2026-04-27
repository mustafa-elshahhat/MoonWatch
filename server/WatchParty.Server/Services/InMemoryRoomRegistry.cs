using System.Collections.Concurrent;
using WatchParty.Server.Models;

namespace WatchParty.Server.Services;





public class InMemoryRoomRegistry : IRoomRegistry
{
    private readonly ConcurrentDictionary<string, Room> _rooms = new(StringComparer.OrdinalIgnoreCase);

    
    private readonly ConcurrentDictionary<string, string> _connectionIndex = new(StringComparer.OrdinalIgnoreCase);

    
    public bool TryAdd(string roomCode, Room room)
    {
        return _rooms.TryAdd(roomCode, room);
    }

    
    public bool TryGet(string roomCode, out Room? room)
    {
        var result = _rooms.TryGetValue(roomCode, out var found);
        room = found;
        return result;
    }

    
    public bool TryRemove(string roomCode, out Room? room)
    {
        var result = _rooms.TryRemove(roomCode, out var removed);
        room = removed;
        return result;
    }

    
    public IReadOnlyCollection<Room> GetAll()
    {
        return _rooms.Values.ToList().AsReadOnly();
    }

    
    public Room? FindByConnectionId(string connectionId)
    {
        if (!_connectionIndex.TryGetValue(connectionId, out var roomCode))
            return null;

        _rooms.TryGetValue(roomCode, out var room);
        return room;
    }

    
    public void RegisterConnection(string connectionId, string roomCode)
    {
        _connectionIndex[connectionId] = roomCode;
    }

    
    public void UnregisterConnection(string connectionId)
    {
        _connectionIndex.TryRemove(connectionId, out _);
    }
}
