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
    return 'http://localhost:5138/images/categories/$icon';
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] ?? map['categoryId'] ?? 0,
      name: map['name'] ?? map['categoryName'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      icon: map['icon'] ?? '',
      sortOrder: map['sortOrder'] ?? 0,
      isActive: map['isActive'] ?? true,
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
