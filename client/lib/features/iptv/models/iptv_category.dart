import 'package:equatable/equatable.dart';

/// Shared category model used across Live, VOD, and Series.
class IptvCategory extends Equatable {
  final String categoryId;
  final String categoryName;
  final int? parentId;

  const IptvCategory({
    required this.categoryId,
    required this.categoryName,
    this.parentId,
  });

  factory IptvCategory.fromJson(Map<String, dynamic> json) {
    return IptvCategory(
      categoryId: json['category_id']?.toString() ?? '',
      categoryName: json['category_name']?.toString() ?? 'Unknown',
      parentId: int.tryParse(json['parent_id']?.toString() ?? ''),
    );
  }

  @override
  List<Object?> get props => [categoryId, categoryName, parentId];
}

// —— Content type enum ——————————————————————————————————————————————

enum IptvContentType { live, movie, series }
