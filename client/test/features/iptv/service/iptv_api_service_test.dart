import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:watch_party/features/iptv/service/iptv_api_service.dart';
import 'package:watch_party/core/config/app_config.dart';
import 'package:watch_party/core/security/credential_store.dart';

class MockDio extends Mock implements Dio {}

class MockAppConfig extends Mock implements AppConfig {}

class MockCredentialStore extends Mock implements CredentialStore {}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri());
  });

  late MockAppConfig mockAppConfig;
  late MockCredentialStore mockCredentialStore;
  late MockDio mockDio;
  late IptvApiService apiService;

  setUp(() {
    mockAppConfig = MockAppConfig();
    mockCredentialStore = MockCredentialStore();
    mockDio = MockDio();

    when(() => mockAppConfig.iptvBaseUrl).thenReturn('http://api.test');
    when(() => mockDio.interceptors).thenReturn(Interceptors());
    when(() => mockDio.getUri(any())).thenAnswer((_) async => Response(
          data: [],
          requestOptions: RequestOptions(path: ''),
        ));

    apiService = IptvApiService(
      appConfig: mockAppConfig,
      credentialStore: mockCredentialStore,
      dio: mockDio,
    );
  });

  group('IptvApiService', () {
    test('refuses requests when credentials are missing', () async {
      when(() => mockCredentialStore.readIptvCredentials())
          .thenAnswer((_) async => null);

      expect(apiService.authenticate(), throwsA(isA<IptvApiException>()));
    });

    test('initializes config on first request if credentials exist', () async {
      when(() => mockCredentialStore.readIptvCredentials()).thenAnswer(
          (_) async => IptvCredentials(username: 'user', password: 'pass'));

      try {
        await apiService.getLiveCategories();
      } catch (_) {}

      verify(() => mockCredentialStore.readIptvCredentials()).called(1);
    });

    test('getConfiguredConfig initializes config from stored credentials',
        () async {
      when(() => mockCredentialStore.readIptvCredentials()).thenAnswer(
          (_) async => IptvCredentials(username: 'user', password: 'pass'));

      final config = await apiService.getConfiguredConfig();

      expect(config.username, 'user');
      expect(config.password, 'pass');
      expect(config.baseUrl, 'http://api.test');
      verify(() => mockCredentialStore.readIptvCredentials()).called(1);
    });
  });
}
