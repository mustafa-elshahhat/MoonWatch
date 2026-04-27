import 'package:equatable/equatable.dart';

class LiveStream extends Equatable {
  final int streamId;
  final String name;
  final String? streamIcon;
  final String? epgChannelId;
  final String categoryId;
  final int? containerExtensionCode;

  const LiveStream({
    required this.streamId,
    required this.name,
    this.streamIcon,
    this.epgChannelId,
    required this.categoryId,
    this.containerExtensionCode,
  });

  factory LiveStream.fromJson(Map<String, dynamic> json) {
    return LiveStream(
      streamId: _parseInt(json['stream_id']),
      name: json['name']?.toString() ?? 'Unknown Channel',
      streamIcon: json['stream_icon']?.toString(),
      epgChannelId: json['epg_channel_id']?.toString(),
      categoryId: json['category_id']?.toString() ?? '',
      containerExtensionCode: int.tryParse(
        json['container_extension']?.toString() ?? '',
      ),
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
