import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:watch_party/features/iptv/service/iptv_navigation_memory.dart';
import 'package:watch_party/features/reconnect/reconnect_bloc.dart';
import 'package:watch_party/features/room/bloc/room_bloc.dart';
import 'package:watch_party/features/room/bloc/room_event.dart';
import 'package:watch_party/features/room/bloc/room_list_bloc.dart';
import 'package:watch_party/features/room/bloc/room_state.dart';
import 'package:watch_party/features/room/screens/waiting_screen.dart';

class MockRoomBloc extends MockBloc<RoomEvent, RoomState> implements RoomBloc {}

class MockReconnectBloc extends MockBloc<ReconnectEvent, ReconnectState>
    implements ReconnectBloc {}

class MockRoomListBloc extends MockBloc<RoomListEvent, RoomListState>
    implements RoomListBloc {}

void main() {
  late MockRoomBloc roomBloc;
  late MockReconnectBloc reconnectBloc;
  late MockRoomListBloc roomListBloc;
  late StreamController<RoomState> roomStates;

  setUpAll(() {
    registerFallbackValue(const RoomEventLeaveRoom());
    registerFallbackValue(const ReconnectEventReset());
    registerFallbackValue(const RoomListFetch());
  });

  setUp(() {
    roomBloc = MockRoomBloc();
    reconnectBloc = MockReconnectBloc();
    roomListBloc = MockRoomListBloc();
    roomStates = StreamController<RoomState>.broadcast();

    when(() => roomBloc.state).thenReturn(
      const RoomStateWaiting(roomCode: 'ABC123', role: 'host'),
    );
    whenListen(
      roomBloc,
      roomStates.stream,
      initialState: const RoomStateWaiting(roomCode: 'ABC123', role: 'host'),
    );
    when(() => reconnectBloc.state).thenReturn(const ReconnectStateIdle());
    when(() => roomListBloc.state).thenReturn(const RoomListLoaded([]));

    if (GetIt.I.isRegistered<IptvNavigationMemory>()) {
      GetIt.I.unregister<IptvNavigationMemory>();
    }
    GetIt.I.registerSingleton<IptvNavigationMemory>(IptvNavigationMemory());
  });

  tearDown(() async {
    await roomStates.close();
    await GetIt.I.reset();
  });

  Widget buildWidget() {
    return MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<RoomBloc>.value(value: roomBloc),
          BlocProvider<ReconnectBloc>.value(value: reconnectBloc),
          BlocProvider<RoomListBloc>.value(value: roomListBloc),
        ],
        child: const WaitingScreen(),
      ),
    );
  }

  testWidgets('system back confirms and dispatches one leave event', (
    tester,
  ) async {
    await tester.pumpWidget(buildWidget());
    await tester.pump();

    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(find.text('Leave Room?'), findsOneWidget);
    expect(
      find.text('Leaving will close this room for everyone.'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Leave'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    verify(() => roomBloc.add(const RoomEventLeaveRoom())).called(1);

    await tester.binding.handlePopRoute();
    await tester.pump();

    verifyNever(() => roomBloc.add(const RoomEventLeaveRoom()));
  });

  testWidgets('closed room clears reconnect state and refreshes rooms list', (
    tester,
  ) async {
    await tester.pumpWidget(buildWidget());
    await tester.pump();

    roomStates.add(const RoomStateClosed('user_left'));
    await tester.pump();

    verify(() => reconnectBloc.add(const ReconnectEventReset())).called(1);
    verify(
      () => roomListBloc.add(const RoomListFetch(silent: true)),
    ).called(1);
  });
}
