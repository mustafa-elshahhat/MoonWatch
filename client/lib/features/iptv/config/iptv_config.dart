import 'dart:io';

/// IPTV provider configuration. Centralizes credentials and endpoint
/// construction. Designed to be replaceable for different providers.
class IptvConfig {
  final String username;
  final String password;
  final String baseUrl;

  const IptvConfig({
    required this.username,
    required this.password,
    required this.baseUrl,
  });

  // ── Built-in provider accounts ────────────────────────────────────
  // Credentials are injected via --dart-define during build.
  // Desktop/Windows -> account A; Android/Mobile -> account B.
  static const String _kBaseUrl = String.fromEnvironment(
    'IPTV_BASE_URL',
    defaultValue: 'http://xc.nv2.xyz',
  );

  static String get _kUsername {
    const envUser = String.fromEnvironment('IPTV_USERNAME');
    if (envUser.isNotEmpty) return envUser;
    return Platform.isAndroid ? 'Mostafaelshahat' : 'Mustafaelshahat';
  }

  static String get _kPassword {
    const envPass = String.fromEnvironment('IPTV_PASSWORD');
    if (envPass.isNotEmpty) return envPass;
    return Platform.isAndroid ? '8429934409' : 'Elshahat-112004';
  }

  /// Returns the configured account automatically.
  /// No manual credential entry is required in source code.
  static IptvConfig get defaultProvider => IptvConfig(
        username: _kUsername,
        password: _kPassword,
        baseUrl: _kBaseUrl,
      );

  /// Whether credentials are configured (always true for built-in defaults).
  bool get isConfigured =>
      username.isNotEmpty && password.isNotEmpty && baseUrl.isNotEmpty;

  // ── Xtream Codes API endpoints ───────────────────────────────────

  String get _authParams => 'username=$username&password=$password';

  /// Player API base for direct stream URLs.
  String get playerApiBase => '$baseUrl/player_api.php?$_authParams';

  /// Authentication / server info.
  Uri get authUrl => Uri.parse('$playerApiBase&action=get_server_info');

  // ── Live TV ──────────────────────────────────────────────────────

  Uri get liveCategoriesUrl =>
      Uri.parse('$playerApiBase&action=get_live_categories');

  Uri liveStreamsUrl({String? categoryId}) {
    final base = '$playerApiBase&action=get_live_streams';
    if (categoryId != null && categoryId != '0') {
      return Uri.parse('$base&category_id=$categoryId');
    }
    return Uri.parse(base);
  }

  /// Live stream playback URL.
  String livePlaybackUrl(String streamId, {String? extension}) {
    // Xtream Codes live streams typically don't have /live/ in the path
    // Format: http://domain:port/username/password/stream_id
    if (extension != null && extension.isNotEmpty) {
      return '$baseUrl/$username/$password/$streamId.$extension';
    }
    return '$baseUrl/$username/$password/$streamId';
  }

  // ── Movies / VOD ─────────────────────────────────────────────────

  Uri get vodCategoriesUrl =>
      Uri.parse('$playerApiBase&action=get_vod_categories');

  Uri vodStreamsUrl({String? categoryId}) {
    final base = '$playerApiBase&action=get_vod_streams';
    if (categoryId != null && categoryId != '0') {
      return Uri.parse('$base&category_id=$categoryId');
    }
    return Uri.parse(base);
  }

  /// Movie playback URL.
  String vodPlaybackUrl(String streamId, String containerExtension) {
    if (containerExtension.isEmpty) {
      return '$baseUrl/movie/$username/$password/$streamId';
    }
    return '$baseUrl/movie/$username/$password/$streamId.$containerExtension';
  }

  // ── Series ───────────────────────────────────────────────────────

  Uri get seriesCategoriesUrl =>
      Uri.parse('$playerApiBase&action=get_series_categories');

  Uri seriesListUrl({String? categoryId}) {
    final base = '$playerApiBase&action=get_series';
    if (categoryId != null && categoryId != '0') {
      return Uri.parse('$base&category_id=$categoryId');
    }
    return Uri.parse(base);
  }

  Uri seriesInfoUrl(String seriesId) =>
      Uri.parse('$playerApiBase&action=get_series_info&series_id=$seriesId');

  /// Episode playback URL.
  String episodePlaybackUrl(String streamId, String containerExtension) =>
      '$baseUrl/series/$username/$password/$streamId.$containerExtension';
}
