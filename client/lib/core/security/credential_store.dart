import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class IptvCredentials {
  final String username;
  final String password;

  IptvCredentials({required this.username, required this.password});
}

class CredentialStore {
  final FlutterSecureStorage _storage;
  static const _keyUsername = 'iptv_username';
  static const _keyPassword = 'iptv_password';

  CredentialStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  Future<void> saveIptvCredentials(String username, String password) async {
    await _storage.write(key: _keyUsername, value: username.trim());
    await _storage.write(key: _keyPassword, value: password);
  }

  Future<IptvCredentials?> readIptvCredentials() async {
    final username = await _storage.read(key: _keyUsername);
    final password = await _storage.read(key: _keyPassword);

    if (username != null && password != null) {
      return IptvCredentials(username: username, password: password);
    }
    return null;
  }

  Future<void> clearIptvCredentials() async {
    await _storage.delete(key: _keyUsername);
    await _storage.delete(key: _keyPassword);
  }

  Future<bool> hasIptvCredentials() async {
    final credentials = await readIptvCredentials();
    return credentials != null;
  }
}
