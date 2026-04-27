namespace WatchParty.Server.Models;

/// <summary>
/// Buffering state of a participant. Ready means player can play; Stalled means player is buffering.
/// </summary>
public enum BufferingState
{
    Ready,
    Stalled,
}
