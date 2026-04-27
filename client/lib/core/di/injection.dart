import 'package:get_it/get_it.dart';
import '../network/signalr_client.dart';
import '../network/http_client.dart';
import '../player/player_controller.dart';
import '../player/media_kit_player_impl.dart';
import '../../features/room/repository/room_repository.dart';
import '../../features/room/bloc/room_bloc.dart';
import '../../features/player/bloc/player_bloc.dart';
import '../../features/sync/sync_engine.dart';
import '../../features/sync/latency_estimator.dart';
import '../../features/reconnect/reconnect_bloc.dart';
import '../../features/iptv/config/iptv_config.dart';
import '../../features/iptv/service/iptv_api_service.dart';
import '../../features/iptv/repository/iptv_repository.dart';
import '../../features/iptv/bloc/iptv_bloc.dart';
import '../../features/iptv/service/iptv_navigation_memory.dart';

final getIt = GetIt.instance;

/// Registers all singletons and factories for DI.
void configureDependencies() {
  // Singletons — network
  getIt.registerLazySingleton<SignalRClient>(() => SignalRClient());
  getIt.registerLazySingleton<HttpClient>(() => HttpClient());

  // Singletons — repositories
  getIt.registerLazySingleton<RoomRepository>(
    () => RoomRepository(
      signalRClient: getIt<SignalRClient>(),
      httpClient: getIt<HttpClient>(),
    ),
  );

  // Singletons — player
  getIt.registerLazySingleton<PlayerController>(() => MediaKitPlayerImpl());

  // Singletons — sync
  getIt.registerLazySingleton<LatencyEstimator>(
    () => LatencyEstimator(signalRClient: getIt<SignalRClient>()),
  );

  // Factories — BLoCs
  getIt.registerFactory<RoomBloc>(
    () => RoomBloc(
      roomRepository: getIt<RoomRepository>(),
      signalRClient: getIt<SignalRClient>(),
    ),
  );

  getIt.registerFactory<PlayerBloc>(
    () => PlayerBloc(playerController: getIt<PlayerController>()),
  );

  getIt.registerFactory<SyncBloc>(
    () => SyncBloc(
      playerController: getIt<PlayerController>(),
      roomRepository: getIt<RoomRepository>(),
    ),
  );

  getIt.registerFactory<ReconnectBloc>(
    () => ReconnectBloc(
      signalRClient: getIt<SignalRClient>(),
      roomRepository: getIt<RoomRepository>(),
    ),
  );

  // IPTV — config, service, repository, bloc, memory
  getIt.registerLazySingleton<IptvConfig>(() => IptvConfig.defaultProvider);
  getIt.registerLazySingleton<IptvNavigationMemory>(
    () => IptvNavigationMemory(),
  );
  getIt.registerLazySingleton<IptvApiService>(
    () => IptvApiService(config: getIt<IptvConfig>()),
  );
  getIt.registerLazySingleton<IptvRepository>(
    () => IptvRepository(apiService: getIt<IptvApiService>()),
  );
  getIt.registerFactory<IptvBloc>(
    () => IptvBloc(repository: getIt<IptvRepository>()),
  );
}
