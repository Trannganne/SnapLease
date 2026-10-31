import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import '../../../../core/storage/token_storage.dart';
import '../../data/contract_detail_data.dart';
import '../../data/repositories/contract_repository.dart';
import '../../domain/models/extension_models.dart';
import '../../services/contract_pdf_service.dart';
import '../../data/extension_submission_store.dart';
import '../../../notification/data/push_service.dart';

class ContractRenewalState {
  final ContractModel? contract;
  final DateTime? currentReturn;
  final DateTime? selected;
  final ExtensionQuote? quote;
  final Map<String, dynamic>? pending;
  final Map<String, dynamic>? selectedAppendix;
  final bool loading, previewing, submitting, uncertain;
  final String? message;
  const ContractRenewalState({
    this.contract,
    this.currentReturn,
    this.selected,
    this.quote,
    this.pending,
    this.selectedAppendix,
    this.loading = false,
    this.previewing = false,
    this.submitting = false,
    this.uncertain = false,
    this.message,
  });
  bool get canSelect =>
      contract != null &&
      !loading &&
      !submitting &&
      !uncertain &&
      pending == null &&
      contract!.status == 'DANG_THUE' &&
      contract!.canExtend != false;
  bool get canSubmit =>
      canSelect &&
      !previewing &&
      quote?.available == true &&
      quote!.newReturn == selected;
  bool get canSign =>
      !loading &&
      !submitting &&
      contract?.status == 'DANG_THUE' &&
      selectedAppendix != null &&
      ExtensionSummary.fromJson(
        selectedAppendix!,
      ).canSignAt(contract!.serverNowUtc);
}

class ContractRenewalCubit extends Cubit<ContractRenewalState> {
  final String id;
  final ContractRepository repository;
  final ExtensionSubmissionStore store;
  final String? appendixId;
  int _generation = 0;
  StreamSubscription<void>? _session;
  StreamSubscription<void>? _push;
  Timer? _expiry;
  bool _reloadRequested = false;
  Future<void>? _loading;
  @override
  Future<void> close() {
    ++_generation;
    _session?.cancel();
    _push?.cancel();
    _expiry?.cancel();
    return super.close();
  }

  ContractRenewalCubit(
    this.id,
    this.repository, {
    ExtensionSubmissionStore? store,
    this.appendixId,
  }) : store = store ?? ExtensionSubmissionStore(),
       super(const ContractRenewalState()) {
    _push = PushService.instance.updates.stream.listen((_) => load());
    _session = TokenStorage.changes.listen((_) {
      ++_generation;
      _expiry?.cancel();
      if (!isClosed) {
        emit(
          const ContractRenewalState(message: 'Phiên đăng nhập đã thay đổi.'),
        );
      }
    });
  }

  Future<void> load({String? message, bool uncertain = false}) {
    if (isClosed) return Future.value();
    if (state.submitting || _loading != null) {
      _reloadRequested = true;
      return _loading ?? Future.value();
    }
    final future = _load(message: message, uncertain: uncertain);
    _loading = future;
    future.then((_) {
      if (identical(_loading, future)) _loading = null;
    });
    return future;
  }

  Future<void> _load({String? message, bool uncertain = false}) async {
    _expiry?.cancel();
    final generation = ++_generation;
    final selected = state.selected;
    var locked = uncertain || state.uncertain;
    emit(
      ContractRenewalState(
        contract: state.contract,
        loading: true,
        uncertain: locked,
        message: message,
      ),
    );
    try {
      final unresolved = await store.read(id);
      locked = locked || unresolved != null;
      final json = await repository.getContractById(id);
      if (isClosed || generation != _generation) return;
      final contract = ContractDetailData.fromJson(json, id).contract;
      final rows = (json['phuLuc'] as List).cast<Map<String, dynamic>>();
      final due = contract.effectiveReturnDate;
      Map<String, dynamic>? pending;
      for (final row in rows) {
        if (['CHO_XAC_NHAN', 'CHO_KY'].contains(row['trangThai'])) {
          pending = row;
        }
      }
      Map<String, dynamic>? selectedAppendix;
      if (appendixId == null) {
        selectedAppendix = pending ?? ExtensionSummary.latestRow(rows);
      } else {
        for (final row in rows) {
          if (row['maPhuLuc'] == appendixId) selectedAppendix = row;
        }
        if (selectedAppendix == null) {
          message =
              'Không tìm thấy yêu cầu/phụ lục được chọn trong hợp đồng này.';
        }
      }
      if (unresolved != null) {
        final matched = rows.any(
          (row) =>
              !(unresolved['knownIds'] as List).contains(row['maPhuLuc']) &&
              DateTime.parse(row['thoiHanTraMoi'] as String) ==
                  DateTime.parse(unresolved['date'] as String) &&
              row['lyDoGiaHan'] == unresolved['reason'],
        );
        if (matched) {
          await store.clear(id);
          locked = false;
          message =
              'Đã xác minh Backend ghi nhận yêu cầu gia hạn. Xem trạng thái phụ lục mới nhất.';
        } else {
          message =
              'Chưa xác định kết quả gửi yêu cầu. Không gửi lại; hãy tải lại hoặc liên hệ cửa hàng để đối soát.';
        }
      }
      if (isClosed || generation != _generation) return;
      if (contract.status != 'DANG_THUE') {
        message =
            '${message == null ? '' : '$message\n'}Trạng thái hợp đồng hiện tại không cho phép gia hạn.';
      }
      if (contract.canExtend == false && json['lyDoKhongTheGiaHan'] is String) {
        message =
            '${message == null ? '' : '$message\n'}${json['lyDoKhongTheGiaHan']}';
      }
      if (pending != null &&
          pending['trangThai'] == 'CHO_XAC_NHAN' &&
          pending['hanXuLyUtc'] == null) {
        message =
            '${message == null ? '' : '$message\n'}Hồ sơ theo quy trình cũ cần Admin kiểm tra và đóng có lý do. Hạn trả và phí chưa thay đổi.';
      }
      emit(
        ContractRenewalState(
          contract: contract,
          currentReturn: due,
          selected: selected != null && selected.isAfter(due) ? selected : null,
          pending: pending,
          selectedAppendix: selectedAppendix,
          uncertain: locked,
          message:
              selectedAppendix != null &&
                      selectedAppendix['trangThai'] == 'CHO_KY'
                  ? '${message == null ? '' : '$message\n'}Gia hạn được duyệt – Chờ ký phụ lục. Hạn trả chưa thay đổi.'
                  : selectedAppendix?['trangThai'] == 'CHO_XAC_NHAN'
                  ? '${message == null ? '' : '$message\n'}Đang chờ cửa hàng xác nhận yêu cầu gia hạn.'
                  : message,
        ),
      );
      if (selectedAppendix != null) {
        final deadline =
            ExtensionSummary.fromJson(selectedAppendix).signingDeadlineUtc;
        if (selectedAppendix['trangThai'] == 'CHO_KY' && deadline != null) {
          final remaining = deadline.difference(contract.serverNowUtc);
          if (remaining > Duration.zero) {
            _expiry = Timer(remaining, () => load());
          }
        }
      }
    } catch (error) {
      if (!isClosed && generation == _generation) {
        emit(
          ContractRenewalState(
            uncertain: locked,
            message: '${message == null ? '' : '$message\n'}$error',
          ),
        );
      }
    } finally {
      if (_reloadRequested && !isClosed && !state.submitting) {
        _reloadRequested = false;
        await _load();
      }
    }
  }

  Future<void> selectDate(DateTime day) async {
    if (!state.canSelect) return;
    final current = state.currentReturn!;
    // Preserve the API clock and timezone kind; unspecified dates stay unspecified.
    final date =
        current.isUtc
            ? DateTime.utc(
              day.year,
              day.month,
              day.day,
              current.hour,
              current.minute,
              current.second,
              current.millisecond,
              current.microsecond,
            )
            : DateTime(
              day.year,
              day.month,
              day.day,
              current.hour,
              current.minute,
              current.second,
              current.millisecond,
              current.microsecond,
            );
    final generation = ++_generation;
    final contract = state.contract;
    emit(
      ContractRenewalState(
        contract: contract,
        currentReturn: current,
        selected: date,
        previewing: date.isAfter(current),
        message:
            date.isAfter(current)
                ? null
                : 'Ngày trả mới phải sau ngày trả hiện tại.',
      ),
    );
    if (!date.isAfter(current)) return;
    try {
      final quote = await repository.previewExtension(id, date);
      if (isClosed || generation != _generation) return;
      if (quote.newReturn != date) {
        throw const FormatException('Báo giá không khớp ngày đã chọn.');
      }
      emit(
        ContractRenewalState(
          contract: contract,
          currentReturn: quote.currentReturn,
          selected: date,
          quote: quote,
          message: quote.reason,
        ),
      );
    } catch (error) {
      if (!isClosed && generation == _generation) {
        emit(
          ContractRenewalState(
            contract: contract,
            currentReturn: current,
            selected: date,
            message: error.toString(),
          ),
        );
      }
    }
  }

  Future<void> submit(String reason) async {
    if (!state.canSubmit) return;
    if (reason.trim().isEmpty || reason.trim().length > 500) return;
    final before = state;
    final generation = _generation;
    emit(
      ContractRenewalState(
        contract: before.contract,
        currentReturn: before.currentReturn,
        selected: before.selected,
        quote: before.quote,
        submitting: true,
      ),
    );
    String message;
    bool uncertain = false;
    bool posted = false;
    try {
      await store.write(id, {
        'date': before.selected!.toIso8601String(),
        'reason': reason.trim(),
        'knownIds':
            before.contract!.extensions.map((row) => row['maPhuLuc']).toList(),
      });
      posted = true;
      await repository.requestExtension(id, before.selected!, reason);
      await store.clear(id);
      message = 'Đã gửi yêu cầu gia hạn. Đang chờ cửa hàng xác nhận.';
    } catch (error) {
      uncertain = posted && (error is! ExtensionFailure || error.uncertain);
      message = error.toString();
      if (!uncertain) {
        try {
          await store.clear(id);
        } catch (_) {
          uncertain = true;
          message =
              'Không thể xác minh trạng thái lưu yêu cầu. Hãy tải lại hợp đồng để đối soát.';
        }
      }
    }
    if (isClosed || generation != _generation) return;
    emit(ContractRenewalState(contract: before.contract, uncertain: uncertain));
    // Always re-read contract and supplements; never retry POST or change due date locally.
    await load(message: message, uncertain: uncertain);
  }
}
