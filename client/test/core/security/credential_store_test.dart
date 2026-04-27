import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:watch_party/core/security/credential_store.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late MockFlutterSecureStorage mockStorage;
  late CredentialStore credentialStore;

  setUp(() {
    mockStorage = MockFlutterSecureStorage();
    credentialStore = CredentialStore(storage: mockStorage);
  });

  group('CredentialStore', () {
    test('saveIptvCredentials writes to secure storage', () async {
      when(() => mockStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          )).thenAnswer((_) async => {});

      await credentialStore.saveIptvCredentials(' test_user ', 'pass123');

      verify(() => mockStorage.write(key: 'iptv_username', value: 'test_user'))
          .called(1);
      verify(() => mockStorage.write(key: 'iptv_password', value: 'pass123'))
          .called(1);
    });

    test('readIptvCredentials returns credentials when they exist', () async {
      when(() => mockStorage.read(key: 'iptv_username'))
          .thenAnswer((_) async => 'user');
      when(() => mockStorage.read(key: 'iptv_password'))
          .thenAnswer((_) async => 'pass');

      final creds = await credentialStore.readIptvCredentials();

      expect(creds?.username, 'user');
      expect(creds?.password, 'pass');
    });

    test('readIptvCredentials returns null when missing', () async {
      when(() => mockStorage.read(key: any(named: 'key')))
          .thenAnswer((_) async => null);

      final creds = await credentialStore.readIptvCredentials();

      expect(creds, isNull);
    });

    test('clearIptvCredentials deletes from secure storage', () async {
      when(() => mockStorage.delete(key: any(named: 'key')))
          .thenAnswer((_) async => {});

      await credentialStore.clearIptvCredentials();

      verify(() => mockStorage.delete(key: 'iptv_username')).called(1);
      verify(() => mockStorage.delete(key: 'iptv_password')).called(1);
    });

    test('hasIptvCredentials returns true if both keys exist', () async {
      when(() => mockStorage.read(key: 'iptv_username'))
          .thenAnswer((_) async => 'user');
      when(() => mockStorage.read(key: 'iptv_password'))
          .thenAnswer((_) async => 'pass');

      expect(await credentialStore.hasIptvCredentials(), isTrue);
    });
  });
}
