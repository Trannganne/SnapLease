import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/formatters/rental_time_formatter.dart';
import '../../../../core/storage/token_storage.dart';
import '../../domain/models/cart_item_model.dart';
import '../../domain/repositories/cart_repository.dart';
import '../../../../domain/entities/device_detail.dart';
import '../../../device_detail/data/device_detail_repository.dart';

class CartFailure implements Exception {
  final String message;
  const CartFailure(this.message);
  @override
  String toString() => message;
}

class CartHoldEditFailure extends CartFailure {
  final String? code;
  final bool uncertain;
  const CartHoldEditFailure(
    super.message, {
    this.code,
    required this.uncertain,
  });
}

class DioCartRepository extends CartRepository {
  final Dio dio;
  List<CartItemModel> _items = [];
  int _generation = 0;
  DioCartRepository({Dio? dio}) : dio = dio ?? ApiClient.instance;
  @override
  Future<List<BranchAvailability>> branchOptions(String modelId) => _session(
    () async =>
        (await DeviceDetailRepository(
          dio: dio,
        ).getDeviceDetail(modelId)).branches,
  );
  @override
  void invalidateSession() {
    ++_generation;
    _items = [];
  }

  Future<T> _session<T>(Future<T> Function() call) async {
    final generation = _generation;
    final token = await TokenStorage.getToken();
    if (token == null) {
      throw const CartFailure('Vui lòng đăng nhập để sử dụng giỏ hàng.');
    }
    try {
      final result = await call();
      if (generation != _generation || token != await TokenStorage.getToken()) {
        throw const CartFailure('Phiên đăng nhập đã thay đổi.');
      }
      return result;
    } on DioException catch (e) {
      throw CartFailure(
        e.response?.data is Map
            ? (e.response!.data['loi'] ?? 'Không thể cập nhật giỏ hàng.')
                .toString()
            : 'Chưa xác định kết quả. Hãy tải lại; ứng dụng không tự gửi lại.',
      );
    }
  }

  static String localTime(DateTime d) => RentalTimeFormatter.wallClock(d);

  Future<Map<String, dynamic>> getHeldCart(String id) => _session(
    () async => Map<String, dynamic>.from(
      (await dio.get('/api/giu-cho/$id')).data as Map,
    ),
  );

  Future<Map<String, dynamic>> updateHeldCart(
    String id,
    List<CartItemModel> items, {
    required String branchId,
    required DateTime pickup,
    required DateTime dropoff,
  }) => _session(() async {
    if (items.isEmpty || items.any((item) => item.version == null)) {
      throw const CartHoldEditFailure(
        'Thiếu phiên bản lựa chọn. Hãy kiểm tra lại giữ chỗ.',
        uncertain: false,
      );
    }
    try {
      final response = await dio.put(
        '/api/gio-hang/giu-cho/$id',
        data: {
          'maCuaHang': branchId,
          'ngayBatDau': localTime(pickup),
          'ngayKetThuc': localTime(dropoff),
          'items': [
            for (final item in items) {'id': item.id, 'phienBan': item.version},
          ],
        },
      );
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (error) {
      final data = error.response?.data;
      throw CartHoldEditFailure(
        data is Map
            ? (data['loi'] ?? 'Không thể cập nhật giữ chỗ.').toString()
            : 'Chưa xác định kết quả cập nhật. Cần kiểm tra lại giữ chỗ.',
        code: data is Map ? data['code']?.toString() : null,
        uncertain: ![400, 403, 404, 409].contains(error.response?.statusCode),
      );
    }
  });
  static CartItemModel fromJson(Map<String, dynamic> j) {
    final q = j['baoGia'] as Map;
    return CartItemModel(
      id: j['maChiTietGioHang'] as String,
      version: j['phienBan'] as String?,
      branchId: j['maCuaHang'] as String,
      branchName: j['tenCuaHang'] as String,
      modelId: j['maDongMay'] as String,
      modelName: j['tenDongMay'] as String,
      imageUrl: j['anhDaiDien'] as String? ?? '',
      dailyPrice: q['donGiaSauGiam'] as num,
      depositPrice: q['tienCocMotDonVi'] as num,
      serverRentalTotal: q['tongTienThue'] as num,
      serverDepositTotal: q['tongTienCoc'] as num,
      startDate: DateTime.parse(j['ngayBatDau'] as String),
      endDate: DateTime.parse(j['ngayKetThuc'] as String),
      rentalDays: q['soNgayTinhPhi'] as int,
      quantity: j['soLuong'] as int,
      maxAvailable: j['soLuongConTrong'] as int,
      isAvailable: j['khaDung'] == true,
      isSelected: false,
    );
  }

  Map<String, dynamic> _body(
    String model,
    String branch,
    int quantity,
    DateTime start,
    DateTime end, [
    String? version,
  ]) => {
    'maDongMay': model,
    'maCuaHang': branch,
    'soLuong': quantity,
    'ngayBatDau': localTime(start),
    'ngayKetThuc': localTime(end),
    'phienBan': version,
  };
  @override
  Future<List<CartItemModel>> getCartItems({bool forceRefresh = false}) async {
    final result = await _session(
      () async =>
          ((await dio.get('/api/gio-hang')).data as List)
              .map((j) => fromJson(Map<String, dynamic>.from(j as Map)))
              .toList(),
    );
    final selected = _items.where((i) => i.isSelected).map((i) => i.id).toSet();
    return _items =
        result
            .map((i) => i.copyWith(isSelected: selected.contains(i.id)))
            .toList();
  }

  @override
  Future<CartItemModel> addItem({
    required String modelId,
    required String branchId,
    required int quantity,
    required DateTime start,
    required DateTime end,
  }) => _session(
    () async => fromJson(
      Map<String, dynamic>.from(
        (await dio.post(
              '/api/gio-hang/chi-tiet',
              data: _body(modelId, branchId, quantity, start, end),
            )).data
            as Map,
      ),
    ),
  );
  @override
  Future<CartItemModel> updateItem(
    CartItemModel item, {
    DateTime? start,
    DateTime? end,
    String? branchId,
  }) async {
    final updated = await _session(
      () async => fromJson(
        Map<String, dynamic>.from(
          (await dio.put(
                '/api/gio-hang/chi-tiet/${item.id}',
                data: _body(
                  item.modelId,
                  branchId ?? item.branchId,
                  item.quantity,
                  start ?? item.startDate,
                  end ?? item.endDate,
                  item.version,
                ),
              )).data
              as Map,
        ),
      ),
    );
    final result = updated.copyWith(isSelected: item.isSelected);
    _items = _items.map((i) => i.id == item.id ? result : i).toList();
    return result;
  }

  @override
  Future<CartItemModel> updateQuantity({
    required String cartItemId,
    required int quantity,
  }) => updateItem(
    _items.singleWhere((i) => i.id == cartItemId).copyWith(quantity: quantity),
  );
  @override
  Future<void> removeItem({required String cartItemId}) async {
    final item = _items.singleWhere((i) => i.id == cartItemId);
    await _session(
      () => dio.delete(
        '/api/gio-hang/chi-tiet/$cartItemId',
        queryParameters: {'phienBan': item.version},
      ),
    );
    _items = _items.where((i) => i.id != cartItemId).toList();
  }

  @override
  Future<CartItemModel> toggleItemSelection({
    required String cartItemId,
    required bool isSelected,
  }) async {
    final item = _items
        .singleWhere((i) => i.id == cartItemId)
        .copyWith(isSelected: isSelected);
    _items = _items.map((i) => i.id == cartItemId ? item : i).toList();
    return item;
  }

  @override
  Future<void> clearCart() async {
    throw const CartFailure('Xóa từng mục để giữ kiểm soát phiên bản.');
  }

  @override
  Future<Map<String, dynamic>> checkout(
    List<CartItemModel> items,
  ) => _session(() async {
    if (items.isEmpty ||
        items.any(
          (i) =>
              i.branchId != items.first.branchId ||
              i.startDate != items.first.startDate ||
              i.endDate != items.first.endDate,
        )) {
      throw const CartFailure(
        'Chọn các mục cùng chi nhánh và cùng thời điểm bắt đầu–kết thúc.',
      );
    }
    final sorted = [...items]..sort((a, b) => a.id.compareTo(b.id));
    final payload = jsonEncode({
      'items': sorted.map((i) => {'id': i.id, 'phienBan': i.version}).toList(),
    });
    final token = await TokenStorage.getToken();
    final markerKey = 'cart_checkout_${sha256.convert(utf8.encode(token!))}';
    final prefs = await SharedPreferences.getInstance();
    var raw = prefs.getString(markerKey);
    if (raw != null) {
      final previous = jsonDecode(raw) as Map;
      try {
        final found = Map<String, dynamic>.from(
          (await dio.get('/api/gio-hang/checkout/${previous['key']}')).data
              as Map,
        );
        if (found['trangThai'] != 'DANG_GIU') {
          await prefs.remove(markerKey);
          raw = null;
        } else if (previous['payload'] == payload) {
          return found;
        } else if (found['cartItems'] is List) {
          // An in-place hold edit advances the selected versions. Recover that
          // same hold from its actual snapshot without attempting another POST.
          final held =
              (found['cartItems'] as List)
                  .map((row) => Map<String, dynamic>.from(row as Map))
                  .toList()
                ..sort(
                  (a, b) => (a['maChiTietGioHang'] as String).compareTo(
                    b['maChiTietGioHang'] as String,
                  ),
                );
          final actualPayload = jsonEncode({
            'items': [
              for (final row in held)
                {'id': row['maChiTietGioHang'], 'phienBan': row['phienBan']},
            ],
          });
          if (actualPayload == payload) {
            await prefs.setString(
              markerKey,
              jsonEncode({'key': previous['key'], 'payload': payload}),
            );
            return found;
          }
        }
      } on DioException catch (e) {
        if (e.response?.statusCode != 404) rethrow;
      }
    }
    var key = const Uuid().v4();
    if (raw != null) {
      final previous = jsonDecode(raw) as Map;
      if (previous['payload'] != payload) {
        throw const CartFailure(
          'Một checkout chưa được đối soát. Hãy hoàn tất/hủy lượt trước rồi tải lại.',
        );
      }
      key = previous['key'] as String;
    } else {
      await prefs.setString(
        markerKey,
        jsonEncode({'key': key, 'payload': payload}),
      );
    }
    final response = await dio.post(
      '/api/gio-hang/checkout',
      data: jsonDecode(payload),
      options: Options(headers: {'Idempotency-Key': key}),
    );
    final result = Map<String, dynamic>.from(response.data as Map);
    if (result['trangThai'] != 'DANG_GIU') {
      await prefs.remove(markerKey);
      throw const CartFailure(
        'Lượt checkout trước đã kết thúc. Hãy tải lại giỏ hàng trước khi tiếp tục.',
      );
    }
    return result;
  });
}
