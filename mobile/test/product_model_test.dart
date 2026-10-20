import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_pos_app/models/category.dart';
import 'package:restaurant_pos_app/models/product.dart';

void main() {
  group('Category Model Tests', () {
    test('Category fromMap and toMap serialization', () {
      final map = {
        'id': 1,
        'name': 'Cà phê truyền thống',
        'title': 'Cà phê phin Robusta Đắk Lắk',
        'description': 'Đậm đà hương vị nguyên bản',
        'icon': 'traditional_coffee.png',
        'sortOrder': 1,
        'isActive': true,
      };

      final cat = Category.fromMap(map);
      expect(cat.id, 1);
      expect(cat.name, 'Cà phê truyền thống');
      expect(cat.title, 'Cà phê phin Robusta Đắk Lắk');
      expect(cat.description, 'Đậm đà hương vị nguyên bản');
      expect(cat.icon, 'traditional_coffee.png');
      expect(cat.sortOrder, 1);
      expect(cat.isActive, true);
      expect(cat.fullIconUrl, contains('traditional_coffee.png'));

      final toMap = cat.toMap();
      expect(toMap['id'], 1);
      expect(toMap['name'], 'Cà phê truyền thống');
      expect(toMap['icon'], 'traditional_coffee.png');
    });

    test('Category fromMap supports categoryId and categoryName aliases', () {
      final map = {
        'categoryId': 5,
        'categoryName': 'Điểm tâm',
      };

      final cat = Category.fromMap(map);
      expect(cat.id, 5);
      expect(cat.name, 'Điểm tâm');
      expect(cat.isActive, true);
    });
  });

  group('Product & Attribute Model Tests', () {
    test('Product serialization with attributes', () {
      final map = {
        'productId': 10,
        'categoryId': 1,
        'categoryName': 'Cà phê truyền thống',
        'productName': 'Cà phê muối xứ Huế',
        'price': 39000,
        'unit': 'Ly',
        'description': 'Cà phê kem muối mặn mà',
        'imageUrl': 'cafe_muoi.jpg',
        'isAvailable': true,
        'isFeatured': true,
        'attributes': [
          {
            'attributeId': 1,
            'productId': 10,
            'attributeGroup': 'Size',
            'attributeName': 'Size L',
            'extraPrice': 8000.0,
            'isRequired': true,
          },
          {
            'attributeId': 2,
            'productId': 10,
            'attributeGroup': 'Đường',
            'attributeName': '50% đường',
            'extraPrice': 0.0,
            'isRequired': false,
          }
        ]
      };

      final product = Product.fromMap(map);
      expect(product.productId, 10);
      expect(product.categoryId, 1);
      expect(product.categoryName, 'Cà phê truyền thống');
      expect(product.productName, 'Cà phê muối xứ Huế');
      expect(product.price, 39000.0);
      expect(product.unit, 'Ly');
      expect(product.isFeatured, true);
      expect(product.fullImageUrl, contains('cafe_muoi.jpg'));

      expect(product.attributes.length, 2);
      expect(product.attributes[0].attributeName, 'Size L');
      expect(product.attributes[0].extraPrice, 8000.0);
      expect(product.attributes[0].isRequired, true);
      expect(product.attributes[1].attributeName, '50% đường');

      final toMap = product.toMap();
      expect(toMap['productId'], 10);
      expect(toMap['productName'], 'Cà phê muối xứ Huế');
      expect(toMap['price'], 39000.0);
      expect((toMap['attributes'] as List).length, 2);
    });

    test('PagedProductResult fromMap parses data array and pagination metadata', () {
      final map = {
        'totalItems': 25,
        'page': 2,
        'pageSize': 10,
        'totalPages': 3,
        'data': [
          {
            'productId': 11,
            'categoryId': 2,
            'productName': 'Espresso',
            'price': 35000,
            'unit': 'Tách',
            'imageUrl': 'espresso.jpg',
          }
        ]
      };

      final paged = PagedProductResult.fromMap(map);
      expect(paged.totalItems, 25);
      expect(paged.page, 2);
      expect(paged.pageSize, 10);
      expect(paged.totalPages, 3);
      expect(paged.data.length, 1);
      expect(paged.data.first.productName, 'Espresso');
    });
  });
}
