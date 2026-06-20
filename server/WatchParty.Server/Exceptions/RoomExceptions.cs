namespace WatchParty.Server.Exceptions;


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


public class RoomFullException : Exception
{
    public string RoomId { get; }

    public RoomFullException(string roomId)
        : base($"Room '{roomId}' is full.")
    {
        RoomId = roomId;
    }
}


public class RoomClosedException : Exception
{
    public string RoomId { get; }

    public RoomClosedException(string roomId)
        : base($"Room '{roomId}' is closed.")
    {
        RoomId = roomId;
    }
}


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


public class InvalidStreamUrlException : Exception
{
    public string RoomId { get; }

    public InvalidStreamUrlException(string roomId, string url)
        : base($"Invalid stream URL format in room '{roomId}'.")
    {
        RoomId = roomId;
    }
}


public class InvalidContentTypeException : Exception
{
    public string RoomId { get; }
    public string ContentType { get; }

    public InvalidContentTypeException(string roomId, string contentType)
        : base($"Invalid content type '{contentType}' for room '{roomId}'. Allowed: live, movie, episode.")
    {
        RoomId = roomId;
        ContentType = contentType;
    }
}


public class ConnectionNotInRoomException : Exception
{
    public string ConnectionId { get; }

    public ConnectionNotInRoomException(string connectionId)
        : base($"Connection '{connectionId}' is not in any room.")
    {
        ConnectionId = connectionId;
    }
}


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
