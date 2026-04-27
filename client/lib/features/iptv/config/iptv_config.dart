class IptvConfig {
  final String username;
  final String password;
  final String baseUrl;

  const IptvConfig({
    required this.username,
    required this.password,
    required this.baseUrl,
  });

  bool get isConfigured =>
      username.isNotEmpty && password.isNotEmpty && baseUrl.isNotEmpty;

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
