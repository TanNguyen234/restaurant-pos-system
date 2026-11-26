import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'escpos_socket_stub.dart' if (dart.library.io) 'escpos_socket_io.dart' as tcp_impl;

class EscPosPrinterConfig {
  final String host;
  final int port;
  final int paperWidthMm;

  const EscPosPrinterConfig({
    this.host = '192.168.1.200',
    this.port = 9100,
    this.paperWidthMm = 80,
  });
}

class EscPosPrinterService {
  static const String _kHostKey = 'pos_escpos_host';
  static const String _kPortKey = 'pos_escpos_port';
  static const String _kWidthKey = 'pos_escpos_width_mm';

  static Future<EscPosPrinterConfig> loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return EscPosPrinterConfig(
        host: prefs.getString(_kHostKey) ?? '192.168.1.200',
        port: prefs.getInt(_kPortKey) ?? 9100,
        paperWidthMm: prefs.getInt(_kWidthKey) ?? 80,
      );
    } catch (_) {
      return const EscPosPrinterConfig();
    }
  }

  static Future<void> saveConfig(EscPosPrinterConfig cfg) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kHostKey, cfg.host.trim());
    await prefs.setInt(_kPortKey, cfg.port);
    await prefs.setInt(_kWidthKey, cfg.paperWidthMm == 58 ? 58 : 80);
  }

  static String foldVietnamese(String input) {
    const src = 'àáạảãâầấậẩẫăằắặẳẵÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴèéẹẻẽêềếệểễÈÉẸẺẼÊỀẾỆỂỄìíịỉĩÌÍỊỈĨòóọỏõôồốộổỗơờớợởỡÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠùúụủũưừứựửữÙÚỤỦŨƯỪỨỰỬỮỳýỵỷỹỲÝỴỶỸđĐ';
    const dst = 'aaaaaaaaaaaaaaaaaAAAAAAAAAAAAAAAAAeeeeeeeeeeeEEEEEEEEEEEiiiiiIIIIIoooooooooooooooooOOOOOOOOOOOOOOOOOuuuuuuuuuuuUUUUUUUUUUUyyyyyYYYYYdD';
    final buf = StringBuffer();
    for (int i = 0; i < input.length; i++) {
      final ch = input[i];
      final idx = src.indexOf(ch);
      buf.write(idx >= 0 ? dst[idx] : ch);
    }
    return buf.toString();
  }

  /// Chuyển ký tự đặc biệt/emoji thành ASCII an toàn để tránh ArgumentError trong `ascii.encode`.
  static String sanitizeAscii(String input) {
    final folded = foldVietnamese(input)
        .replaceAll('•', '*')
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('…', '...')
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('‘', "'")
        .replaceAll('’', "'")
        .replaceAll('₫', 'd');
    final buf = StringBuffer();
    for (final code in folded.runes) {
      if (code >= 0x20 && code <= 0x7E) {
        buf.writeCharCode(code);
      } else if (code == 0x09 || code == 0x0A || code == 0x0D) {
        buf.writeCharCode(code);
      } else {
        buf.write(' ');
      }
    }
    return buf.toString();
  }

  static String _padColumns(String left, String right, int totalCols) {
    final l = sanitizeAscii(left);
    final r = sanitizeAscii(right);
    if (l.length + r.length + 1 >= totalCols) {
      final maxL = (totalCols - r.length - 1).clamp(4, totalCols);
      final trimmedL = l.length > maxL ? '${l.substring(0, maxL - 1)}.' : l;
      final spaces = (totalCols - trimmedL.length - r.length).clamp(1, totalCols);
      return '$trimmedL${' ' * spaces}$r';
    }
    final spaces = totalCols - l.length - r.length;
    return '$l${' ' * spaces}$r';
  }

  /// Tạo chuỗi byte nhị phân chuẩn ESC/POS cho máy in nhiệt 58mm (32 cột) hoặc 80mm (48 cột).
  static List<int> buildReceiptBytes(
    Map<String, dynamic> order, {
    int paperWidthMm = 80,
    bool isPreCheck = false,
    bool isDuplicate = false,
  }) {
    final cols = paperWidthMm == 58 ? 32 : 48;
    final divider = '-' * cols;
    final moneyFmt = NumberFormat('#,##0', 'vi_VN');
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');

    final bytes = <int>[];
    void cmd(List<int> c) => bytes.addAll(c);
    void line([String text = '']) => bytes.addAll(ascii.encode('${sanitizeAscii(text)}\n'));

    // ESC @ (Initialize printer)
    cmd([0x1B, 0x40]);
    // Center + Bold On
    cmd([0x1B, 0x61, 0x01]);
    cmd([0x1B, 0x45, 0x01]);
    line('RESTAURANT & CAFE POS');
    cmd([0x1B, 0x45, 0x00]);
    line(isPreCheck ? '*** PHIEU TAM TINH ***' : 'HOA DON THANH TOAN');
    if (isDuplicate) line('[ BAN IN LAI - DUPLICATE ]');
    line(divider);

    // Left align metadata
    cmd([0x1B, 0x61, 0x00]);
    final orderCode = (order['orderCode'] ?? 'ORD').toString();
    final tableName = (order['tableName'] ?? 'Mang ve').toString();
    final customer = (order['customerName'] ?? 'Khach le').toString();
    final created = DateTime.tryParse(order['createdAt']?.toString() ?? '') ?? DateTime.now();

    line('Ma don : $orderCode');
    line('Ban    : $tableName');
    line('Khach  : $customer');
    line('Thoi gian: ${dateFmt.format(created)}');
    line(divider);

    final rawDetails = (order['details'] as List? ?? order['items'] as List? ?? []);
    for (final item in rawDetails.whereType<Map>()) {
      final qty = (item['quantity'] as num?)?.toInt() ?? 1;
      final cookingStatus = (item['cookingStatus'] as num?)?.toInt() ?? 0;
      if (cookingStatus == 4) continue;
      final name = (item['productName'] ?? 'Mon').toString();
      final subTotal = (item['subTotal'] as num?)?.toDouble() ??
          ((item['unitPrice'] as num?)?.toDouble() ?? 0) * qty;
      line(_padColumns('${qty}x $name', '${moneyFmt.format(subTotal)}d', cols));
    }

    line(divider);
    final total = (order['totalAmount'] as num?)?.toDouble() ?? 0;
    final disc = (order['discountAmount'] as num?)?.toDouble() ?? 0;
    final finalAmt = (order['finalAmount'] as num?)?.toDouble() ?? (total - disc);

    line(_padColumns('Tam tinh:', '${moneyFmt.format(total)}d', cols));
    if (disc > 0) {
      line(_padColumns('Giam gia:', '-${moneyFmt.format(disc)}d', cols));
    }
    cmd([0x1B, 0x45, 0x01]);
    line(_padColumns('THANH TOAN:', '${moneyFmt.format(finalAmt)}d', cols));
    cmd([0x1B, 0x45, 0x00]);
    line(divider);

    cmd([0x1B, 0x61, 0x01]);
    line('Cam on quy khach - Hen gap lai!');
    bytes.addAll([0x0A, 0x0A, 0x0A]);
    // GS V 66 0 (Feed and partial cut)
    cmd([0x1D, 0x56, 0x42, 0x00]);
    return bytes;
  }

  static Future<Map<String, dynamic>> printOrderOverLan(
    Map<String, dynamic> order, {
    bool isPreCheck = false,
    bool isDuplicate = false,
  }) async {
    final cfg = await loadConfig();
    final rawBytes = buildReceiptBytes(
      order,
      paperWidthMm: cfg.paperWidthMm,
      isPreCheck: isPreCheck,
      isDuplicate: isDuplicate,
    );
    final res = await tcp_impl.sendRawTcpBytes(host: cfg.host, port: cfg.port, bytes: rawBytes);
    return {
      ...res,
      'byteCount': rawBytes.length,
      'paperWidthMm': cfg.paperWidthMm,
      'host': cfg.host,
      'port': cfg.port,
    };
  }
}
