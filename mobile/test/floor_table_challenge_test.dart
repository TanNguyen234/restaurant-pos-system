import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:restaurant_pos_app/repositories/table_repository.dart';
import 'package:restaurant_pos_app/utils/database_helper.dart';
import 'package:restaurant_pos_app/views/table/floor_table_page.dart';

/// Fake SQLite Database for widget testing
class ChallengeFakeDatabase implements Database {
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
    return [];
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(String sql, [List<Object?>? arguments]) async {
    return [{'count': 0, 'total': 0}];
  }
}

/// Custom HttpOverrides to inject controlled API responses during widget tests
class ChallengeHttpOverrides extends HttpOverrides {
  final String Function(Uri uri, String method)? handler;
  final bool simulateOffline;

  ChallengeHttpOverrides({this.handler, this.simulateOffline = false});

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return ChallengeFakeHttpClient(handler: handler, simulateOffline: simulateOffline);
  }
}

class ChallengeFakeHttpClient extends Fake implements HttpClient {
  final String Function(Uri uri, String method)? handler;
  final bool simulateOffline;

  ChallengeFakeHttpClient({this.handler, this.simulateOffline = false});

  @override
  bool autoUncompress = true;
  @override
  Duration? connectionTimeout;
  @override
  Duration idleTimeout = const Duration(seconds: 15);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    if (simulateOffline) {
      throw const SocketException('Simulated Network Unreachable');
    }
    final responseBody = handler != null ? handler!(url, method) : '{}';
    return ChallengeFakeHttpClientRequest(responseBody);
  }

  @override
  void close({bool force = false}) {}

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);
  @override
  Future<HttpClientRequest> postUrl(Uri url) => openUrl('POST', url);
  @override
  Future<HttpClientRequest> putUrl(Uri url) => openUrl('PUT', url);
}

class ChallengeFakeHttpClientRequest extends Fake implements HttpClientRequest {
  final String responseBody;
  ChallengeFakeHttpClientRequest(this.responseBody);

  @override
  bool followRedirects = true;

  @override
  int maxRedirects = 5;

  @override
  int contentLength = -1;

  @override
  bool persistentConnection = false;

  @override
  final HttpHeaders headers = ChallengeFakeHttpHeaders();

  @override
  void write(Object? obj) {}

  @override
  void add(List<int> data) {}

  @override
  Future addStream(Stream<List<int>> stream) async {}

  @override
  Future<HttpClientResponse> close() async {
    return ChallengeFakeHttpClientResponse(responseBody);
  }
}

class ChallengeFakeHttpHeaders extends Fake implements HttpHeaders {
  final Map<String, List<String>> _headers = {
    'content-type': ['application/json; charset=utf-8'],
  };

  @override
  void forEach(void Function(String name, List<String> values) action) {
    _headers.forEach(action);
  }

  @override
  List<String>? operator [](String name) => _headers[name.toLowerCase()];

  @override
  String? value(String name) => _headers[name.toLowerCase()]?.first;

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _headers[name.toLowerCase()] = [value.toString()];
  }

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    _headers.putIfAbsent(name.toLowerCase(), () => []).add(value.toString());
  }
}

class ChallengeFakeHttpClientResponse extends Fake implements HttpClientResponse {
  final String responseBody;
  ChallengeFakeHttpClientResponse(this.responseBody);

  @override
  int get statusCode => 200;

  @override
  String get reasonPhrase => 'OK';

  @override
  bool get isRedirect => false;

  @override
  bool get persistentConnection => false;

  @override
  List<RedirectInfo> get redirects => const [];

  @override
  int get contentLength => utf8.encode(responseBody).length;

  @override
  final HttpHeaders headers = ChallengeFakeHttpHeaders();

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(utf8.encode(responseBody)).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

void main() {
  setUp(() {
    DatabaseHelper.setDatabaseForTesting(ChallengeFakeDatabase());
    TableRepository.timeoutDuration = const Duration(milliseconds: 200);
  });

  tearDown(() {
    DatabaseHelper.setDatabaseForTesting(null);
    HttpOverrides.global = null;
  });

  group('Challenge Task 1.1: Area with Zero Tables Handling', () {
    testWidgets('Displays empty state without crashing when an area has zero tables', (tester) async {
      HttpOverrides.global = ChallengeHttpOverrides(
        handler: (uri, method) {
          if (uri.path.contains('/areas')) {
            return jsonEncode([
              {'areaId': 10, 'areaName': 'Khu Sân Thượng', 'description': 'Chưa xếp bàn', 'sortOrder': 1, 'isActive': true}
            ]);
          } else if (uri.path.endsWith('/api/table')) {
            // Zero tables in restaurant
            return jsonEncode([]);
          }
          return '[]';
        },
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: FloorTablePage(),
        ),
      );

      await tester.pumpAndSettle();

      // Verify the area tab is displayed
      expect(find.text('Khu Sân Thượng'), findsOneWidget);

      // Verify empty state is rendered without throwing
      expect(find.text('Chưa có bàn nào trong khu vực này'), findsOneWidget);
      expect(find.byIcon(Icons.table_restaurant), findsOneWidget);

      // Verify summary chips handle 0 tables gracefully
      expect(find.text('Tổng bàn: 0'), findsOneWidget);
      expect(find.text('Trống: 0'), findsOneWidget);
      expect(find.text('Có khách: 0'), findsOneWidget);
      expect(find.text('Đặt trước: 0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Switching to an area with zero tables renders empty state gracefully', (tester) async {
      HttpOverrides.global = ChallengeHttpOverrides(
        handler: (uri, method) {
          if (uri.path.contains('/areas')) {
            return jsonEncode([
              {'areaId': 1, 'areaName': 'Khu Có Bàn', 'sortOrder': 1, 'isActive': true},
              {'areaId': 2, 'areaName': 'Khu Trống', 'sortOrder': 2, 'isActive': true},
            ]);
          } else if (uri.path.endsWith('/api/table')) {
            return jsonEncode([
              {'tableId': 1, 'areaId': 1, 'tableName': 'Bàn 1-01', 'capacity': 4, 'status': 0},
            ]);
          }
          return '[]';
        },
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: FloorTablePage(),
        ),
      );

      await tester.pumpAndSettle();

      // In Area 1: Table exists
      expect(find.text('Bàn 1-01'), findsOneWidget);
      expect(find.text('Chưa có bàn nào trong khu vực này'), findsNothing);

      // Switch to Area 2 (Khu Trống)
      await tester.tap(find.text('Khu Trống'));
      await tester.pumpAndSettle();

      // In Area 2: Empty state is rendered
      expect(find.text('Chưa có bàn nào trong khu vực này'), findsOneWidget);
      expect(find.byIcon(Icons.table_restaurant), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Challenge Task 1.2: Table Transfer Dialog Unoccupied Constraint', () {
    testWidgets('Transfer dialog ONLY lists unoccupied tables (status == 0)', (tester) async {
      HttpOverrides.global = ChallengeHttpOverrides(
        handler: (uri, method) {
          if (uri.path.contains('/areas')) {
            return jsonEncode([
              {'areaId': 1, 'areaName': 'Khu VIP', 'sortOrder': 1, 'isActive': true}
            ]);
          } else if (uri.path.endsWith('/api/table')) {
            return jsonEncode([
              {'tableId': 1, 'areaId': 1, 'tableName': 'VIP 01 (Nguồn)', 'capacity': 4, 'status': 1, 'currentOrderId': 301},
              {'tableId': 2, 'areaId': 1, 'tableName': 'VIP 02 (Có khách)', 'capacity': 4, 'status': 1, 'currentOrderId': 302},
              {'tableId': 3, 'areaId': 1, 'tableName': 'VIP 03 (Đã đặt)', 'capacity': 6, 'status': 2},
              {'tableId': 4, 'areaId': 1, 'tableName': 'VIP 04 (Trống)', 'capacity': 4, 'status': 0},
            ]);
          }
          return '[]';
        },
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: FloorTablePage(),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on occupied VIP 01 to open action sheet
      await tester.tap(find.text('VIP 01 (Nguồn)'));
      await tester.pumpAndSettle();

      // Tap 'Chuyển bàn ăn'
      await tester.tap(find.text('Chuyển bàn ăn'));
      await tester.pumpAndSettle();

      // Dialog is open
      expect(find.text('Chuyển bàn ăn'), findsWidgets);
      expect(find.text('Bàn chuyển đi: VIP 01 (Nguồn)'), findsOneWidget);

      // Verify that VIP 04 (Trống) IS included in the dropdown items
      expect(find.text('VIP 04 (Trống) (4 ghế - Khu VIP)'), findsOneWidget);

      // Verify that VIP 02 (Occupied) and VIP 03 (Reserved) are NOT in the dropdown items
      expect(find.textContaining('VIP 02 (Có khách) (4 ghế'), findsNothing);
      expect(find.textContaining('VIP 03 (Đã đặt) (6 ghế'), findsNothing);
      // Verify source table itself is not in the destination options
      expect(find.textContaining('VIP 01 (Nguồn) (4 ghế'), findsNothing);
    });

    testWidgets('Transfer shows warning SnackBar when no available tables exist', (tester) async {
      HttpOverrides.global = ChallengeHttpOverrides(
        handler: (uri, method) {
          if (uri.path.contains('/areas')) {
            return jsonEncode([
              {'areaId': 1, 'areaName': 'Khu Kín Chỗ', 'sortOrder': 1, 'isActive': true}
            ]);
          } else if (uri.path.endsWith('/api/table')) {
            // All tables are occupied or reserved
            return jsonEncode([
              {'tableId': 1, 'areaId': 1, 'tableName': 'Bàn Đầy 1', 'capacity': 4, 'status': 1, 'currentOrderId': 401},
              {'tableId': 2, 'areaId': 1, 'tableName': 'Bàn Đầy 2', 'capacity': 4, 'status': 1, 'currentOrderId': 402},
              {'tableId': 3, 'areaId': 1, 'tableName': 'Bàn Đã Đặt', 'capacity': 6, 'status': 2},
            ]);
          }
          return '[]';
        },
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: FloorTablePage(),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on Bàn Đầy 1
      await tester.tap(find.text('Bàn Đầy 1'));
      await tester.pumpAndSettle();

      // Tap 'Chuyển bàn ăn'
      await tester.tap(find.text('Chuyển bàn ăn'));
      await tester.pumpAndSettle();

      // SnackBar should be displayed informing user no tables are available
      expect(find.text('Không có bàn trống nào để chuyển đến!'), findsOneWidget);
    });
  });

  group('Challenge Task 1.3: Genuine Network Error Propagation & Offline Empty State', () {
    test('TableRepository throws clean network exception on network failure without fake mocks', () async {
      HttpOverrides.global = ChallengeHttpOverrides(simulateOffline: true);

      // 1. getAreas() throws Exception on network failure
      expect(() => TableRepository.getAreas(), throwsA(isA<Exception>()));

      // 2. getAllTables() throws Exception on network failure
      expect(() => TableRepository.getAllTables(), throwsA(isA<Exception>()));

      // 3. getTablesByArea(1) throws Exception on network failure
      expect(() => TableRepository.getTablesByArea(1), throwsA(isA<Exception>()));

      // 4. updateStatus returns false on network failure without fake memory mutation
      final updateOk = await TableRepository.updateStatus(1, 1);
      expect(updateOk, false);

      // 5. transferTable returns false on network failure without fake memory mutation
      final transferOk = await TableRepository.transferTable(1, 3);
      expect(transferOk, false);
    });

    testWidgets('FloorTablePage renders genuine offline empty state when network is unreachable', (tester) async {
      HttpOverrides.global = ChallengeHttpOverrides(simulateOffline: true);

      await tester.pumpWidget(
        const MaterialApp(
          home: FloorTablePage(),
        ),
      );

      await tester.pumpAndSettle();

      // Verify that genuine offline empty state is rendered (wifi_off icon and error text)
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
      expect(find.text('Không thể tải danh sách khu vực bàn ăn.'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);

      // Verify no unhandled exceptions
      expect(tester.takeException(), isNull);
    });
  });
}
