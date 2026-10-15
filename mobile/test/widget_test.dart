import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:restaurant_pos_app/main.dart';
import 'package:restaurant_pos_app/models/category.dart';
import 'package:restaurant_pos_app/repositories/table_repository.dart';
import 'package:restaurant_pos_app/utils/database_helper.dart';

class WidgetTestFakeDatabase implements Database {
  final Map<String, List<Map<String, dynamic>>> _tables = {
    'user_session': [],
    'cart_items': [],
    'offline_orders': [],
  };

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    return _tables[table] ?? [];
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(String sql, [List<Object?>? arguments]) async {
    return [
      {'count': 0, 'total': 0}
    ];
  }
}

void main() {
  setUpAll(() {
    TableRepository.timeoutDuration = const Duration(milliseconds: 50);
  });

  setUp(() {
    DatabaseHelper.setDatabaseForTesting(WidgetTestFakeDatabase());
  });

  tearDown(() {
    DatabaseHelper.setDatabaseForTesting(null);
  });

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

  testWidgets('RestaurantPosApp renders with NavigationBar and Tabs', (tester) async {
    await tester.pumpWidget(const RestaurantPosApp());
    await tester.pumpAndSettle();

    // Verify AppBar title of initial floor plan page
    expect(find.text('Sơ đồ Bàn ăn (Floor Plan)'), findsOneWidget);

    // Verify NavigationBar destinations
    expect(find.text('Sơ đồ bàn'), findsOneWidget);
    expect(find.text('Thực đơn'), findsOneWidget);
    expect(find.text('Đồng bộ đơn'), findsOneWidget);

    // Switch to Thực đơn tab
    await tester.tap(find.text('Thực đơn'));
    await tester.pumpAndSettle();

    // Verify Category page is loaded
    expect(find.text('Thực đơn & Danh mục'), findsOneWidget);

    // Switch to Đồng bộ đơn tab
    await tester.tap(find.text('Đồng bộ đơn'));
    await tester.pumpAndSettle();

    // Verify OrdersSyncPage is loaded
    expect(find.text('Đơn hàng & Đồng bộ ngoại tuyến'), findsOneWidget);
    expect(find.text('Trạng thái đồng bộ hàng đợi SQLite'), findsOneWidget);
  });
}
