import 'package:equatable/equatable.dart';

/// A VOD / movie item from the IPTV provider.
class VodStream extends Equatable {
  final int streamId;
  final String name;
  final String? streamIcon;
  final String categoryId;
  final String containerExtension;
  final double? rating;
  final String? plot;
  final String? cast;
  final String? genre;
  final String? releaseDate;

  const VodStream({
    required this.streamId,
    required this.name,
    this.streamIcon,
    required this.categoryId,
    required this.containerExtension,
    this.rating,
    this.plot,
    this.cast,
    this.genre,
    this.releaseDate,
  });

  factory VodStream.fromJson(Map<String, dynamic> json) {
    return VodStream(
      streamId: _parseInt(json['stream_id']),
      name: json['name']?.toString() ?? 'Unknown Movie',
      streamIcon: json['stream_icon']?.toString(),
      categoryId: json['category_id']?.toString() ?? '',
      containerExtension: json['container_extension']?.toString() ?? 'mp4',
      rating: double.tryParse(json['rating']?.toString() ?? ''),
      plot: json['plot']?.toString(),
      cast: json['cast']?.toString(),
      genre: json['genre']?.toString(),
      releaseDate: json['releasedate']?.toString(),
    );
  }

  @override
  List<Object?> get props => [streamId, name, categoryId];
}

int _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
