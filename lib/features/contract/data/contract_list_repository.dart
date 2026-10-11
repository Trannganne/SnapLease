import '../domain/models/contract_summary_model.dart';

import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';

class ContractListRepository {
  final Dio _dio = ApiClient.instance;

  Future<List<ContractSummaryModel>> getContracts() async {
    try {
      final response = await _dio.get('/api/hop-dong/cua-toi');
      final data = response.data as List;
      
      return data.map((json) {
        ContractStatus parseStatus(String statusStr) {
          switch (statusStr) {
            case 'CHO_KY':
            case 'DA_KY':
            case 'CHO_BAN_GIAO':
              return ContractStatus.pending;
            case 'DANG_THUE':
              return ContractStatus.active;
            case 'HOAN_THANH':
              return ContractStatus.completed;
            case 'DA_HUY':
              return ContractStatus.cancelled;
            default:
              return ContractStatus.all;
          }
        }

        final thietBi = json['thietBi'] ?? {};
        final hinhAnh = thietBi['hinhAnh'] ?? '';
        final tenDongMay = thietBi['tenDongMay'] ?? 'Không rõ thiết bị';
        final soLuong = json['soLuongThietBi'] ?? 1;
        final name = soLuong > 1 ? '$tenDongMay và ${soLuong - 1} thiết bị khác' : tenDongMay;

        return ContractSummaryModel(
          id: json['maHopDong'] ?? '',
          status: parseStatus(json['trangThai'] ?? ''),
          originalStatus: json['trangThai'] ?? '',
          imagePath: hinhAnh,
          deviceName: name,
          packageInfo: 'Gói thuê thiết bị', // Mock or add to backend later if needed
          pickupDate: DateTime.parse(json['thoiGianBanGiao']),
          returnDate: DateTime.parse(json['thoiGianTraDuKien']),
          branchName: json['tenCuaHang'] ?? '',
          statusAlertMessage: json['trangThai'] == 'CHO_KY' ? 'Bạn có hợp đồng đang chờ ký.' : null,
          totalAmount: (json['tongTien'] ?? 0).toInt(),
        );
      }).toList();
    } catch (e) {
      throw Exception('Lỗi khi tải danh sách hợp đồng: $e');
    }
  }
}
