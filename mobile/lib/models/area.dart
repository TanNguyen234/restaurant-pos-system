class Area {
  final int id;
  final String name;
  final String? description;
  final int sortOrder;
  final bool isActive;

  Area({
    required this.id,
    required this.name,
    this.description,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory Area.fromMap(Map<String, dynamic> map) {
    return Area(
      id: map['areaId'] ?? map['id'] ?? 0,
      name: map['areaName'] ?? map['name'] ?? '',
      description: map['description'],
      sortOrder: map['sortOrder'] ?? 0,
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'areaId': id,
      'areaName': name,
      'description': description,
      'sortOrder': sortOrder,
      'isActive': isActive,
    };
  }

  @override
  String toString() => 'Area(id: $id, name: $name, sortOrder: $sortOrder, isActive: $isActive)';
}
