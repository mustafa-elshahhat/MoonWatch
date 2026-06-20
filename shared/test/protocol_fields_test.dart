import 'package:test/test.dart';
import 'package:watch_party_protocol/protocol/payloads.dart';
import 'package:watch_party_protocol/protocol/room_events.dart';

void main() {
  group('RoomEvents constants', () {
    test('hub method names are non-empty', () {
      expect(RoomEvents.hubCreateRoom, isNotEmpty);
      expect(RoomEvents.hubJoinRoom, isNotEmpty);
      expect(RoomEvents.hubLeaveRoom, isNotEmpty);
      expect(RoomEvents.hubSetContent, isNotEmpty);
      expect(RoomEvents.hubPlay, isNotEmpty);
      expect(RoomEvents.hubPause, isNotEmpty);
      expect(RoomEvents.hubSeek, isNotEmpty);
      expect(RoomEvents.hubNotifyBufferingStall, isNotEmpty);
      expect(RoomEvents.hubNotifyPlayerReady, isNotEmpty);
      expect(RoomEvents.hubNotifyBufferingReady, isNotEmpty);
      expect(RoomEvents.hubPing, isNotEmpty);
    });

    test('server event names match expected protocol strings', () {
      expect(RoomEvents.roomJoined, 'room:joined');
      expect(RoomEvents.roomGuestJoined, 'room:guest_joined');
      expect(RoomEvents.roomGuestLeft, 'room:guest_left');
      expect(RoomEvents.roomGuestReconnected, 'room:guest_reconnected');
      expect(RoomEvents.roomHostAway, 'room:host_away');
      expect(RoomEvents.roomHostReconnected, 'room:host_reconnected');
      expect(RoomEvents.roomClosed, 'room:closed');
      expect(RoomEvents.roomContentSet, 'room:content_set');
      expect(RoomEvents.roomError, 'room:error');
      expect(RoomEvents.playerReady, 'player:ready');
      expect(RoomEvents.playbackPlay, 'playback:play');
      expect(RoomEvents.playbackPause, 'playback:pause');
      expect(RoomEvents.playbackSeek, 'playback:seek');
      expect(RoomEvents.playbackStateSync, 'playback:state_sync');
      expect(RoomEvents.bufferingStall, 'buffering:stall');
      expect(RoomEvents.bufferingReady, 'buffering:ready');
      expect(RoomEvents.bufferingResume, 'buffering:resume');
      expect(RoomEvents.pong, 'pong');
    });

    test('hub method names match expected SignalR method names', () {
      expect(RoomEvents.hubCreateRoom, 'CreateRoom');
      expect(RoomEvents.hubJoinRoom, 'JoinRoom');
      expect(RoomEvents.hubLeaveRoom, 'LeaveRoom');
      expect(RoomEvents.hubSetContent, 'SetContent');
      expect(RoomEvents.hubPlay, 'Play');
      expect(RoomEvents.hubPause, 'Pause');
      expect(RoomEvents.hubSeek, 'Seek');
      expect(RoomEvents.hubNotifyBufferingStall, 'NotifyBufferingStall');
      expect(RoomEvents.hubNotifyPlayerReady, 'NotifyPlayerReady');
      expect(RoomEvents.hubNotifyBufferingReady, 'NotifyBufferingReady');
      expect(RoomEvents.hubPing, 'Ping');
    });
  });

  group('Host grace payloads (BE-001/XP-001)', () {
    test('RoomHostAwayPayload parses grace seconds', () {
      final payload = RoomHostAwayPayload.fromJson({
        'serverTimestampMs': 1700000000000,
        'gracePeriodSeconds': 30,
      });
      expect(payload.serverTimestampMs, 1700000000000);
      expect(payload.gracePeriodSeconds, 30);
    });

    test('RoomHostReconnectedPayload parses timestamp', () {
      final payload = RoomHostReconnectedPayload.fromJson({
        'serverTimestampMs': 1700000000001,
      });
      expect(payload.serverTimestampMs, 1700000000001);
    });
  });

  group('BufferingResumePayload', () {
    test('includes episodeId field and parses correctly', () {
      final json = {
        'episodeId': 42,
        'serverTimestampMs': 1700000000000,
        'resumePositionMs': 12345,
      };
      final payload = BufferingResumePayload.fromJson(json);
      expect(payload.episodeId, 42);
      expect(payload.serverTimestampMs, 1700000000000);
      expect(payload.resumePositionMs, 12345);
    });

    test('episodeId defaults to 0 when missing', () {
      final json = {
        'serverTimestampMs': 1700000000000,
        'resumePositionMs': 5000,
      };
      final payload = BufferingResumePayload.fromJson(json);
      expect(payload.episodeId, 0);
    });
  });

  group('BufferingStallBroadcastPayload', () {
    test('includes episodeId field and parses correctly', () {
      final json = {
        'episodeId': 7,
        'role': 'guest',
        'positionMs': 9000,
        'serverTimestampMs': 1700000000001,
      };
      final payload = BufferingStallBroadcastPayload.fromJson(json);
      expect(payload.episodeId, 7);
      expect(payload.role, 'guest');
      expect(payload.positionMs, 9000);
      expect(payload.serverTimestampMs, 1700000000001);
    });

    test('episodeId defaults to 0 when missing', () {
      final json = {
        'role': 'host',
        'positionMs': 3000,
        'serverTimestampMs': 1700000000002,
      };
      final payload = BufferingStallBroadcastPayload.fromJson(json);
      expect(payload.episodeId, 0);
    });
  });

  group('PlaybackStateSyncPayload', () {
    test('includes seqNo field', () {
      final json = {
        'hostPositionMs': 60000,
        'isPlaying': true,
        'serverTimestampMs': 1700000000000,
        'seqNo': 5,
      };
      final payload = PlaybackStateSyncPayload.fromJson(json);
      expect(payload.seqNo, 5);
      expect(payload.hostPositionMs, 60000);
      expect(payload.isPlaying, isTrue);
    });

    test('seqNo defaults to 0 when absent', () {
      final json = {
        'hostPositionMs': 0,
        'isPlaying': false,
        'serverTimestampMs': 1700000000000,
      };
      final payload = PlaybackStateSyncPayload.fromJson(json);
      expect(payload.seqNo, 0);
    });
  });

  group('PlaybackSeekPayload', () {
    test('includes isPlaying field', () {
      final json = {
        'targetPositionMs': 30000,
        'serverTimestampMs': 1700000000000,
        'seqNo': 3,
        'isPlaying': true,
      };
      final payload = PlaybackSeekPayload.fromJson(json);
      expect(payload.isPlaying, isTrue);
      expect(payload.targetPositionMs, 30000);
    });

    test('isPlaying defaults to true when absent', () {
      final json = {
        'targetPositionMs': 0,
        'serverTimestampMs': 1700000000000,
        'seqNo': 0,
      };
      final payload = PlaybackSeekPayload.fromJson(json);
      expect(payload.isPlaying, isTrue);
    });
  });

  group('IptvContentDescriptor', () {
    test('round-trips through JSON', () {
      const descriptor = IptvContentDescriptor(
        contentType: IptvDescriptorType.episode,
        streamId: '999',
        containerExtension: 'mkv',
        title: 'Test Episode',
      );
      final json = descriptor.toJson();
      final restored = IptvContentDescriptor.fromJson(json);
      expect(restored, descriptor);
    });

    test('contentKey is stable and unique per content', () {
      const a = IptvContentDescriptor(
        contentType: IptvDescriptorType.movie,
        streamId: '1',
        containerExtension: 'mp4',
        title: 'Film A',
      );
      const b = IptvContentDescriptor(
        contentType: IptvDescriptorType.movie,
        streamId: '2',
        containerExtension: 'mp4',
        title: 'Film B',
      );
      expect(a.contentKey, isNot(b.contentKey));
    });
  });

  group('PlayerReadyPayload', () {
    test('parses all required fields', () {
      final json = {
        'bothReady': true,
        'readyRole': 'host',
        'serverTimestampMs': 1700000000000,
        'contentKey': 'episode|42|mkv',
      };
      final payload = PlayerReadyPayload.fromJson(json);
      expect(payload.bothReady, isTrue);
      expect(payload.readyRole, 'host');
      expect(payload.contentKey, 'episode|42|mkv');
    });
  });
}
