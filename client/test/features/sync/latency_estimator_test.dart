import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:watch_party/core/network/signalr_client.dart';
import 'package:watch_party/core/protocol/room_events.dart';
import 'package:watch_party/features/sync/latency_estimator.dart';

class MockSignalRClient extends Mock implements SignalRClient {}

void main() {
  late MockSignalRClient mockSignalR;
  late LatencyEstimator estimator;

  setUp(() {
    mockSignalR = MockSignalRClient();
    when(() => mockSignalR.on(any(), any())).thenReturn(null);
    when(() => mockSignalR.off(any())).thenReturn(null);
    when(
      () => mockSignalR.invoke(any(), args: any(named: 'args')),
    ).thenAnswer((_) async => null);
    estimator = LatencyEstimator(signalRClient: mockSignalR);
  });

  tearDown(() {
    estimator.stop();
  });

  group('LatencyEstimator — idempotency', () {
    test('start() sends an immediate ping', () {
      estimator.start();

      verify(
        () => mockSignalR.invoke(RoomEvents.hubPing, args: any(named: 'args')),
      ).called(1);
    });

    test('calling start() a second time while already running is a no-op', () {
      estimator.start();

      // Reset interaction count so we can assert the second call adds nothing.
      clearInteractions(mockSignalR);

      estimator.start(); // idempotency guard should block this

      // No additional ping or handler registration should occur.
      verifyNever(() => mockSignalR.invoke(any(), args: any(named: 'args')));
      verifyNever(() => mockSignalR.on(any(), any()));
    });

    test('stop() then start() produces a clean restart with one ping', () {
      estimator.start();
      estimator.stop();

      clearInteractions(mockSignalR);

      estimator.start();

      // Exactly one immediate ping on clean restart.
      verify(
        () => mockSignalR.invoke(RoomEvents.hubPing, args: any(named: 'args')),
      ).called(1);
    });

    test('stop() registers off() for pong and clears internal state', () {
      estimator.start();
      estimator.stop();

      verify(() => mockSignalR.off(RoomEvents.pong)).called(1);
      // After stop(), currentRttMs is reset to default and clockOffsetMs to 0.
      expect(estimator.currentRttMs, greaterThan(0)); // default constant
      expect(estimator.clockOffsetMs, 0);
    });

    test(
      'multiple start()/stop() cycles each register exactly one pong handler',
      () {
        estimator.start();
        estimator.stop();
        estimator.start();
        estimator.stop();

        // on() called once per start() = 2 times total.
        verify(() => mockSignalR.on(RoomEvents.pong, any())).called(2);
        // off() called once per stop() = 2 times total.
        verify(() => mockSignalR.off(RoomEvents.pong)).called(2);
      },
    );
  });
}
