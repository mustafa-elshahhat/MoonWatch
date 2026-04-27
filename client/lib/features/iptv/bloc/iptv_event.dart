import 'package:equatable/equatable.dart';
import '../../iptv/models/iptv_category.dart';

sealed class IptvEvent extends Equatable {
  const IptvEvent();

  @override
  List<Object?> get props => [];
}

/// Load categories for a content type tab.
class IptvLoadCategories extends IptvEvent {
  final IptvContentType contentType;
  const IptvLoadCategories(this.contentType);

  @override
  List<Object?> get props => [contentType];
}

/// Load streams/items for a specific category.
class IptvLoadCategoryContent extends IptvEvent {
  final IptvContentType contentType;
  final String categoryId;
  final String categoryName;

  const IptvLoadCategoryContent({
    required this.contentType,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  List<Object?> get props => [contentType, categoryId, categoryName];
}

/// Load detailed info for a series (seasons + episodes).
class IptvLoadSeriesInfo extends IptvEvent {
  final int seriesId;
  final String seriesName;

  const IptvLoadSeriesInfo({required this.seriesId, required this.seriesName});

  @override
  List<Object?> get props => [seriesId, seriesName];
}

/// User selected content to play — resolve playback URL.
class IptvSelectContent extends IptvEvent {
  final IptvContentType contentType;
  final int streamId;
  final String? containerExtension;
  final String title;

  const IptvSelectContent({
    required this.contentType,
    required this.streamId,
    this.containerExtension,
    required this.title,
  });

  @override
  List<Object?> get props => [contentType, streamId, title];
}

/// User selected an episode to play.
class IptvSelectEpisode extends IptvEvent {
  final String episodeId;
  final String containerExtension;
  final String title;

  const IptvSelectEpisode({
    required this.episodeId,
    required this.containerExtension,
    required this.title,
  });

  @override
  List<Object?> get props => [episodeId, title];
}

/// Reset to initial state (e.g. navigate back to browse root).
class IptvReset extends IptvEvent {
  const IptvReset();
}
