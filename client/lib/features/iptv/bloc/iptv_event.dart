import 'package:equatable/equatable.dart';
import '../../iptv/models/iptv_category.dart';

sealed class IptvEvent extends Equatable {
  const IptvEvent();

  @override
  List<Object?> get props => [];
}

class IptvLoadCategories extends IptvEvent {
  final IptvContentType contentType;
  const IptvLoadCategories(this.contentType);

  @override
  List<Object?> get props => [contentType];
}

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

class IptvLoadSeriesInfo extends IptvEvent {
  final int seriesId;
  final String seriesName;

  const IptvLoadSeriesInfo({required this.seriesId, required this.seriesName});

  @override
  List<Object?> get props => [seriesId, seriesName];
}

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

class IptvReset extends IptvEvent {
  const IptvReset();
}
