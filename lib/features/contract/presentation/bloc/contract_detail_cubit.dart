import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/contract_detail_data.dart';
import '../../data/repositories/contract_repository.dart';
import 'dart:async';
import 'package:rentcam/core/storage/token_storage.dart';
import '../../../notification/data/push_service.dart';
import '../../domain/models/settlement_view.dart';
import '../../../payment/data/payment_repository.dart';
import 'package:uuid/uuid.dart';

class ContractDetailState {
  final ContractDetailData? data;
  final bool loading;
  final String? error;
  final SettlementView? settlement;
  final bool submitting;
  final bool uncertain;
  const ContractDetailState({
    this.data,
    this.loading = false,
    this.error,
    this.settlement,
    this.submitting = false,
    this.uncertain = false,
  });

  ContractDetailState settlementState({
    SettlementView? value,
    bool? loading,
    bool? submitting,
    bool? uncertain,
    String? error,
  }) => ContractDetailState(
    data: data,
    settlement: value ?? settlement,
    loading: loading ?? this.loading,
    submitting: submitting ?? this.submitting,
    uncertain: uncertain ?? this.uncertain,
    error: error,
  );
}

class ContractDetailCubit extends Cubit<ContractDetailState> {
  final String contractId;
  final ContractRepository repository;
  final bool settlementOnly;
  final PaymentRepository? _paymentRepository;
  int _sessionEpoch = 0;
  bool _readAgain = false;
  int _request = 0;
  Future<void>? _inFlight;
  StreamSubscription<void>? _session;
  StreamSubscription<void>? _push;
  ContractDetailCubit({
    required this.contractId,
    required this.repository,
    this.settlementOnly = false,
    PaymentRepository? paymentRepository,
  }) : _paymentRepository = paymentRepository,
       super(const ContractDetailState()) {
    _push = PushService.instance.updates.stream.listen(
      (_) => load(force: true),
    );
    _session = TokenStorage.changes.listen((_) {
      ++_sessionEpoch;
      ++_request;
      _inFlight = null;
      if (!isClosed) {
        emit(const ContractDetailState(error: 'Phiên đăng nhập đã thay đổi.'));
      }
    });
  }
  @override
  Future<void> close() {
    ++_request;
    _session?.cancel();
    _push?.cancel();
    return super.close();
  }

  Future<void> cancelContract() => repository.cancelContract(contractId);
  Future<List<int>> returnImage(String url) => repository.getHandoverImage(url);
  Future<ContractDetailData?> settlementReviewData() async {
    final epoch = _sessionEpoch;
    final json = await repository.getContractById(contractId);
    if (isClosed ||
        epoch != _sessionEpoch ||
        json['trangThai'] != 'HOAN_THANH') {
      return null;
    }
    return ContractDetailData.fromJson(json, contractId);
  }

  Future<void> requestCancellation(String reason) async {
    if (state.loading) return;
    final request = _request;
    emit(ContractDetailState(data: state.data, loading: true));
    try {
      await repository.requestCancellation(contractId, reason);
    } finally {
      if (!isClosed && request == _request) await load(force: true);
    }
  }

  Future<void> load({bool force = false}) {
    if (isClosed) return Future.value();
    if (_inFlight != null && (!force || settlementOnly)) {
      if (settlementOnly && force) _readAgain = true;
      return _inFlight!;
    }
    final future = _load();
    _inFlight = future;
    future.then((_) {
      if (identical(_inFlight, future)) _inFlight = null;
      if (_readAgain && !isClosed) {
        _readAgain = false;
        load();
      }
    });
    return future;
  }

  Future<void> _load() async {
    if (isClosed) return;
    if (settlementOnly) return _loadSettlement();
    final request = ++_request;
    emit(ContractDetailState(data: state.data, loading: true));
    try {
      if (contractId.trim().isEmpty) {
        throw const FormatException('Mã hợp đồng không hợp lệ');
      }
      final json = await repository.getContractById(contractId);
      if (isClosed || request != _request) return;
      SettlementView? settlement;
      if (json['quyetToan'] is Map) {
        try {
          settlement = SettlementView.fromJson(
            Map<String, dynamic>.from(json['quyetToan'] as Map),
            contractId,
          );
        } on FormatException {
          /* Optional statement cannot hide the signed contract. */
        }
      }
      emit(
        ContractDetailState(
          data: ContractDetailData.fromJson(json, contractId),
          settlement: settlement,
        ),
      );
    } catch (error) {
      if (isClosed || request != _request) return;
      emit(
        ContractDetailState(
          data: state.data,
          error: error.toString().replaceFirst(
            RegExp(r'^(Exception|FormatException): '),
            '',
          ),
        ),
      );
    }
  }

  Future<void> _loadSettlement() async {
    final request = ++_request;
    emit(state.settlementState(loading: true));
    try {
      var value = await repository.getSettlement(contractId);
      if (isClosed || request != _request) return;
      var uncertain = false;
      final pending = await repository.pendingSettlementOperation(contractId);
      if (pending != null) {
        uncertain = true;
        final result = await repository.reconcileSettlementOperation(
          contractId,
          pending['id'] as String,
          pending['kind'] as String,
        );
        if (result['daGhiNhan'] == true) {
          // The operation read waits for the writer's lock; re-read AFTER that
          // evidence rather than publishing a financial snapshot read before it.
          value = await repository.getSettlement(contractId);
        }
        if (result['daGhiNhan'] == true && pending['phase'] != 'link') {
          await repository.rememberSettlementOperation(contractId, null);
          uncertain = false;
        } else if (result['daGhiNhan'] == true &&
            pending['phase'] == 'link' &&
            result['maThanhToan'] is String) {
          final payment = await (_paymentRepository ?? PaymentRepository())
              .getPaymentById(result['maThanhToan'] as String);
          // A persisted link or terminal result proves the previous link request outcome.
          if (payment.maHopDong == contractId &&
              (payment.duongDanThanhToan != null ||
                  payment.trangThai != 'CHO_THANH_TOAN')) {
            await repository.rememberSettlementOperation(contractId, null);
            uncertain = false;
          }
        }
      }
      if (isClosed || request != _request) return;
      emit(
        state.settlementState(
          value: value,
          loading: false,
          uncertain: uncertain,
        ),
      );
    } catch (error) {
      if (isClosed || request != _request) return;
      emit(state.settlementState(loading: false, error: error.toString()));
    }
  }

  Future<void> settlementFeedback(
    String type, {
    String? paymentId,
    String? reason,
    String? feedbackId,
    String? expectedHash,
    num? expectedAmount,
    String? replySeenAt,
  }) async {
    final snapshot = state.settlement;
    if (snapshot == null ||
        snapshot.hash == null ||
        state.submitting ||
        state.uncertain) {
      return;
    }
    if (expectedHash != snapshot.hash) {
      emit(
        state.settlementState(error: 'Quyết toán đã thay đổi. Hãy xem lại.'),
      );
      return;
    }
    final epoch = _sessionEpoch;
    emit(state.settlementState(submitting: true));
    String? error;
    var uncertain = false;
    final operation = const Uuid().v4();
    try {
      await repository.rememberSettlementOperation(contractId, {
        'id': operation,
        'kind': 'QT_KHACH',
      });
      if (isClosed || epoch != _sessionEpoch) return;
      await repository.sendSettlementFeedback(
        contractId,
        hash: snapshot.hash!,
        operationId: operation,
        type: type,
        paymentId: paymentId,
        reason: reason,
        feedbackId: feedbackId,
        expectedAmount: expectedAmount,
        replySeenAt: replySeenAt,
      );
      await repository.rememberSettlementOperation(contractId, null);
    } catch (failure) {
      error = failure.toString();
      uncertain = failure is SettlementFailure && failure.uncertain;
      if (!uncertain) {
        await repository.rememberSettlementOperation(contractId, null);
      }
    }
    if (isClosed || epoch != _sessionEpoch) return;
    emit(state.settlementState(uncertain: uncertain));
    await load(force: true);
    if (!isClosed && epoch == _sessionEpoch) {
      emit(
        state.settlementState(
          submitting: false,
          uncertain: state.uncertain,
          error: uncertain && !state.uncertain ? null : error,
        ),
      );
    }
  }

  Future<String?> settlementPayment() async {
    final snapshot = state.settlement;
    if (snapshot == null ||
        snapshot.hash == null ||
        !snapshot.allows('thanhToan') ||
        state.submitting ||
        state.uncertain) {
      return null;
    }
    final epoch = _sessionEpoch;
    emit(state.settlementState(submitting: true));
    String? url;
    String? error;
    var uncertain = false;
    final operation = const Uuid().v4();
    try {
      await repository.rememberSettlementOperation(contractId, {
        'id': operation,
        'kind': 'QT_THU',
      });
      if (isClosed || epoch != _sessionEpoch) return null;
      final id = await repository.createSettlementCollection(
        contractId,
        hash: snapshot.hash!,
        operationId: operation,
      );
      if (epoch != _sessionEpoch || isClosed) return null;
      // Reuse PAY-02: a failed link request is never automatically repeated.
      await repository.rememberSettlementOperation(contractId, {
        'id': operation,
        'kind': 'QT_THU',
        'phase': 'link',
      });
      if (isClosed || epoch != _sessionEpoch) return null;
      final payment = await (_paymentRepository ?? PaymentRepository())
          .createVnpayPaymentUrl(id);
      url = payment.duongDanThanhToan;
      await repository.rememberSettlementOperation(contractId, null);
    } catch (failure) {
      error = '$failure';
      uncertain = true;
    }
    if (isClosed || epoch != _sessionEpoch) return null;
    emit(state.settlementState(uncertain: uncertain));
    await load(force: true);
    if (isClosed || epoch != _sessionEpoch) return null;
    emit(
      state.settlementState(
        submitting: false,
        uncertain: uncertain && state.uncertain,
        error: uncertain && !state.uncertain ? null : error,
      ),
    );
    return url;
  }
}
