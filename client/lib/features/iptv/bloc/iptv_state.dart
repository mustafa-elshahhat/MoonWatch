import 'package:equatable/equatable.dart';
import '../../../core/protocol/payloads.dart';
import '../models/iptv_category.dart';
import '../models/live_stream.dart';
import '../models/vod_stream.dart';
import '../models/series_item.dart';

sealed class IptvState extends Equatable {
  const IptvState();

  @override
  List<Object?> get props => [];
}

/// Initial / idle state.
class IptvInitial extends IptvState {
  const IptvInitial();
}

/// Loading categories or content.
class IptvLoading extends IptvState {
  final String? message;
  const IptvLoading({this.message});

  @override
  List<Object?> get props => [message];
}

/// Categories loaded for a content type.
class IptvCategoriesLoaded extends IptvState {
  final IptvContentType contentType;
  final List<IptvCategory> categories;

  const IptvCategoriesLoaded({
    required this.contentType,
    required this.categories,
  });

  @override
  List<Object?> get props => [contentType, categories];
}

/// Live streams loaded for a category.
class IptvLiveStreamsLoaded extends IptvState {
  final String categoryName;
  final List<LiveStream> streams;

  const IptvLiveStreamsLoaded({
    required this.categoryName,
    required this.streams,
  });

  @override
  List<Object?> get props => [categoryName, streams];
}

/// VOD streams loaded for a category.
class IptvVodStreamsLoaded extends IptvState {
  final String categoryName;
  final List<VodStream> streams;

  const IptvVodStreamsLoaded({
    required this.categoryName,
    required this.streams,
  });

  @override
  List<Object?> get props => [categoryName, streams];
}

/// Series list loaded for a category.
class IptvSeriesListLoaded extends IptvState {
  final String categoryName;
  final List<SeriesItem> seriesList;

  const IptvSeriesListLoaded({
    required this.categoryName,
    required this.seriesList,
  });

  @override
  List<Object?> get props => [categoryName, seriesList];
}

/// Series detail loaded (seasons + episodes).
class IptvSeriesInfoLoaded extends IptvState {
  final String seriesName;
  final SeriesInfo info;

  const IptvSeriesInfoLoaded({required this.seriesName, required this.info});

  @override
  List<Object?> get props => [seriesName, info];
}

/// Content selected — descriptor ready for room broadcast or local resolve.
class IptvContentSelected extends IptvState {
  final IptvContentDescriptor descriptor;
  final String title;

  const IptvContentSelected({required this.descriptor, required this.title});

  @override
  List<Object?> get props => [descriptor, title];
}

/// Error state.
class IptvError extends IptvState {
  final String message;

  const IptvError(this.message);

  @override
  List<Object?> get props => [message];
}
