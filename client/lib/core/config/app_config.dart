import 'dart:convert';
import 'package:flutter/services.dart'
    show rootBundle, PlatformException;

class AppConfig {
  final String serverBaseUrl;
  final String iptvBaseUrl;

  AppConfig({
    required this.serverBaseUrl,
    required this.iptvBaseUrl,
  });

  static Future<AppConfig> load() async {
    String jsonString;
    try {
      jsonString =
          await rootBundle.loadString('assets/config/appsettings.local.json');
    } catch (e) {
      throw Exception(
        'Configuration file appsettings.local.json not found. '
        'Copy appsettings.example.json to appsettings.local.json and '
        'update with your server and IPTV provider URLs. '
        'Details: $e'
      );
    }

    final Map<String, dynamic> json = jsonDecode(jsonString);

    final serverUrl = _normalizeUrl(json['serverBaseUrl'] as String?);
    final iptvUrl = _normalizeUrl(json['iptvBaseUrl'] as String?);

    if (serverUrl == null || serverUrl.isEmpty) {
      throw Exception('serverBaseUrl is missing in config');
    }
    if (iptvUrl == null || iptvUrl.isEmpty) {
      throw Exception('iptvBaseUrl is missing in config');
    }

    _validateUrl(serverUrl, 'serverBaseUrl');
    _validateUrl(iptvUrl, 'iptvBaseUrl');

    return AppConfig(
      serverBaseUrl: serverUrl,
      iptvBaseUrl: iptvUrl,
    );
  }

  static String? _normalizeUrl(String? url) {
    if (url == null) return null;
    var trimmed = url.trim();
    if (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  static void _validateUrl(String url, String field) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      throw Exception('$field is not a valid absolute URL: $url');
    }
  }
}
