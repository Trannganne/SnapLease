import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../domain/entities/category.dart';
import '../../../../domain/entities/product.dart';
import '../../../../domain/entities/brand.dart';
import '../../../../domain/entities/branch.dart';

class CatalogRepository {
  final Dio _dio = ApiClient.instance;

  Future<List<DeviceCategory>> getCategories() async {
    try {
      final response = await _dio.get('/api/danh-muc');
      if (response.statusCode == 200) {
        final List<dynamic> data = (response.data is Map && (response.data as Map).containsKey('value')) 
            ? response.data['value'] 
            : response.data;
        return data.map((json) {
          String iconPath = 'assets/images/screen.png';
          if (json['maDanhMuc'] == 'DM001') {
            iconPath = 'assets/images/camera.png';
          } else if (json['maDanhMuc'] == 'DM002') {
            iconPath = 'assets/images/lens.png';
          }

          return DeviceCategory(
            id: json['maDanhMuc'] as String,
            name: json['tenDanhMuc'] as String,
            subtitle: json['moTa'] as String? ?? '',
            iconPath: iconPath,
          );
        }).toList();
      }
      throw Exception('Failed to load categories');
    } catch (e) {
      throw Exception('Failed to load categories: $e');
    }
  }

  Future<List<Brand>> getBrands() async {
    try {
      final response = await _dio.get('/api/thuong-hieu');
      if (response.statusCode == 200) {
        final List<dynamic> data = (response.data is Map && (response.data as Map).containsKey('value')) 
            ? response.data['value'] 
            : response.data;
        return data.map((json) => Brand.fromJson(json)).toList();
      }
      throw Exception('Failed to load brands');
    } catch (e) {
      throw Exception('Failed to load brands: $e');
    }
  }

  Future<List<Branch>> getBranches() async {
    try {
      final response = await _dio.get('/api/cua-hang');
      if (response.statusCode == 200) {
        final List<dynamic> data = (response.data is Map && (response.data as Map).containsKey('value')) 
            ? response.data['value'] 
            : response.data;
        return data.map((json) => Branch.fromJson(json)).toList();
      }
      throw Exception('Failed to load branches');
    } catch (e) {
      throw Exception('Failed to load branches: $e');
    }
  }

  Future<Map<String, dynamic>> getProducts({
    String? keyword,
    String? categoryId,
    String? branchId,
    String? brandId,
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'trang': page,
        'kichThuocTrang': pageSize,
      };
      
      if (keyword != null && keyword.isNotEmpty) queryParams['tuKhoa'] = keyword;
      if (categoryId != null && categoryId.isNotEmpty) queryParams['maDanhMuc'] = categoryId;
      if (branchId != null && branchId.isNotEmpty) queryParams['maCuaHang'] = branchId;
      if (brandId != null && brandId.isNotEmpty) queryParams['maThuongHieu'] = brandId;

      final response = await _dio.get(
        '/api/dong-may',
        queryParameters: queryParams,
        cancelToken: cancelToken,
      );
      
      if (response.statusCode == 200) {
        final data = response.data;
        final int tongSo = data['tongSo'] as int;
        final List<dynamic> duLieu = data['duLieu'];

        final List<Product> products = duLieu.map((json) {
          final giaThue = json['giaThueNgay'] as num;
          // Format 150000 -> 150.000đ/ngày
          final formattedPrice = '${giaThue.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}đ/ngày';
          
          return Product(
            id: json['maDongMay'] as String,
            name: json['tenDongMay'] as String,
            image: json['anhDaiDien'] as String? ?? '',
            rating: (json['rating'] as num).toDouble(),
            reviewCount: json['reviewCount'] as int,
            pricePerDay: formattedPrice,
            available: json['available'] as bool,
            category: json['tenDanhMuc'] as String,
            branchIds: (json['branchIds'] as List<dynamic>).map((e) => e.toString()).toList(),
          );
        }).toList();

        return {
          'tongSo': tongSo,
          'products': products,
        };
      }
      throw Exception('Failed to load products');
    } catch (e) {
      throw Exception('Failed to load products: $e');
    }
  }
}
