import 'package:equatable/equatable.dart';


class SeriesItem extends Equatable {
  final int seriesId;
  final String name;
  final String? cover;
  final String categoryId;
  final String? plot;
  final String? cast;
  final String? genre;
  final double? rating;
  final String? releaseDate;
  final String? lastModified;

  const SeriesItem({
    required this.seriesId,
    required this.name,
    this.cover,
    required this.categoryId,
    this.plot,
    this.cast,
    this.genre,
    this.rating,
    this.releaseDate,
    this.lastModified,
  });

  factory SeriesItem.fromJson(Map<String, dynamic> json) {
    return SeriesItem(
      seriesId: _parseInt(json['series_id']),
      name: json['name']?.toString() ?? 'Unknown Series',
      cover: json['cover']?.toString(),
      categoryId: json['category_id']?.toString() ?? '',
      plot: json['plot']?.toString(),
      cast: json['cast']?.toString(),
      genre: json['genre']?.toString(),
      rating: double.tryParse(json['rating']?.toString() ?? ''),
      releaseDate: json['releaseDate']?.toString(),
      lastModified: json['last_modified']?.toString(),
    );
  }

  @override
  List<Object?> get props => [seriesId, name, categoryId];
}


class SeriesInfo extends Equatable {
  final Map<String, dynamic> info;
  final Map<String, List<SeriesEpisode>> seasons;

  const SeriesInfo({required this.info, required this.seasons});

  String get name => info['name']?.toString() ?? 'Unknown Series';
  String? get cover => info['cover']?.toString();
  String? get plot => info['plot']?.toString();
  String? get cast => info['cast']?.toString();
  String? get genre => info['genre']?.toString();
  double? get rating => double.tryParse(info['rating']?.toString() ?? '');

  List<String> get seasonNumbers {
    final keys = seasons.keys.toList();
    keys.sort((a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0));
    return keys;
  }

  factory SeriesInfo.fromJson(Map<String, dynamic> json) {
    final infoMap = json['info'] as Map<String, dynamic>? ?? {};
    final episodesMap = json['episodes'] as Map<String, dynamic>? ?? {};

    final seasons = <String, List<SeriesEpisode>>{};
    for (final entry in episodesMap.entries) {
      final seasonNum = entry.key;
      final episodeList = entry.value;
      if (episodeList is List) {
        seasons[seasonNum] = episodeList
            .whereType<Map<String, dynamic>>()
            .map((e) => SeriesEpisode.fromJson(e))
            .toList();
      }
    }

    return SeriesInfo(info: infoMap, seasons: seasons);
  }

  @override
  List<Object?> get props => [info, seasons];
}


class SeriesEpisode extends Equatable {
  final String id;
  final int episodeNum;
  final String title;
  final String containerExtension;
  final String? plot;
  final String? duration;
  final double? rating;
  final String? coverBig;

  const SeriesEpisode({
    required this.id,
    required this.episodeNum,
    required this.title,
    required this.containerExtension,
    this.plot,
    this.duration,
    this.rating,
    this.coverBig,
  });

  factory SeriesEpisode.fromJson(Map<String, dynamic> json) {
    return SeriesEpisode(
      id: json['id']?.toString() ?? '',
      episodeNum: _parseInt(json['episode_num']),
      title: json['title']?.toString() ?? 'Episode',
      containerExtension: json['container_extension']?.toString() ?? 'mp4',
      plot: json['plot']?.toString(),
      duration: json['duration']?.toString(),
      rating: double.tryParse(json['rating']?.toString() ?? ''),
      coverBig: json['info']?['movie_image']?.toString() ??
          json['info']?['cover_big']?.toString(),
    );
  }

  @override
  List<Object?> get props => [id, episodeNum, title];
}

int _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
