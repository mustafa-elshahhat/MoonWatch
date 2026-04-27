namespace WatchParty.Server.Exceptions;

/// <summary>Room not found in registry.</summary>
public class RoomNotFoundException : Exception
{
    public string RoomId { get; }
    public string? ConnectionId { get; }

    public RoomNotFoundException(string roomId, string? connectionId = null)
        : base($"Room '{roomId}' not found.")
    {
        RoomId = roomId;
        ConnectionId = connectionId;
    }
}

/// <summary>Room already has 2 participants.</summary>
public class RoomFullException : Exception
{
    public string RoomId { get; }

    public RoomFullException(string roomId)
        : base($"Room '{roomId}' is full.")
    {
        RoomId = roomId;
    }
}

/// <summary>Room is in Closed state.</summary>
public class RoomClosedException : Exception
{
    public string RoomId { get; }

    public RoomClosedException(string roomId)
        : base($"Room '{roomId}' is closed.")
    {
        RoomId = roomId;
    }
}

/// <summary>Action not permitted for this role (e.g., guest calling Play).</summary>
public class RoleUnauthorizedException : Exception
{
    public string RoomId { get; }
    public string Role { get; }
    public string? ConnectionId { get; }

    public RoleUnauthorizedException(string roomId, string role, string? connectionId = null)
        : base($"Role '{role}' is not authorized in room '{roomId}'.")
    {
        RoomId = roomId;
        Role = role;
        ConnectionId = connectionId;
    }
}

/// <summary>Stream URL failed format validation.</summary>
public class InvalidStreamUrlException : Exception
{
    public string RoomId { get; }

    public InvalidStreamUrlException(string roomId, string url)
        : base($"Invalid stream URL format in room '{roomId}'.")
    {
        RoomId = roomId;
    }
}

/// <summary>Hub method called before JoinRoom.</summary>
public class ConnectionNotInRoomException : Exception
{
    public string ConnectionId { get; }

    public ConnectionNotInRoomException(string connectionId)
        : base($"Connection '{connectionId}' is not in any room.")
    {
        ConnectionId = connectionId;
    }
}

/// <summary>Connection already joined a room.</summary>
public class AlreadyJoinedException : Exception
{
    public string ConnectionId { get; }
    public string RoomId { get; }

    public AlreadyJoinedException(string connectionId, string roomId)
        : base($"Connection '{connectionId}' is already in room '{roomId}'.")
    {
        ConnectionId = connectionId;
        RoomId = roomId;
    }
}

/// <summary>Invalid role value.</summary>
public class InvalidRoleException : Exception
{
    public string RoomId { get; }
    public string Role { get; }

    public InvalidRoleException(string roomId, string role)
        : base($"Invalid role '{role}' for room '{roomId}'.")
    {
        RoomId = roomId;
        Role = role;
    }
}
