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
import '../../features/iptv/service/iptv_api_service.dart';
import '../../features/iptv/repository/iptv_repository.dart';
import '../../features/iptv/bloc/iptv_bloc.dart';
import '../../features/iptv/service/iptv_navigation_memory.dart';
import '../../features/room/bloc/room_list_bloc.dart';
import '../config/app_config.dart';
import '../security/credential_store.dart';
import '../../features/auth/bloc/auth_bloc.dart';

final getIt = GetIt.instance;

Future<void> configureDependencies({required AppConfig appConfig}) async {
  getIt.registerSingleton<AppConfig>(appConfig);
  getIt.registerLazySingleton<CredentialStore>(() => CredentialStore());

  getIt.registerLazySingleton<SignalRClient>(
    () => SignalRClient(baseUrl: appConfig.serverBaseUrl),
  );
  getIt.registerLazySingleton<HttpClient>(
    () => HttpClient(baseUrl: appConfig.serverBaseUrl),
  );

  getIt.registerLazySingleton<RoomRepository>(
    () => RoomRepository(
      signalRClient: getIt<SignalRClient>(),
      httpClient: getIt<HttpClient>(),
    ),
  );

  getIt.registerLazySingleton<PlayerController>(() => MediaKitPlayerImpl());

  getIt.registerLazySingleton<LatencyEstimator>(
    () => LatencyEstimator(signalRClient: getIt<SignalRClient>()),
  );

  getIt.registerFactory<RoomBloc>(
    () => RoomBloc(
      roomRepository: getIt<RoomRepository>(),
      signalRClient: getIt<SignalRClient>(),
    ),
  );
  getIt.registerFactory<RoomListBloc>(
    () => RoomListBloc(repository: getIt<RoomRepository>()),
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

  getIt.registerLazySingleton<IptvNavigationMemory>(
    () => IptvNavigationMemory(),
  );
  getIt.registerLazySingleton<IptvApiService>(
    () => IptvApiService(
      appConfig: getIt<AppConfig>(),
      credentialStore: getIt<CredentialStore>(),
    ),
  );
  getIt.registerLazySingleton<IptvRepository>(
    () => IptvRepository(apiService: getIt<IptvApiService>()),
  );
  getIt.registerFactory<IptvBloc>(
    () => IptvBloc(repository: getIt<IptvRepository>()),
  );

  getIt.registerFactory<AuthBloc>(
    () => AuthBloc(
      credentialStore: getIt<CredentialStore>(),
      iptvApiService: getIt<IptvApiService>(),
    ),
  );
}
