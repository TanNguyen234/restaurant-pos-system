import '../config/api_config.dart';

class Category {
  final int id;
  final String name;
  final String title;
  final String description;
  final String icon;
  final int sortOrder;
  final bool isActive;

  Category({
    required this.id,
    required this.name,
    required this.title,
    required this.description,
    required this.icon,
    this.sortOrder = 0,
    this.isActive = true,
  });

  String get fullIconUrl {
    if (icon.isEmpty) return '';
    if (icon.startsWith('http://') || icon.startsWith('https://')) return icon;
    final base = ApiConfig.baseUrl.replaceAll('/api', '');
    return '$base/images/categories/$icon';
  }

  static bool _parseBool(dynamic v, {bool fallback = true}) {
    if (v == null) return fallback;
    if (v is bool) return v;
    if (v is num) return v != 0;
    return v.toString().toLowerCase() == 'true' || v.toString() == '1';
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: (map['id'] ?? map['categoryId'] ?? 0) as int,
      name: (map['name'] ?? map['categoryName'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      icon: (map['icon'] ?? '').toString(),
      sortOrder: ((map['sortOrder'] ?? map['sort_order']) as num? ?? 0).toInt(),
      isActive: _parseBool(map['isActive'] ?? map['is_active'], fallback: true),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'title': title,
      'description': description,
      'icon': icon,
      'sortOrder': sortOrder,
      'isActive': isActive,
    };
  }
}
