// Canonical Dart payload models for the WatchParty SignalR protocol.
// C# mirror: shared/protocol/payloads/Payloads.cs — keep both in sync.

// ── Content descriptor ───────────────────────────────────────────────────────

enum IptvDescriptorType { live, movie, episode }

/// Identifies IPTV content without embedding credentials.
/// Each client resolves the final playback URL locally using its own account.
class IptvContentDescriptor {
  final IptvDescriptorType contentType;
  final String streamId;
  final String? containerExtension;
  final String title;

  const IptvContentDescriptor({
    required this.contentType,
    required this.streamId,
    this.containerExtension,
    required this.title,
  });

  Map<String, dynamic> toJson() => {
        'contentType': contentType.name,
        'streamId': streamId,
        'containerExtension': containerExtension,
        'title': title,
      };

  factory IptvContentDescriptor.fromJson(Map<String, dynamic> json) =>
      IptvContentDescriptor(
        contentType: IptvDescriptorType.values
            .firstWhere((e) => e.name == json['contentType'] as String),
        streamId: json['streamId'] as String,
        containerExtension: json['containerExtension'] as String?,
        title: json['title'] as String,
      );

  String get contentKey =>
      '${contentType.name}|$streamId|${containerExtension ?? ''}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IptvContentDescriptor &&
          contentType == other.contentType &&
          streamId == other.streamId &&
          containerExtension == other.containerExtension &&
          title == other.title;

  @override
  int get hashCode =>
      Object.hash(contentType, streamId, containerExtension, title);
}

// ── Server → Client payloads ──────────────────────────────────────────────────

class RoomJoinedPayload {
  final String roomCode;
  final String role;
  final bool guestPresent;
  final IptvContentDescriptor? contentDescriptor;
  final int serverTimestampMs;

  const RoomJoinedPayload({
    required this.roomCode,
    required this.role,
    required this.guestPresent,
    this.contentDescriptor,
    required this.serverTimestampMs,
  });

  factory RoomJoinedPayload.fromJson(Map<String, dynamic> json) =>
      RoomJoinedPayload(
        roomCode: json['roomCode'] as String,
        role: json['role'] as String,
        guestPresent: json['guestPresent'] as bool,
        contentDescriptor: json['contentDescriptor'] == null
            ? null
            : IptvContentDescriptor.fromJson(
                json['contentDescriptor'] as Map<String, dynamic>),
        serverTimestampMs: json['serverTimestampMs'] as int,
      );
}

class RoomGuestJoinedPayload {
  final int serverTimestampMs;

  const RoomGuestJoinedPayload({required this.serverTimestampMs});

  factory RoomGuestJoinedPayload.fromJson(Map<String, dynamic> json) =>
      RoomGuestJoinedPayload(
          serverTimestampMs: json['serverTimestampMs'] as int);
}

class RoomGuestLeftPayload {
  final int serverTimestampMs;
  final int gracePeriodSeconds;

  const RoomGuestLeftPayload({
    required this.serverTimestampMs,
    required this.gracePeriodSeconds,
  });

  factory RoomGuestLeftPayload.fromJson(Map<String, dynamic> json) =>
      RoomGuestLeftPayload(
        serverTimestampMs: json['serverTimestampMs'] as int,
        gracePeriodSeconds: json['gracePeriodSeconds'] as int,
      );
}

class RoomGuestReconnectedPayload {
  final int serverTimestampMs;

  const RoomGuestReconnectedPayload({required this.serverTimestampMs});

  factory RoomGuestReconnectedPayload.fromJson(Map<String, dynamic> json) =>
      RoomGuestReconnectedPayload(
          serverTimestampMs: json['serverTimestampMs'] as int);
}

class RoomClosedPayload {
  final String reason;
  final int serverTimestampMs;

  const RoomClosedPayload(
      {required this.reason, required this.serverTimestampMs});

  factory RoomClosedPayload.fromJson(Map<String, dynamic> json) =>
      RoomClosedPayload(
        reason: json['reason'] as String,
        serverTimestampMs: json['serverTimestampMs'] as int,
      );
}

class RoomContentSetPayload {
  final IptvContentDescriptor descriptor;
  final int serverTimestampMs;

  const RoomContentSetPayload(
      {required this.descriptor, required this.serverTimestampMs});

  factory RoomContentSetPayload.fromJson(Map<String, dynamic> json) =>
      RoomContentSetPayload(
        descriptor: IptvContentDescriptor.fromJson(
            json['descriptor'] as Map<String, dynamic>),
        serverTimestampMs: json['serverTimestampMs'] as int,
      );
}

class ErrorPayload {
  final String code;
  final String message;
  final int serverTimestampMs;

  const ErrorPayload(
      {required this.code,
      required this.message,
      required this.serverTimestampMs});

  factory ErrorPayload.fromJson(Map<String, dynamic> json) => ErrorPayload(
        code: json['code'] as String,
        message: json['message'] as String,
        serverTimestampMs: json['serverTimestampMs'] as int,
      );
}

// ── Playback payloads ────────────────────────────────────────────────────────

class PlaybackPlayPayload {
  final int positionMs;
  final int serverTimestampMs;
  final int hostRttMs;

  /// Monotonically increasing room playback command counter.
  /// Used by SyncBloc to reject stale commands.
  final int seqNo;

  const PlaybackPlayPayload({
    required this.positionMs,
    required this.serverTimestampMs,
    required this.hostRttMs,
    this.seqNo = 0,
  });

  factory PlaybackPlayPayload.fromJson(Map<String, dynamic> json) =>
      PlaybackPlayPayload(
        positionMs: json['positionMs'] as int,
        serverTimestampMs: json['serverTimestampMs'] as int,
        hostRttMs: json['hostRttMs'] as int,
        seqNo: (json['seqNo'] as int?) ?? 0,
      );
}

class PlaybackPausePayload {
  final int positionMs;
  final int serverTimestampMs;

  /// Monotonically increasing room playback command counter.
  final int seqNo;

  const PlaybackPausePayload(
      {required this.positionMs,
      required this.serverTimestampMs,
      this.seqNo = 0});

  factory PlaybackPausePayload.fromJson(Map<String, dynamic> json) =>
      PlaybackPausePayload(
        positionMs: json['positionMs'] as int,
        serverTimestampMs: json['serverTimestampMs'] as int,
        seqNo: (json['seqNo'] as int?) ?? 0,
      );
}

class PlaybackSeekPayload {
  final int targetPositionMs;
  final int serverTimestampMs;

  /// Monotonically increasing room playback command counter.
  final int seqNo;

  /// Whether the host was playing at the time of seek.
  /// Guest uses this to decide whether to resume playback after seeking.
  final bool isPlaying;

  const PlaybackSeekPayload(
      {required this.targetPositionMs,
      required this.serverTimestampMs,
      this.seqNo = 0,
      this.isPlaying = true});

  factory PlaybackSeekPayload.fromJson(Map<String, dynamic> json) =>
      PlaybackSeekPayload(
        targetPositionMs: json['targetPositionMs'] as int,
        serverTimestampMs: json['serverTimestampMs'] as int,
        seqNo: (json['seqNo'] as int?) ?? 0,
        isPlaying: (json['isPlaying'] as bool?) ?? true,
      );
}

class PlaybackStateSyncPayload {
  final int hostPositionMs;
  final bool isPlaying;
  final int serverTimestampMs;

  /// Room playback command counter at time of emission.
  /// Clients compare this to their own last-applied seqNo to detect stale state_sync.
  final int seqNo;

  const PlaybackStateSyncPayload({
    required this.hostPositionMs,
    required this.isPlaying,
    required this.serverTimestampMs,
    this.seqNo = 0,
  });

  factory PlaybackStateSyncPayload.fromJson(Map<String, dynamic> json) =>
      PlaybackStateSyncPayload(
        hostPositionMs: json['hostPositionMs'] as int,
        isPlaying: json['isPlaying'] as bool,
        serverTimestampMs: json['serverTimestampMs'] as int,
        seqNo: (json['seqNo'] as int?) ?? 0,
      );
}

class PongPayload {
  final int clientTimestampMs;
  final int serverTimestampMs;

  const PongPayload(
      {required this.clientTimestampMs, required this.serverTimestampMs});

  factory PongPayload.fromJson(Map<String, dynamic> json) => PongPayload(
        clientTimestampMs: json['clientTimestampMs'] as int,
        serverTimestampMs: json['serverTimestampMs'] as int,
      );
}

// ── Buffering payloads ───────────────────────────────────────────────────────

class BufferingStallBroadcastPayload {
  final int episodeId;
  final String role;
  final int positionMs;
  final int serverTimestampMs;

  const BufferingStallBroadcastPayload({
    required this.episodeId,
    required this.role,
    required this.positionMs,
    required this.serverTimestampMs,
  });

  factory BufferingStallBroadcastPayload.fromJson(Map<String, dynamic> json) =>
      BufferingStallBroadcastPayload(
        episodeId: (json['episodeId'] as int?) ?? 0,
        role: json['role'] as String,
        positionMs: json['positionMs'] as int,
        serverTimestampMs: json['serverTimestampMs'] as int,
      );
}

class PlayerReadyPayload {
  final bool bothReady;
  final String readyRole;
  final int serverTimestampMs;
  final String contentKey;

  const PlayerReadyPayload({
    required this.bothReady,
    required this.readyRole,
    required this.serverTimestampMs,
    required this.contentKey,
  });

  factory PlayerReadyPayload.fromJson(Map<String, dynamic> json) =>
      PlayerReadyPayload(
        bothReady: json['bothReady'] as bool,
        readyRole: json['readyRole'] as String,
        serverTimestampMs: json['serverTimestampMs'] as int,
        contentKey: json['contentKey'] as String,
      );
}

class BufferingResumePayload {
  final int serverTimestampMs;
  final int resumePositionMs;

  const BufferingResumePayload({
    required this.serverTimestampMs,
    required this.resumePositionMs,
  });

  factory BufferingResumePayload.fromJson(Map<String, dynamic> json) =>
      BufferingResumePayload(
        serverTimestampMs: json['serverTimestampMs'] as int,
        resumePositionMs: json['resumePositionMs'] as int,
      );
}
