import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:watch_party/features/auth/bloc/auth_bloc.dart';
import 'package:watch_party/core/security/credential_store.dart';
import 'package:watch_party/features/iptv/service/iptv_api_service.dart';

class MockCredentialStore extends Mock implements CredentialStore {}

class MockIptvApiService extends Mock implements IptvApiService {}

void main() {
  late MockCredentialStore mockCredentialStore;
  late MockIptvApiService mockIptvApiService;

  setUp(() {
    mockCredentialStore = MockCredentialStore();
    mockIptvApiService = MockIptvApiService();
  });

  group('AuthBloc', () {
    blocTest<AuthBloc, AuthState>(
      'emits [Authenticated] when credentials exist on check',
      setUp: () {
        when(() => mockCredentialStore.hasIptvCredentials())
            .thenAnswer((_) async => true);
      },
      build: () => AuthBloc(
        credentialStore: mockCredentialStore,
        iptvApiService: mockIptvApiService,
      ),
      act: (bloc) => bloc.add(AuthCheckRequested()),
      expect: () => [AuthAuthenticated()],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [Loading, Authenticated] on successful login',
      setUp: () {
        when(() => mockIptvApiService.verifyCredentials('user', 'pass'))
            .thenAnswer((_) async => true);
        when(() => mockCredentialStore.saveIptvCredentials('user', 'pass'))
            .thenAnswer((_) async => {});
        when(() => mockIptvApiService.clearConfig()).thenReturn(null);
      },
      build: () => AuthBloc(
        credentialStore: mockCredentialStore,
        iptvApiService: mockIptvApiService,
      ),
      act: (bloc) => bloc.add(const AuthLoginSubmitted(' user ', 'pass')),
      expect: () => [
        AuthLoading(),
        AuthAuthenticated(),
      ],
      verify: (_) {
        verify(() => mockCredentialStore.saveIptvCredentials('user', 'pass'))
            .called(1);
        verify(() => mockIptvApiService.clearConfig()).called(1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'emits [Loading, Error] on invalid credentials',
      setUp: () {
        when(() => mockIptvApiService.verifyCredentials('user', 'wrong'))
            .thenAnswer((_) async => false);
      },
      build: () => AuthBloc(
        credentialStore: mockCredentialStore,
        iptvApiService: mockIptvApiService,
      ),
      act: (bloc) => bloc.add(const AuthLoginSubmitted('user', 'wrong')),
      expect: () => [
        AuthLoading(),
        const AuthError('Invalid IPTV username or password.'),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [Unauthenticated] on logout',
      setUp: () {
        when(() => mockCredentialStore.clearIptvCredentials())
            .thenAnswer((_) async => {});
        when(() => mockIptvApiService.clearConfig()).thenReturn(null);
      },
      build: () => AuthBloc(
        credentialStore: mockCredentialStore,
        iptvApiService: mockIptvApiService,
      ),
      act: (bloc) => bloc.add(AuthLogoutRequested()),
      expect: () => [AuthUnauthenticated()],
      verify: (_) {
        verify(() => mockCredentialStore.clearIptvCredentials()).called(1);
        verify(() => mockIptvApiService.clearConfig()).called(1);
      },
    );
  });
}
