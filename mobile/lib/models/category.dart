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

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] ?? 0,
      name: map['name'] ?? '',
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
