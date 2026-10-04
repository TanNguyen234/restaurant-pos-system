import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_pos_app/models/category.dart';

void main() {
  test('Category model fromMap and toMap serialization test', () {
    final map = {
      'id': 1,
      'name': 'Cà phê',
      'title': 'Cà phê nguyên chất',
      'description': 'Đậm đà hương vị truyền thống',
      'icon': 'coffee.png',
      'sortOrder': 1,
      'isActive': true,
    };

    final category = Category.fromMap(map);

    expect(category.id, 1);
    expect(category.name, 'Cà phê');
    expect(category.title, 'Cà phê nguyên chất');
    expect(category.icon, 'coffee.png');

    final backToMap = category.toMap();
    expect(backToMap['id'], 1);
    expect(backToMap['name'], 'Cà phê');
  });
}
