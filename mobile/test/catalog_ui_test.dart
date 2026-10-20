import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_pos_app/models/product.dart';
import 'package:restaurant_pos_app/utils/database_helper.dart';
import 'package:restaurant_pos_app/views/cart_page.dart';
import 'package:restaurant_pos_app/views/home_page.dart';
import 'package:restaurant_pos_app/views/product_detail_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await DatabaseHelper().clearCart();
  });

  group('CartPage Widget Tests', () {
    testWidgets('Renders empty state when cart has no items', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CartPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Giỏ hàng của bạn đang trống'), findsOneWidget);
      expect(find.text('KHÁM PHÁ THỰC ĐƠN'), findsOneWidget);
    });

    testWidgets('Renders item and calculates total when item is in cart', (WidgetTester tester) async {
      await DatabaseHelper().insertOrUpdateCart({
        'product_id': 1,
        'product_name': 'Cà phê đen đá Đắk Lắk',
        'price': 25000.0,
        'quantity': 2,
        'image_url': 'cafe_den_da.jpg',
        'note': 'Ít đá',
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: CartPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cà phê đen đá Đắk Lắk'), findsOneWidget);
      expect(find.text('Ít đá'), findsOneWidget);
      expect(find.text('TIẾN HÀNH ĐẶT MÓN'), findsOneWidget);
    });
  });

  group('ProductDetailPage Widget Tests', () {
    testWidgets('Renders product detail with size options and add-to-cart button', (WidgetTester tester) async {
      final sampleProduct = Product(
        productId: 1,
        categoryId: 1,
        categoryName: 'Cà phê truyền thống',
        productName: 'Cà phê muối xứ Huế',
        price: 39000,
        unit: 'Ly',
        description: 'Kem muối béo ngậy',
        imageUrl: 'cafe_muoi.jpg',
        isAvailable: true,
        isFeatured: true,
        attributes: [
          ProductAttribute(
            attributeId: 1,
            productId: 1,
            attributeGroup: 'Size',
            attributeName: 'Size M (Chuẩn)',
            extraPrice: 0,
          ),
          ProductAttribute(
            attributeId: 2,
            productId: 1,
            attributeGroup: 'Size',
            attributeName: 'Size L (+8k)',
            extraPrice: 8000,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ProductDetailPage(product: sampleProduct),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cà phê muối xứ Huế'), findsWidgets);
      expect(find.text('Kích thước (Size)'), findsOneWidget);
      expect(find.text('Size M (Chuẩn)'), findsOneWidget);
      expect(find.text('Mức đường'), findsOneWidget);
      expect(find.text('Mức đá'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsWidgets);
    });
  });

  group('HomePage Widget Tests', () {
    testWidgets('Renders search bar, category chips, and product cards', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomePage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Restaurant & Cafe POS'), findsOneWidget);
      expect(find.text('Tất cả món'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });
  });
}
