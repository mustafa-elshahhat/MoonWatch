/// IPTV provider configuration. Credentials and base URL are injected via
/// --dart-define at build time. Never hardcode credentials here.
class IptvConfig {
  final String username;
  final String password;
  final String baseUrl;

  const IptvConfig({
    required this.username,
    required this.password,
    required this.baseUrl,
  });

  // Supply credentials at build time:
  //   --dart-define=IPTV_BASE_URL=http://...
  //   --dart-define=IPTV_USERNAME=your_user
  //   --dart-define=IPTV_PASSWORD=your_pass
  static const String _kBaseUrl = String.fromEnvironment('IPTV_BASE_URL');
  static const String _kUsername = String.fromEnvironment('IPTV_USERNAME');
  static const String _kPassword = String.fromEnvironment('IPTV_PASSWORD');

  static IptvConfig get defaultProvider => const IptvConfig(
        username: _kUsername,
        password: _kPassword,
        baseUrl: _kBaseUrl,
      );

  /// True when all required credentials have been supplied via --dart-define.
  bool get isConfigured =>
      username.isNotEmpty && password.isNotEmpty && baseUrl.isNotEmpty;

  /// Throws a clear [StateError] when credentials are missing, so
  /// developers get an actionable message instead of a silent network failure.
  void ensureConfigured() {
    if (!isConfigured) {
      throw StateError(
        'IPTV credentials are not configured.\n'
        'Supply them at build time:\n'
        '  --dart-define=IPTV_BASE_URL=<url>\n'
        '  --dart-define=IPTV_USERNAME=<user>\n'
        '  --dart-define=IPTV_PASSWORD=<pass>',
      );
    }
  }

  // —— Xtream Codes API endpoints ———————————————————————————————————

  String get _authParams => 'username=$username&password=$password';

  String get playerApiBase => '$baseUrl/player_api.php?$_authParams';

  Uri get authUrl => Uri.parse('$playerApiBase&action=get_server_info');

  // —— Live TV ——————————————————————————————————————————————————————

  Uri get liveCategoriesUrl =>
      Uri.parse('$playerApiBase&action=get_live_categories');

  Uri liveStreamsUrl({String? categoryId}) {
    final base = '$playerApiBase&action=get_live_streams';
    if (categoryId != null && categoryId != '0') {
      return Uri.parse('$base&category_id=$categoryId');
    }
    return Uri.parse(base);
  }

  /// Live stream playback URL. Credentials appear in the URL per the
  /// Xtream Codes protocol; never log this URL directly.
  String livePlaybackUrl(String streamId, {String? extension}) {
    if (extension != null && extension.isNotEmpty) {
      return '$baseUrl/$username/$password/$streamId.$extension';
    }
    return '$baseUrl/$username/$password/$streamId';
  }

  // —— Movies / VOD —————————————————————————————————————————————————

  Uri get vodCategoriesUrl =>
      Uri.parse('$playerApiBase&action=get_vod_categories');

  Uri vodStreamsUrl({String? categoryId}) {
    final base = '$playerApiBase&action=get_vod_streams';
    if (categoryId != null && categoryId != '0') {
      return Uri.parse('$base&category_id=$categoryId');
    }
    return Uri.parse(base);
  }

  String vodPlaybackUrl(String streamId, String containerExtension) {
    if (containerExtension.isEmpty) {
      return '$baseUrl/movie/$username/$password/$streamId';
    }
    return '$baseUrl/movie/$username/$password/$streamId.$containerExtension';
  }

  // —— Series ———————————————————————————————————————————————————————

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

  String episodePlaybackUrl(String streamId, String containerExtension) =>
      '$baseUrl/series/$username/$password/$streamId.$containerExtension';
}
