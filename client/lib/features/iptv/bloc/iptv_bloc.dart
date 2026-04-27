import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/protocol/payloads.dart';
import '../models/iptv_category.dart';
import '../repository/iptv_repository.dart';
import '../service/iptv_api_service.dart';
import 'iptv_event.dart';
import 'iptv_state.dart';


class IptvBloc extends Bloc<IptvEvent, IptvState> {
  final IptvRepository _repository;
  final AppLogger _logger;

  IptvBloc({required IptvRepository repository, AppLogger? logger})
      : _repository = repository,
        _logger = logger ?? AppLogger('IptvBloc'),
        super(const IptvInitial()) {
    on<IptvLoadCategories>(_onLoadCategories);
    on<IptvLoadCategoryContent>(_onLoadCategoryContent);
    on<IptvLoadSeriesInfo>(_onLoadSeriesInfo);
    on<IptvSelectContent>(_onSelectContent);
    on<IptvSelectEpisode>(_onSelectEpisode);
    on<IptvReset>(_onReset);
  }

  Future<void> _onLoadCategories(
    IptvLoadCategories event,
    Emitter<IptvState> emit,
  ) async {
    if (state is IptvCategoriesLoaded) {
      final current = state as IptvCategoriesLoaded;
      if (current.contentType == event.contentType) {
        return; 
      }
    }

    _logger.i('[PROFILER] iptv_categories_load_start');
    final startTime = DateTime.now();

    emit(
      IptvLoading(message: 'Loading ${event.contentType.name} categories...'),
    );
    try {
      final categories = await _repository.getCategories(event.contentType);
      emit(
        IptvCategoriesLoaded(
          contentType: event.contentType,
          categories: categories,
        ),
      );
    } on IptvApiException catch (e) {
      _logger.e('Load categories failed: $e');
      emit(IptvError(e.message));
    } finally {
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      _logger.i('[PROFILER] iptv_categories_load_end: ${elapsed}ms');
    }
  }

  Future<void> _onLoadCategoryContent(
    IptvLoadCategoryContent event,
    Emitter<IptvState> emit,
  ) async {
    emit(IptvLoading(message: 'Loading ${event.categoryName}...'));
    try {
      switch (event.contentType) {
        case IptvContentType.live:
          final streams = await _repository.getLiveStreams(event.categoryId);
          emit(
            IptvLiveStreamsLoaded(
              categoryName: event.categoryName,
              streams: streams,
            ),
          );
        case IptvContentType.movie:
          final streams = await _repository.getVodStreams(event.categoryId);
          emit(
            IptvVodStreamsLoaded(
              categoryName: event.categoryName,
              streams: streams,
            ),
          );
        case IptvContentType.series:
          final series = await _repository.getSeriesList(event.categoryId);
          emit(
            IptvSeriesListLoaded(
              categoryName: event.categoryName,
              seriesList: series,
            ),
          );
      }
    } on IptvApiException catch (e) {
      _logger.e('Load category content failed: $e');
      emit(IptvError(e.message));
    }
  }

  Future<void> _onLoadSeriesInfo(
    IptvLoadSeriesInfo event,
    Emitter<IptvState> emit,
  ) async {
    emit(IptvLoading(message: 'Loading ${event.seriesName}...'));
    try {
      final info = await _repository.getSeriesInfo(event.seriesId.toString());
      emit(IptvSeriesInfoLoaded(seriesName: event.seriesName, info: info));
    } on IptvApiException catch (e) {
      _logger.e('Load series info failed: $e');
      emit(IptvError(e.message));
    }
  }

  void _onSelectContent(IptvSelectContent event, Emitter<IptvState> emit) {
    if (event.contentType == IptvContentType.series) {
      emit(const IptvError('Cannot play series directly, select an episode'));
      return;
    }

    final descriptor = IptvContentDescriptor(
      contentType: switch (event.contentType) {
        IptvContentType.live => IptvDescriptorType.live,
        IptvContentType.movie => IptvDescriptorType.movie,
        IptvContentType.series => IptvDescriptorType.live, 
      },
      streamId: event.streamId.toString(),
      containerExtension: event.containerExtension,
      title: event.title,
    );

    _logger.d(
      'Selected content: ${event.title} [${event.contentType.name}:${event.streamId}]',
    );
    emit(IptvContentSelected(descriptor: descriptor, title: event.title));
  }

  void _onSelectEpisode(IptvSelectEpisode event, Emitter<IptvState> emit) {
    final descriptor = IptvContentDescriptor(
      contentType: IptvDescriptorType.episode,
      streamId: event.episodeId,
      containerExtension: event.containerExtension,
      title: event.title,
    );
    _logger.d('Selected episode: ${event.title} [${event.episodeId}]');
    emit(IptvContentSelected(descriptor: descriptor, title: event.title));
  }

  void _onReset(IptvReset event, Emitter<IptvState> emit) {
    emit(const IptvInitial());
  }
}
