using WatchParty.Server.Models;

namespace WatchParty.Server.Services;




public interface IRoomRegistry
{
    
    bool TryAdd(string roomCode, Room room);

    
    bool TryGet(string roomCode, out Room? room);

    
    bool TryRemove(string roomCode, out Room? room);

    
    IReadOnlyCollection<Room> GetAll();

    
    Room? FindByConnectionId(string connectionId);

    
    
    
    
    void RegisterConnection(string connectionId, string roomCode);

    
    
    
    
    void UnregisterConnection(string connectionId);
}
