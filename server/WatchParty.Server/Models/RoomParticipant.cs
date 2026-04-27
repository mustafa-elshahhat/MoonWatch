namespace WatchParty.Server.Models;




public class RoomParticipant
{
    
    public string ConnectionId { get; set; } = string.Empty;

    
    public ParticipantRole Role { get; set; }

    
    public BufferingState BufferingState { get; set; } = BufferingState.Ready;

    
    public bool IsPlayerReady { get; set; } = false;

    
    public string? PlayerReadyContentKey { get; set; }
}
