class RoomEvents {
  RoomEvents._();

  static const String roomJoined = 'room:joined';
  static const String roomGuestJoined = 'room:guest_joined';
  static const String roomGuestLeft = 'room:guest_left';
  static const String roomGuestReconnected = 'room:guest_reconnected';
  static const String roomClosed = 'room:closed';
  static const String roomContentSet = 'room:content_set';
  static const String roomError = 'room:error';
  static const String playerReady = 'player:ready';

  static const String playbackPlay = 'playback:play';
  static const String playbackPause = 'playback:pause';
  static const String playbackSeek = 'playback:seek';
  static const String playbackStateSync = 'playback:state_sync';
  static const String playbackSpeed = 'playback:speed';

  static const String bufferingStall = 'buffering:stall';
  static const String bufferingReady = 'buffering:ready';
  static const String bufferingResume = 'buffering:resume';

  static const String pong = 'pong';

  static const String hubCreateRoom = 'CreateRoom';
  static const String hubJoinRoom = 'JoinRoom';
  static const String hubLeaveRoom = 'LeaveRoom';
  static const String hubSetContent = 'SetContent';
  static const String hubPlay = 'Play';
  static const String hubPause = 'Pause';
  static const String hubSeek = 'Seek';
  static const String hubSetPlaybackSpeed = 'SetPlaybackSpeed';
  static const String hubNotifyBufferingStall = 'NotifyBufferingStall';
  static const String hubNotifyPlayerReady = 'NotifyPlayerReady';
  static const String hubNotifyBufferingReady = 'NotifyBufferingReady';
  static const String hubPing = 'Ping';
}
