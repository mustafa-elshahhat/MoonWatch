enum RoomErrorCode {
  roomNotFound,
  roomFull,
  roomClosed,
  roleInvalid,
  roleUnauthorized,
  alreadyJoined,
  streamUrlInvalid,
  internalError,
}

extension RoomErrorCodeX on RoomErrorCode {
  static RoomErrorCode fromString(String code) {
    return switch (code) {
      'room_not_found' => RoomErrorCode.roomNotFound,
      'room_full' => RoomErrorCode.roomFull,
      'room_closed' => RoomErrorCode.roomClosed,
      'role_invalid' => RoomErrorCode.roleInvalid,
      'role_unauthorized' => RoomErrorCode.roleUnauthorized,
      'already_joined' => RoomErrorCode.alreadyJoined,
      'stream_url_invalid' => RoomErrorCode.streamUrlInvalid,
      _ => RoomErrorCode.internalError,
    };
  }

  String toSnakeCase() {
    return switch (this) {
      RoomErrorCode.roomNotFound => 'room_not_found',
      RoomErrorCode.roomFull => 'room_full',
      RoomErrorCode.roomClosed => 'room_closed',
      RoomErrorCode.roleInvalid => 'role_invalid',
      RoomErrorCode.roleUnauthorized => 'role_unauthorized',
      RoomErrorCode.alreadyJoined => 'already_joined',
      RoomErrorCode.streamUrlInvalid => 'stream_url_invalid',
      RoomErrorCode.internalError => 'internal_error',
    };
  }
}
