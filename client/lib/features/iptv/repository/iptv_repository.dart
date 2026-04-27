import '../../../core/logging/app_logger.dart';
import '../../../core/protocol/payloads.dart';
import '../config/iptv_config.dart';
import '../models/iptv_category.dart';
import '../models/live_stream.dart';
import '../models/vod_stream.dart';
import '../models/series_item.dart';
import '../service/iptv_api_service.dart';



class IptvRepository {
  final IptvApiService _apiService;
  final AppLogger _logger;

  
  final Map<IptvContentType, List<IptvCategory>> _categoryCache = {};
  final Map<String, List<LiveStream>> _liveStreamsCache = {};
  final Map<String, List<VodStream>> _vodStreamsCache = {};
  final Map<String, List<SeriesItem>> _seriesListCache = {};
  final Map<String, SeriesInfo> _seriesInfoCache = {};

  IptvRepository({required IptvApiService apiService, AppLogger? logger})
      : _apiService = apiService,
        _logger = logger ?? AppLogger('IptvRepository');

  IptvConfig get config => _apiService.config;

  void clearCache() {
    _categoryCache.clear();
    _liveStreamsCache.clear();
    _vodStreamsCache.clear();
    _seriesListCache.clear();
    _seriesInfoCache.clear();
  }

  

  Future<List<IptvCategory>> getCategories(
    IptvContentType type, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _categoryCache.containsKey(type)) {
      return _categoryCache[type]!;
    }

    try {
      final categories = switch (type) {
        IptvContentType.live => await _apiService.getLiveCategories(),
        IptvContentType.movie => await _apiService.getVodCategories(),
        IptvContentType.series => await _apiService.getSeriesCategories(),
      };
      _categoryCache[type] = categories;
      _logger.d('Loaded ${categories.length} ${type.name} categories');
      return categories;
    } on IptvApiException catch (e) {
      _logger.e('Failed to load ${type.name} categories: $e');
      rethrow;
    }
  }

  

  Future<List<LiveStream>> getLiveStreams(
    String categoryId, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _liveStreamsCache.containsKey(categoryId)) {
      return _liveStreamsCache[categoryId]!;
    }

    try {
      final streams = await _apiService.getLiveStreams(categoryId: categoryId);
      _liveStreamsCache[categoryId] = streams;
      _logger.d(
        'Loaded ${streams.length} live streams for category $categoryId',
      );
      return streams;
    } on IptvApiException catch (e) {
      _logger.e('Failed to load live streams: $e');
      rethrow;
    }
  }

  

  Future<List<VodStream>> getVodStreams(
    String categoryId, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _vodStreamsCache.containsKey(categoryId)) {
      return _vodStreamsCache[categoryId]!;
    }

    try {
      final streams = await _apiService.getVodStreams(categoryId: categoryId);
      _vodStreamsCache[categoryId] = streams;
      _logger.d(
        'Loaded ${streams.length} VOD streams for category $categoryId',
      );
      return streams;
    } on IptvApiException catch (e) {
      _logger.e('Failed to load VOD streams: $e');
      rethrow;
    }
  }

  

  Future<List<SeriesItem>> getSeriesList(
    String categoryId, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _seriesListCache.containsKey(categoryId)) {
      return _seriesListCache[categoryId]!;
    }

    try {
      final series = await _apiService.getSeriesList(categoryId: categoryId);
      _seriesListCache[categoryId] = series;
      _logger.d('Loaded ${series.length} series for category $categoryId');
      return series;
    } on IptvApiException catch (e) {
      _logger.e('Failed to load series list: $e');
      rethrow;
    }
  }

  Future<SeriesInfo> getSeriesInfo(
    String seriesId, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _seriesInfoCache.containsKey(seriesId)) {
      return _seriesInfoCache[seriesId]!;
    }

    try {
      final json = await _apiService.getSeriesInfo(seriesId);
      final info = SeriesInfo.fromJson(json);
      _seriesInfoCache[seriesId] = info;
      _logger.d('Loaded series info for $seriesId: ${info.name}');
      return info;
    } on IptvApiException catch (e) {
      _logger.e('Failed to load series info: $e');
      rethrow;
    }
  }

  

  String getLivePlaybackUrl(int streamId) =>
      config.livePlaybackUrl(streamId.toString());

  String getVodPlaybackUrl(int streamId, String containerExtension) {
    final url = config.vodPlaybackUrl(streamId.toString(), containerExtension);
    final strategy = containerExtension.toLowerCase() == 'm3u8'
        ? 'HLS Playlist'
        : 'Direct File';
    _logger.i(
      'VOD URL: content=movie, stream_id=$streamId, '
      'ext=$containerExtension, strategy=$strategy, '
      'url=${AppLogger.sanitizeUrl(url)}',
    );
    return url;
  }

  String getEpisodePlaybackUrl(String episodeId, String containerExtension) {
    final url = config.episodePlaybackUrl(episodeId, containerExtension);
    final strategy = containerExtension.toLowerCase() == 'm3u8'
        ? 'HLS Playlist'
        : 'Direct File';
    _logger.i(
      'VOD URL: content=episode, episode_id=$episodeId, '
      'ext=$containerExtension, strategy=$strategy, '
      'url=${AppLogger.sanitizeUrl(url)}',
    );
    return url;
  }

  
  
  String resolvePlaybackUrl(IptvContentDescriptor descriptor) {
    final String url = switch (descriptor.contentType) {
      IptvDescriptorType.live => config.livePlaybackUrl(descriptor.streamId),
      IptvDescriptorType.movie => config.vodPlaybackUrl(
          descriptor.streamId,
          descriptor.containerExtension ?? 'mp4',
        ),
      IptvDescriptorType.episode => config.episodePlaybackUrl(
          descriptor.streamId,
          descriptor.containerExtension ?? 'mp4',
        ),
    };

    final strategy =
        url.endsWith('.m3u8') ? 'HLS Playlist' : 'Direct File / Stream';
    _logger.i(
      'VOD Strategy: content_type=${descriptor.contentType.name}, '
      'extension=${descriptor.containerExtension ?? "mp4 (default)"}, '
      'playback=$strategy, '
      'url=${AppLogger.sanitizeUrl(url)}',
    );
    return url;
  }
}
