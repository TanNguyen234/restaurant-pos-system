import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/product.dart';
import '../config/api_config.dart';

class ProductRepository {
  static String baseUrl = ApiConfig.baseUrl + '/api/product';
  static Duration timeoutDuration = const Duration(seconds: 4);

  // Fallback mock products for offline resilience & testing

  /// Lấy danh sách sản phẩm có phân trang, lọc theo danh mục, tìm kiếm và sắp xếp.
  static Future<PagedProductResult> getProducts({
    int? categoryId,
    String? search,
    int page = 1,
    int pageSize = 10,
    String? sortBy,
  }) async {
    final q=<String,String>{'page':'$page','pageSize':'$pageSize'};
    if(categoryId!=null)q['categoryId']='$categoryId';
    if(search!=null&&search.trim().isNotEmpty)q['search']=search.trim();
    if(sortBy!=null&&sortBy.trim().isNotEmpty)q['sortBy']=sortBy.trim();
    final uri=Uri.parse(baseUrl).replace(queryParameters:q);
    final res=await http.get(uri).timeout(timeoutDuration);
    if(res.statusCode!=200)throw StateError('Không tải được sản phẩm (HTTP ${res.statusCode})');
    return PagedProductResult.fromMap(jsonDecode(utf8.decode(res.bodyBytes)));
  }

  /// Lấy danh sách sản phẩm nổi bật
  static Future<List<Product>> getFeaturedProducts({int limit = 10}) async {
    final res=await http.get(Uri.parse('$baseUrl/featured?limit=$limit')).timeout(timeoutDuration);
    if(res.statusCode!=200)throw StateError('Không tải được món nổi bật (HTTP ${res.statusCode})');
    final List<dynamic> data=jsonDecode(utf8.decode(res.bodyBytes));
    return data.map((e)=>Product.fromMap(e)).toList();
  }

  /// Lấy chi tiết sản phẩm kèm thuộc tính
  static Future<Product?> getProductById(int id) async {
    final res=await http.get(Uri.parse('$baseUrl/$id')).timeout(timeoutDuration);
    if(res.statusCode==404)return null;
    if(res.statusCode!=200)throw StateError('Không tìm thấy sản phẩm (HTTP ${res.statusCode})');
    return Product.fromMap(jsonDecode(utf8.decode(res.bodyBytes)));
  }

  /// Lấy danh sách sản phẩm liên quan cùng danh mục có phân trang
  static Future<PagedProductResult> getRelatedProducts(
    int id, {
    int page = 1,
    int pageSize = 6,
  }) async {
    final res=await http.get(Uri.parse('$baseUrl/related/$id?page=$page&pageSize=$pageSize')).timeout(timeoutDuration);
    if(res.statusCode!=200)throw StateError('Không tải được sản phẩm liên quan (HTTP ${res.statusCode})');
    return PagedProductResult.fromMap(jsonDecode(utf8.decode(res.bodyBytes)));
  }

  /// Thêm món ăn mới kèm hỗ trợ multipart upload ảnh
  static Future<Map<String, dynamic>> createProduct(
    Map<String, dynamic> data, {
    Uint8List? imageBytes,
    String? imageFileName,
  }) async {
    try{
      final req=http.MultipartRequest('POST',Uri.parse(baseUrl));
      data.forEach((key,value){if(value!=null)req.fields[key]=value.toString();});
      if(imageBytes!=null&&imageBytes.isNotEmpty)req.files.add(http.MultipartFile.fromBytes('file',imageBytes,filename:imageFileName??'product.jpg'));
      final stream=await req.send().timeout(const Duration(seconds:12));
      final res=await http.Response.fromStream(stream);
      if(res.statusCode==200||res.statusCode==201)return {'success':true,'product':Product.fromMap(jsonDecode(utf8.decode(res.bodyBytes))),'message':'Đã thêm sản phẩm'};
      return {'success':false,'message':'Không thể tạo sản phẩm (HTTP ${res.statusCode})'};
    }catch(e){return {'success':false,'message':'Không thể thêm sản phẩm: $e'};}
  }

  /// Cập nhật món ăn kèm hỗ trợ upload ảnh mới
  static Future<Map<String, dynamic>> updateProduct(
    int id,
    Map<String, dynamic> data, {
    Uint8List? imageBytes,
    String? imageFileName,
  }) async {
    try{
      final req=http.MultipartRequest('PUT',Uri.parse('$baseUrl/$id'));
      data.forEach((key,value){if(value!=null)req.fields[key]=value.toString();});
      if(imageBytes!=null&&imageBytes.isNotEmpty)req.files.add(http.MultipartFile.fromBytes('file',imageBytes,filename:imageFileName??'product.jpg'));
      final stream=await req.send().timeout(const Duration(seconds:12));
      final res=await http.Response.fromStream(stream);
      if(res.statusCode==200)return {'success':true,'product':Product.fromMap(jsonDecode(utf8.decode(res.bodyBytes))),'message':'Đã cập nhật sản phẩm'};
      return {'success':false,'message':'Không thể sửa sản phẩm (HTTP ${res.statusCode})'};
    }catch(e){return {'success':false,'message':'Không thể cập nhật sản phẩm: $e'};}
  }

  /// Xóa món ăn (kiểm tra ràng buộc đơn hàng)
  static Future<Map<String, dynamic>> deleteProduct(int id) async {
    try{
      final res=await http.delete(Uri.parse('$baseUrl/$id')).timeout(timeoutDuration);
      return {'success':res.statusCode==200,'message':res.statusCode==200?'Đã xóa sản phẩm':'Không thể xóa sản phẩm (HTTP ${res.statusCode})'};
    }catch(e){return {'success':false,'message':'Không thể xóa sản phẩm: $e'};}
  }
}
