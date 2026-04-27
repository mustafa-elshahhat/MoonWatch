import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/di/injection.dart';
import 'core/theme/app_theme.dart';
import 'features/room/bloc/room_bloc.dart';
import 'features/room/bloc/room_list_bloc.dart';
import 'features/reconnect/reconnect_bloc.dart';
import 'features/iptv/bloc/iptv_bloc.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/room/screens/home_screen.dart';
import 'features/room/screens/create_room_screen.dart';
import 'features/room/screens/join_room_screen.dart';
import 'features/room/screens/waiting_screen.dart';
import 'features/player/screens/watch_screen.dart';
import 'features/player/screens/solo_player_screen.dart';
import 'features/iptv/screens/iptv_browse_screen.dart';
import 'features/navigation/screens/main_shell.dart';
import 'features/auth/screens/iptv_login_screen.dart';

class WatchPartyApp extends StatelessWidget {
  const WatchPartyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<RoomBloc>(create: (_) => getIt<RoomBloc>()),
        BlocProvider<ReconnectBloc>(create: (_) => getIt<ReconnectBloc>()),
        BlocProvider<IptvBloc>(create: (_) => getIt<IptvBloc>()),
        BlocProvider<RoomListBloc>(create: (_) => getIt<RoomListBloc>()),
        BlocProvider<AuthBloc>(
          create: (_) => getIt<AuthBloc>()..add(AuthCheckRequested()),
        ),
      ],
      child: MaterialApp(
        title: 'WatchParty',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        initialRoute: '/',
        onGenerateRoute: (settings) {
          if (settings.name == '/') {
            return MaterialPageRoute(
              builder: (context) => BlocBuilder<AuthBloc, AuthState>(
                builder: (context, state) {
                  if (state is AuthAuthenticated) {
                    return const MainShell();
                  } else if (state is AuthUnauthenticated ||
                      state is AuthError) {
                    return const IptvLoginScreen();
                  }
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                },
              ),
            );
          }
          return null;
        },
        routes: {
          '/home': (_) => const HomeScreen(),
          '/login': (_) => const IptvLoginScreen(),
          '/create': (_) => const CreateRoomScreen(),
          '/join': (_) => const JoinRoomScreen(),
          '/waiting': (_) => const WaitingScreen(),
          '/watch': (_) => const WatchScreen(),
          '/solo-player': (_) => const SoloPlayerScreen(),
          '/iptv': (_) => const IptvBrowseScreen(),
        },
      ),
    );
  }
}
