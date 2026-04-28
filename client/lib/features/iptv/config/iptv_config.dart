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

  Map<String, String> get _baseParams => {
        'username': username,
        'password': password,
      };

  Uri _buildApiUri(Map<String, String> actionParams) {
    final uri = Uri.parse(baseUrl);
    return uri.replace(
      path: '${uri.path}/player_api.php'.replaceAll('//', '/'),
      queryParameters: {
        ..._baseParams,
        ...actionParams,
      },
    );
  }

  Uri get authUrl => _buildApiUri({'action': 'get_server_info'});

  Uri get liveCategoriesUrl => _buildApiUri({'action': 'get_live_categories'});

  Uri liveStreamsUrl({String? categoryId}) {
    final params = {'action': 'get_live_streams'};
    if (categoryId != null && categoryId != '0') {
      params['category_id'] = categoryId;
    }
    return _buildApiUri(params);
  }

  String livePlaybackUrl(String streamId, {String? extension}) {
    final uri = Uri.parse(baseUrl);
    final fileName =
        (extension != null && extension.isNotEmpty) ? '$streamId.$extension' : streamId;

    return uri
        .replace(
          path: '${uri.path}/$username/$password/$fileName'.replaceAll('//', '/'),
        )
        .toString();
  }

  Uri get vodCategoriesUrl => _buildApiUri({'action': 'get_vod_categories'});

  Uri vodStreamsUrl({String? categoryId}) {
    final params = {'action': 'get_vod_streams'};
    if (categoryId != null && categoryId != '0') {
      params['category_id'] = categoryId;
    }
    return _buildApiUri(params);
  }

  String vodPlaybackUrl(String streamId, String containerExtension) {
    final uri = Uri.parse(baseUrl);
    final fileName = containerExtension.isNotEmpty
        ? '$streamId.$containerExtension'
        : streamId;

    return uri
        .replace(
          path: '${uri.path}/movie/$username/$password/$fileName'
              .replaceAll('//', '/'),
        )
        .toString();
  }

  Uri get seriesCategoriesUrl =>
      _buildApiUri({'action': 'get_series_categories'});

  Uri seriesListUrl({String? categoryId}) {
    final params = {'action': 'get_series'};
    if (categoryId != null && categoryId != '0') {
      params['category_id'] = categoryId;
    }
    return _buildApiUri(params);
  }

  Uri seriesInfoUrl(String seriesId) => _buildApiUri({
        'action': 'get_series_info',
        'series_id': seriesId,
      });

  String episodePlaybackUrl(String streamId, String containerExtension) {
    final uri = Uri.parse(baseUrl);
    final fileName = containerExtension.isNotEmpty
        ? '$streamId.$containerExtension'
        : streamId;

    return uri
        .replace(
          path: '${uri.path}/series/$username/$password/$fileName'
              .replaceAll('//', '/'),
        )
        .toString();
  }
}
