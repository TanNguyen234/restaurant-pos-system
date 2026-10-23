import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_pos_app/repositories/table_repository.dart';

void main() {
  final originalBaseUrl = TableRepository.baseUrl;
  final originalTimeout = TableRepository.timeoutDuration;

  tearDown(() {
    TableRepository.baseUrl = originalBaseUrl;
    TableRepository.timeoutDuration = originalTimeout;
  });

  group('Adversarial Test Suite 1: Real TCP Connection Refusal (No Server Running)', () {
    setUp(() {
      // Point to an inactive loopback port to produce genuine SocketException (Connection Refused)
      TableRepository.baseUrl = 'http://127.0.0.1:59199/api/table';
      TableRepository.timeoutDuration = const Duration(milliseconds: 500);
    });

    test('getAreas() strictly throws Exception and NEVER returns fallback mocks when backend is unreachable', () async {
      try {
        final result = await TableRepository.getAreas();
        fail('Expected Exception, but getAreas returned: $result');
      } catch (e) {
        expect(e, isA<Exception>());
        expect(e.toString(), contains('Không thể tải danh sách khu vực'));
      }
    });

    test('getTablesByArea(1) strictly throws Exception and NEVER returns fallback mocks when backend is unreachable', () async {
      try {
        final result = await TableRepository.getTablesByArea(1);
        fail('Expected Exception, but getTablesByArea returned: $result');
      } catch (e) {
        expect(e, isA<Exception>());
        expect(e.toString(), contains('Không thể tải danh sách bàn theo khu vực'));
      }
    });

    test('getAllTables() strictly throws Exception and NEVER returns fallback mocks when backend is unreachable', () async {
      try {
        final result = await TableRepository.getAllTables();
        fail('Expected Exception, but getAllTables returned: $result');
      } catch (e) {
        expect(e, isA<Exception>());
        expect(e.toString(), contains('Không thể tải toàn bộ danh sách bàn'));
      }
    });

    test('updateStatus() strictly returns false and does NOT alter any memory cache on network refusal', () async {
      final success = await TableRepository.updateStatus(1, 1);
      expect(success, isFalse, reason: 'updateStatus must return false on connection refusal');
    });

    test('transferTable() strictly returns false and does NOT alter any memory cache on network refusal', () async {
      final success = await TableRepository.transferTable(1, 2);
      expect(success, isFalse, reason: 'transferTable must return false on connection refusal');
    });

    test('Repeated updateStatus calls remain stateless and do not accumulate side effects', () async {
      for (int i = 0; i < 5; i++) {
        final res = await TableRepository.updateStatus(i + 1, 1);
        expect(res, isFalse);
      }
    });
  });

  group('Adversarial Test Suite 2: Network Timeout Handling', () {
    late HttpServer slowServer;

    setUp(() async {
      // Spin up a local server that delays responding longer than timeoutDuration
      slowServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      slowServer.listen((request) async {
        await Future.delayed(const Duration(milliseconds: 600));
        request.response.statusCode = 200;
        request.response.write('[]');
        await request.response.close();
      });

      TableRepository.baseUrl = 'http://127.0.0.1:${slowServer.port}/api/table';
      TableRepository.timeoutDuration = const Duration(milliseconds: 150);
    });

    tearDown(() async {
      await slowServer.close(force: true);
    });

    test('getAreas() throws Exception on timeout without returning stale data', () async {
      expect(
        () => TableRepository.getAreas(),
        throwsA(predicate((e) => e is Exception && e.toString().contains('TimeoutException'))),
      );
    });

    test('getTablesByArea() throws Exception on timeout without returning stale data', () async {
      expect(
        () => TableRepository.getTablesByArea(1),
        throwsA(predicate((e) => e is Exception && e.toString().contains('TimeoutException'))),
      );
    });

    test('updateStatus() returns false on timeout', () async {
      final success = await TableRepository.updateStatus(1, 1);
      expect(success, isFalse);
    });

    test('transferTable() returns false on timeout', () async {
      final success = await TableRepository.transferTable(1, 2);
      expect(success, isFalse);
    });
  });

  group('Adversarial Test Suite 3: Backend HTTP 500 / 404 / 502 Errors', () {
    late HttpServer errorServer;
    int targetStatusCode = 500;

    setUp(() async {
      errorServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      errorServer.listen((request) async {
        request.response.statusCode = targetStatusCode;
        request.response.write('{"error": "Internal Server Error"}');
        await request.response.close();
      });

      TableRepository.baseUrl = 'http://127.0.0.1:${errorServer.port}/api/table';
      TableRepository.timeoutDuration = const Duration(seconds: 1);
    });

    tearDown(() async {
      await errorServer.close(force: true);
    });

    test('HTTP 500: getAreas() throws Exception containing HTTP 500', () async {
      targetStatusCode = 500;
      try {
        await TableRepository.getAreas();
        fail('Expected exception on HTTP 500');
      } catch (e) {
        expect(e.toString(), contains('HTTP 500'));
      }
    });

    test('HTTP 404: getTablesByArea() throws Exception containing HTTP 404', () async {
      targetStatusCode = 404;
      try {
        await TableRepository.getTablesByArea(999);
        fail('Expected exception on HTTP 404');
      } catch (e) {
        expect(e.toString(), contains('HTTP 404'));
      }
    });

    test('HTTP 500: updateStatus() returns false', () async {
      targetStatusCode = 500;
      final result = await TableRepository.updateStatus(1, 1);
      expect(result, isFalse);
    });

    test('HTTP 500: transferTable() returns false', () async {
      targetStatusCode = 500;
      final result = await TableRepository.transferTable(1, 2);
      expect(result, isFalse);
    });
  });

  group('Adversarial Test Suite 4: Malformed Backend Payloads', () {
    late HttpServer malformedServer;

    setUp(() async {
      malformedServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      malformedServer.listen((request) async {
        request.response.statusCode = 200;
        request.response.headers.contentType = ContentType.json;
        // Invalid non-JSON payload or HTML error page returned with 200
        request.response.write('<html><body>502 Bad Gateway</body></html>');
        await request.response.close();
      });

      TableRepository.baseUrl = 'http://127.0.0.1:${malformedServer.port}/api/table';
      TableRepository.timeoutDuration = const Duration(seconds: 1);
    });

    tearDown(() async {
      await malformedServer.close(force: true);
    });

    test('Malformed payload causes getAreas() to throw FormatException wrapped in Exception', () async {
      try {
        await TableRepository.getAreas();
        fail('Expected Exception for malformed JSON');
      } catch (e) {
        expect(e, isA<Exception>());
        expect(e.toString(), contains('FormatException'));
      }
    });

    test('Malformed payload causes getTablesByArea() to throw FormatException wrapped in Exception', () async {
      try {
        await TableRepository.getTablesByArea(1);
        fail('Expected Exception for malformed JSON');
      } catch (e) {
        expect(e, isA<Exception>());
        expect(e.toString(), contains('FormatException'));
      }
    });
  });

  group('Adversarial Test Suite 5: Real Success Path (HTTP 200 With Valid Data)', () {
    late HttpServer successServer;

    setUp(() async {
      successServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      successServer.listen((request) async {
        request.response.statusCode = 200;
        request.response.headers.contentType = ContentType.json;

        if (request.uri.path.endsWith('/areas')) {
          request.response.write(jsonEncode([
            {'areaId': 1, 'areaName': 'Tầng 1 Live', 'sortOrder': 1, 'isActive': true},
            {'areaId': 2, 'areaName': 'Tầng 2 Live', 'sortOrder': 2, 'isActive': true},
          ]));
        } else if (request.uri.path.contains('/by-area/1')) {
          request.response.write(jsonEncode([
            {'tableId': 101, 'areaId': 1, 'tableName': 'Bàn 101', 'capacity': 4, 'status': 0},
          ]));
        } else if (request.uri.path.endsWith('/api/table') && request.method == 'GET') {
          request.response.write(jsonEncode([
            {'tableId': 101, 'areaId': 1, 'tableName': 'Bàn 101', 'capacity': 4, 'status': 0},
            {'tableId': 201, 'areaId': 2, 'tableName': 'Bàn 201', 'capacity': 2, 'status': 1},
          ]));
        } else if (request.uri.path.contains('/status') && request.method == 'PUT') {
          request.response.write(jsonEncode({'success': true}));
        } else if (request.uri.path.endsWith('/transfer') && request.method == 'POST') {
          request.response.write(jsonEncode({'success': true}));
        } else {
          request.response.write('[]');
        }
        await request.response.close();
      });

      TableRepository.baseUrl = 'http://127.0.0.1:${successServer.port}/api/table';
      TableRepository.timeoutDuration = const Duration(seconds: 1);
    });

    tearDown(() async {
      await successServer.close(force: true);
    });

    test('getAreas() parses real HTTP 200 response accurately', () async {
      final areas = await TableRepository.getAreas();
      expect(areas.length, 2);
      expect(areas[0].id, 1);
      expect(areas[0].name, 'Tầng 1 Live');
      expect(areas[1].name, 'Tầng 2 Live');
    });

    test('getTablesByArea() parses real HTTP 200 response accurately', () async {
      final tables = await TableRepository.getTablesByArea(1);
      expect(tables.length, 1);
      expect(tables[0].id, 101);
      expect(tables[0].name, 'Bàn 101');
      expect(tables[0].capacity, 4);
    });

    test('getAllTables() parses real HTTP 200 response accurately', () async {
      final tables = await TableRepository.getAllTables();
      expect(tables.length, 2);
      expect(tables[0].name, 'Bàn 101');
      expect(tables[1].name, 'Bàn 201');
    });

    test('updateStatus() returns true on HTTP 200 response', () async {
      final success = await TableRepository.updateStatus(101, 1);
      expect(success, isTrue);
    });

    test('transferTable() returns true on HTTP 200 response', () async {
      final success = await TableRepository.transferTable(101, 201);
      expect(success, isTrue);
    });
  });

  group('Adversarial Test Suite 6: Source Code & Architectural Invariant Audit', () {
    test('table_repository.dart contains zero traces of fallback mocks or hardcoded data', () {
      final file = File('lib/repositories/table_repository.dart');
      expect(file.existsSync(), isTrue, reason: 'table_repository.dart must exist');

      final content = file.readAsStringSync();

      // Ensure no fallback variables exist
      expect(content.contains('_fallbackAreas'), isFalse, reason: '_fallbackAreas must not exist');
      expect(content.contains('_fallbackTables'), isFalse, reason: '_fallbackTables must not exist');
      expect(content.contains('fallback'), isFalse, reason: 'No fallback logic allowed in table_repository.dart');

      // Ensure hardcoded floor names from previous mock are absent
      expect(content.contains('Tầng 1'), isFalse);
      expect(content.contains('Tầng 2'), isFalse);
      expect(content.contains('Sân vườn'), isFalse);
      expect(content.contains('Phòng VIP'), isFalse);

      // Verify clean error handling syntax
      expect(content.contains('throw Exception'), isTrue);
      expect(content.contains('response.statusCode == 200'), isTrue);
    });
  });
}
