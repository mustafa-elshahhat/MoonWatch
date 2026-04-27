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
  late MockAppConfig mockAppConfig;
  late MockCredentialStore mockCredentialStore;
  late IptvApiService apiService;

  setUp(() {
    mockAppConfig = MockAppConfig();
    mockCredentialStore = MockCredentialStore();
    
    when(() => mockAppConfig.iptvBaseUrl).thenReturn('http://api.test');
    
    apiService = IptvApiService(
      appConfig: mockAppConfig,
      credentialStore: mockCredentialStore,
    );
  });

  group('IptvApiService', () {
    test('refuses requests when credentials are missing', () async {
      when(() => mockCredentialStore.readIptvCredentials()).thenAnswer((_) async => null);

      expect(apiService.authenticate(), throwsA(isA<IptvApiException>()));
    });

    test('initializes config on first request if credentials exist', () async {
      when(() => mockCredentialStore.readIptvCredentials()).thenAnswer((_) async =>
          IptvCredentials(username: 'user', password: 'pass'));

      try {
        await apiService.getLiveCategories();
      } catch (_) {}

      verify(() => mockCredentialStore.readIptvCredentials()).called(1);
    });
  });
}
