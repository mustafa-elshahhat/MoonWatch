class IptvConfig {
  final String username;
  final String password;
  final String baseUrl;

  const IptvConfig({
    required this.username,
    required this.password,
    required this.baseUrl,
  });

  static const String _kBaseUrl = String.fromEnvironment('IPTV_BASE_URL');
  static const String _kUsername = String.fromEnvironment('IPTV_USERNAME');
  static const String _kPassword = String.fromEnvironment('IPTV_PASSWORD');

  static IptvConfig get defaultProvider => const IptvConfig(
        username: _kUsername,
        password: _kPassword,
        baseUrl: _kBaseUrl,
      );

  bool get isConfigured =>
      username.isNotEmpty && password.isNotEmpty && baseUrl.isNotEmpty;

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

  String get _authParams => 'username=$username&password=$password';

  String get playerApiBase => '$baseUrl/player_api.php?$_authParams';

  Uri get authUrl => Uri.parse('$playerApiBase&action=get_server_info');

  Uri get liveCategoriesUrl =>
      Uri.parse('$playerApiBase&action=get_live_categories');

  Uri liveStreamsUrl({String? categoryId}) {
    final base = '$playerApiBase&action=get_live_streams';
    if (categoryId != null && categoryId != '0') {
      return Uri.parse('$base&category_id=$categoryId');
    }
    return Uri.parse(base);
  }

  String livePlaybackUrl(String streamId, {String? extension}) {
    if (extension != null && extension.isNotEmpty) {
      return '$baseUrl/$username/$password/$streamId.$extension';
    }
    return '$baseUrl/$username/$password/$streamId';
  }

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
