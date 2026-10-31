import '../domain/models/contract_summary_model.dart';

import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import 'repositories/contract_repository.dart';
import 'contract_detail_data.dart';
import '../domain/models/extension_models.dart';

class ContractListRepository {
  final Dio _dio;
  ContractListRepository({Dio? dio}) : _dio = dio ?? ApiClient.instance;

  Future<List<ContractSummaryModel>> getContracts() async {
    try {
      final response = await _dio.get('/api/hop-dong/cua-toi');
      final data = response.data as List;

      return await Future.wait(
        data.map((json) async {
          // The list endpoint omits supplements. Re-read renewable contracts so
          // approved dates and pending requests remain consistent with details.
          DateTime returnDate = DateTime.parse(json['thoiGianTraDuKien']);
          ExtensionSummary? extension;
          if ([
            'DA_KY',
            'CHO_BAN_GIAO',
            'DANG_THUE',
          ].contains(json['trangThai'])) {
            final detail = await ContractRepository(
              dio: _dio,
            ).getContractById(json['maHopDong']);
            final model =
                ContractDetailData.fromJson(detail, json['maHopDong']).contract;
            returnDate = model.effectiveReturnDate;
            extension = model.latestExtension;
          }
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
          final name =
              soLuong > 1
                  ? '$tenDongMay và ${soLuong - 1} thiết bị khác'
                  : tenDongMay;

          return ContractSummaryModel(
            id: json['maHopDong'] ?? '',
            status: parseStatus(json['trangThai'] ?? ''),
            originalStatus: json['trangThai'] ?? '',
            imagePath: hinhAnh,
            deviceName: name,
            packageInfo:
                'Gói thuê thiết bị', // Mock or add to backend later if needed
            pickupDate: DateTime.parse(json['thoiGianBanGiao']),
            returnDate: returnDate,
            branchName: json['tenCuaHang'] ?? '',
            extension: extension,
            statusAlertMessage:
                extension?.listMessage ??
                (json['trangThai'] == 'CHO_KY'
                    ? 'Bạn có hợp đồng đang chờ ký.'
                    : null),
            totalAmount: json['tongTien'] as num? ?? 0,
          );
        }),
      );
    } catch (e) {
      throw Exception('Lỗi khi tải danh sách hợp đồng: $e');
    }
  }
}
