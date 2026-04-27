import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watch_party/features/sync/sync_engine.dart';
import 'package:watch_party/core/player/mock_player_impl.dart';
import '../../mocks/mock_room_repository.dart';

void main() {
  late MockPlayerImpl mockPlayer;
  late MockRoomRepository mockRepo;
  late SyncBloc syncBloc;

  setUp(() {
    mockPlayer = MockPlayerImpl();
    mockRepo = MockRoomRepository();
    syncBloc = SyncBloc(playerController: mockPlayer, roomRepository: mockRepo);
    // Tests exercise guest sync behavior — mark player as ready.
    syncBloc.setPlayerReady(true);
  });

  tearDown(() async {
    await syncBloc.close();
  });

  group('SyncBloc — drift detection', () {
    blocTest<SyncBloc, SyncState>(
      'drift below threshold: no seek issued',
      build: () {
        mockPlayer.setPosition(const Duration(milliseconds: 10000));
        return syncBloc;
      },
      act: (bloc) {
        final now = DateTime.now().millisecondsSinceEpoch;
        bloc.add(
          SyncEventStateSyncReceived(
            hostPositionMs: 10200, // 200ms drift, below 500ms threshold
            isPlaying: true,
            serverTimestampMs: now,
          ),
        );
      },
      expect: () => <SyncState>[],
      verify: (_) {
        expect(mockPlayer.seekHistory, isEmpty);
      },
    );

    blocTest<SyncBloc, SyncState>(
      'drift above threshold: correction seek issued after hysteresis',
      build: () {
        mockPlayer.setPosition(const Duration(milliseconds: 10000));
        return syncBloc;
      },
      act: (bloc) async {
        // Hysteresis requires 2 consecutive drift hits before correction.
        for (var i = 0; i < 2; i++) {
          mockPlayer.setPosition(const Duration(milliseconds: 10000));
          final now = DateTime.now().millisecondsSinceEpoch;
          bloc.add(
            SyncEventStateSyncReceived(
              hostPositionMs: 10800, // 800ms drift, above 500ms threshold
              isPlaying: true,
              serverTimestampMs: now,
            ),
          );
          await Future.delayed(const Duration(milliseconds: 10));
        }
      },
      wait: const Duration(milliseconds: 100),
      expect: () => [const SyncStateSyncing()],
      verify: (_) {
        expect(mockPlayer.seekHistory, isNotEmpty);
        final seekTarget = mockPlayer.seekHistory.last.inMilliseconds;
        expect(seekTarget, closeTo(10800, 50));
      },
    );

    blocTest<SyncBloc, SyncState>(
      'host-ahead correction: guest seeks forward after hysteresis',
      build: () {
        mockPlayer.setPosition(const Duration(milliseconds: 5000));
        return syncBloc;
      },
      act: (bloc) async {
        // Hysteresis requires 2 consecutive drift hits before correction.
        for (var i = 0; i < 2; i++) {
          mockPlayer.setPosition(const Duration(milliseconds: 5000));
          final now = DateTime.now().millisecondsSinceEpoch;
          bloc.add(
            SyncEventStateSyncReceived(
              hostPositionMs: 8000, // 3000ms ahead of guest
              isPlaying: true,
              serverTimestampMs: now,
            ),
          );
          await Future.delayed(const Duration(milliseconds: 10));
        }
      },
      wait: const Duration(milliseconds: 100),
      expect: () => [const SyncStateSyncing()],
      verify: (_) {
        expect(mockPlayer.seekHistory, isNotEmpty);
        final seekTarget = mockPlayer.seekHistory.last.inMilliseconds;
        expect(seekTarget, greaterThan(5000));
        expect(seekTarget, closeTo(8000, 50));
      },
    );

    blocTest<SyncBloc, SyncState>(
      'drift above threshold while paused: emits SyncStatePaused after hysteresis',
      build: () {
        mockPlayer.setPosition(const Duration(milliseconds: 10000));
        return syncBloc;
      },
      act: (bloc) async {
        // Hysteresis requires 2 consecutive drift hits before correction.
        for (var i = 0; i < 2; i++) {
          mockPlayer.setPosition(const Duration(milliseconds: 10000));
          final now = DateTime.now().millisecondsSinceEpoch;
          bloc.add(
            SyncEventStateSyncReceived(
              hostPositionMs: 11000,
              isPlaying: false, // host is paused
              serverTimestampMs: now,
            ),
          );
          await Future.delayed(const Duration(milliseconds: 10));
        }
      },
      wait: const Duration(milliseconds: 100),
      expect: () => [const SyncStatePaused()],
      verify: (_) {
        expect(mockPlayer.seekHistory, isNotEmpty);
        expect(mockPlayer.actionHistory, contains('pause'));
      },
    );
  });

  group('SyncBloc — correction throttling', () {
    blocTest<SyncBloc, SyncState>(
      'post-command cooldown prevents excessive corrections',
      build: () {
        mockPlayer.setPosition(const Duration(milliseconds: 10000));
        return syncBloc;
      },
      act: (bloc) async {
        // First 2 events satisfy hysteresis, triggering 1 correction.
        // Subsequent events are blocked by the 6s post-command cooldown.
        for (var i = 0; i < 6; i++) {
          mockPlayer.setPosition(const Duration(milliseconds: 10000));
          final now = DateTime.now().millisecondsSinceEpoch;
          bloc.add(
            SyncEventStateSyncReceived(
              hostPositionMs: 11000 + (i * 100),
              isPlaying: true,
              serverTimestampMs: now,
            ),
          );
          await Future.delayed(const Duration(milliseconds: 10));
        }
      },
      wait: const Duration(milliseconds: 200),
      // Only 1 correction fires (after hysteresis on event #2);
      // events #3-#6 are blocked by cooldown.
      expect: () => [
        const SyncStateSyncing(), // single correction
      ],
    );
  });

  group('SyncBloc — play received', () {
    blocTest<SyncBloc, SyncState>(
      'seeks to latency-adjusted position and plays',
      build: () => syncBloc,
      act: (bloc) {
        final now = DateTime.now().millisecondsSinceEpoch;
        bloc.add(
          SyncEventPlayReceived(
            positionMs: 5000,
            serverTimestampMs: now,
            hostRttMs: 100,
          ),
        );
      },
      expect: () => [const SyncStateSyncing()],
      verify: (_) {
        expect(mockPlayer.seekHistory, isNotEmpty);
        // adjusted = 5000 + ~0 elapsed + 100/2 + 100/2 = ~5100 (default guest RTT = 100)
        expect(mockPlayer.seekHistory.last.inMilliseconds, closeTo(5100, 50));
        expect(mockPlayer.actionHistory, contains('play'));
      },
    );

    blocTest<SyncBloc, SyncState>(
      'uses updated guest RTT for latency compensation',
      build: () {
        syncBloc.updateGuestRtt(200);
        return syncBloc;
      },
      act: (bloc) {
        final now = DateTime.now().millisecondsSinceEpoch;
        bloc.add(
          SyncEventPlayReceived(
            positionMs: 5000,
            serverTimestampMs: now,
            hostRttMs: 100,
          ),
        );
      },
      expect: () => [const SyncStateSyncing()],
      verify: (_) {
        // adjusted = 5000 + ~0 elapsed + 100/2 = ~5050
        // (guestRttMs/2 no longer added — clock offset handles server→guest delay)
        expect(mockPlayer.seekHistory.last.inMilliseconds, closeTo(5050, 50));
      },
    );
  });

  group('SyncBloc — pause received', () {
    blocTest<SyncBloc, SyncState>(
      'pauses and seeks to specified position',
      build: () => syncBloc,
      act: (bloc) {
        bloc.add(const SyncEventPauseReceived(positionMs: 3000));
      },
      expect: () => [const SyncStatePaused()],
      verify: (_) {
        expect(mockPlayer.actionHistory, contains('pause'));
        expect(mockPlayer.seekHistory.last, const Duration(milliseconds: 3000));
      },
    );
  });

  group('SyncBloc — seek received', () {
    blocTest<SyncBloc, SyncState>(
      'seeks to target position and emits paused when not playing',
      build: () => syncBloc,
      act: (bloc) {
        bloc.add(const SyncEventSeekReceived(targetPositionMs: 60000));
      },
      expect: () => [const SyncStatePaused()],
      verify: (_) {
        expect(
          mockPlayer.seekHistory.last,
          const Duration(milliseconds: 60000),
        );
      },
    );
  });

  group('SyncBloc — buffering', () {
    blocTest<SyncBloc, SyncState>(
      'player stall emits SyncStateBuffering',
      build: () => syncBloc,
      act: (bloc) {
        bloc.add(const SyncEventPlayerStalled());
      },
      expect: () => [const SyncStateBuffering()],
    );

    blocTest<SyncBloc, SyncState>(
      'player ready while in Buffering stays in Buffering',
      build: () {
        final bloc = SyncBloc(
          playerController: mockPlayer,
          roomRepository: mockRepo,
        );
        bloc.setPlayerReady(true);
        return bloc;
      },
      seed: () => const SyncStateBuffering(),
      act: (bloc) async {
        await mockPlayer.play(); // set isPlaying = true
        bloc.add(const SyncEventPlayerReady());
      },
      expect: () => [],
    );

    blocTest<SyncBloc, SyncState>(
      'player ready when not in Buffering while playing: no state change (already Syncing)',
      build: () {
        final bloc = SyncBloc(
          playerController: mockPlayer,
          roomRepository: mockRepo,
        );
        bloc.setPlayerReady(true);
        return bloc;
      },
      seed: () => const SyncStateSyncing(),
      act: (bloc) async {
        await mockPlayer.play(); // set isPlaying = true
        bloc.add(const SyncEventPlayerReady());
      },
      // Bloc deduplicates: current state is already SyncStateSyncing.
      expect: () => <SyncState>[],
    );

    blocTest<SyncBloc, SyncState>(
      'player ready when not in Buffering while paused: no state change (already Paused)',
      build: () {
        final bloc = SyncBloc(
          playerController: mockPlayer,
          roomRepository: mockRepo,
        );
        bloc.setPlayerReady(true);
        return bloc;
      },
      seed: () => const SyncStatePaused(),
      act: (bloc) {
        // mockPlayer.isPlaying is false by default
        bloc.add(const SyncEventPlayerReady());
      },
      // Bloc deduplicates: current state is already SyncStatePaused.
      expect: () => <SyncState>[],
    );
  });

  // —— Problem 3: state_sync gating while player not ready ——————————————————

  group('SyncBloc — state_sync deferred while player not ready', () {
    blocTest<SyncBloc, SyncState>(
      'state_sync is deferred (not applied) while playerReady=false',
      build: () {
        // Guest role, player explicitly NOT ready.
        final bloc = SyncBloc(
          playerController: mockPlayer,
          roomRepository: mockRepo,
        );
        bloc.setRole('guest');
        // Do NOT call setPlayerReady(true) — player is loading.
        return bloc;
      },
      act: (bloc) {
        mockPlayer.setPosition(
          Duration.zero,
        ); // guest at 0 — new content loading
        final now = DateTime.now().millisecondsSinceEpoch;
        bloc.add(
          SyncEventStateSyncReceived(
            hostPositionMs: 10136, // host is 10 s ahead
            isPlaying: true,
            serverTimestampMs: now,
          ),
        );
      },
      wait: const Duration(milliseconds: 100),
      expect: () => <SyncState>[], // no state change — no correction
      verify: (_) {
        expect(mockPlayer.seekHistory, isEmpty); // no correction seek
      },
    );

    blocTest<SyncBloc, SyncState>(
      'state_sync applies normally once playerReady=true',
      build: () {
        final bloc = SyncBloc(
          playerController: mockPlayer,
          roomRepository: mockRepo,
        );
        bloc.setRole('guest');
        bloc.setPlayerReady(true);
        return bloc;
      },
      act: (bloc) async {
        // Two hits to satisfy hysteresis threshold of 2.
        for (var i = 0; i < 2; i++) {
          mockPlayer.setPosition(const Duration(milliseconds: 10000));
          final now = DateTime.now().millisecondsSinceEpoch;
          bloc.add(
            SyncEventStateSyncReceived(
              hostPositionMs: 11000, // 1000ms drift, above threshold
              isPlaying: true,
              serverTimestampMs: now,
            ),
          );
          await Future.delayed(const Duration(milliseconds: 10));
        }
      },
      wait: const Duration(milliseconds: 100),
      expect: () => [const SyncStateSyncing()], // correction fired
      verify: (_) {
        expect(mockPlayer.seekHistory, isNotEmpty);
      },
    );

    blocTest<SyncBloc, SyncState>(
      'drift hits reset when player transitions not-ready → ready (new content)',
      build: () {
        final bloc = SyncBloc(
          playerController: mockPlayer,
          roomRepository: mockRepo,
        );
        bloc.setRole('guest');
        bloc.setPlayerReady(true);
        return bloc;
      },
      act: (bloc) async {
        // First drift hit — below hysteresis threshold of 2.
        mockPlayer.setPosition(const Duration(milliseconds: 10000));
        bloc.add(
          SyncEventStateSyncReceived(
            hostPositionMs: 11000,
            isPlaying: true,
            serverTimestampMs: DateTime.now().millisecondsSinceEpoch,
          ),
        );
        await Future.delayed(const Duration(milliseconds: 10));

        // New content starts loading → playerReady goes false then true.
        // This must reset _consecutiveDriftHits to 0.
        bloc.setPlayerReady(false);
        bloc.setPlayerReady(true);

        // Second drift hit after reset — should NOT trigger correction because
        // the hysteresis counter was reset (only 1 hit in new window, need 2).
        mockPlayer.setPosition(const Duration(milliseconds: 10000));
        bloc.add(
          SyncEventStateSyncReceived(
            hostPositionMs: 11000,
            isPlaying: true,
            serverTimestampMs: DateTime.now().millisecondsSinceEpoch,
          ),
        );
        await Future.delayed(const Duration(milliseconds: 10));
      },
      wait: const Duration(milliseconds: 100),
      // No correction — only 1 consecutive hit in the second window (need 2).
      expect: () => <SyncState>[],
      verify: (_) {
        expect(mockPlayer.seekHistory, isEmpty);
      },
    );
  });
  group('SyncBloc - player ready notifications', () {
    blocTest<SyncBloc, SyncState>(
      'notifies ready once per content key and sends again for new content',
      build: () => syncBloc,
      act: (bloc) {
        bloc.setPlayerReady(true, contentKey: 'episode|1|m3u8');
        bloc.setPlayerReady(true, contentKey: 'episode|1|m3u8');
        bloc.setPlayerReady(true, contentKey: 'episode|2|m3u8');
      },
      expect: () => <SyncState>[],
      verify: (_) {
        expect(mockRepo.notifyPlayerReadyCalls, [
          'episode|1|m3u8',
          'episode|2|m3u8',
        ]);
      },
    );
  });
}
