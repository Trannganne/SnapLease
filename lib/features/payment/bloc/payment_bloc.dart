import 'package:flutter_bloc/flutter_bloc.dart';
import 'payment_event.dart';
import 'payment_state.dart';
import '../data/payment_repository.dart';
import '../domain/models/payment_model.dart';
import '../domain/enums/payment_method.dart';

class PaymentBloc extends Bloc<PaymentEvent, PaymentState> {
  final PaymentRepository repository;

  PaymentBloc({required this.repository}) : super(PaymentInitial()) {
    on<LoadPaymentStatus>(_onLoadPaymentStatus);
    on<CreatePaymentRequested>(_onCreatePaymentRequested);
  }

  Future<void> _onLoadPaymentStatus(
    LoadPaymentStatus event,
    Emitter<PaymentState> emit,
  ) async {
    emit(PaymentLoading());
    try {
      final payments = await repository.getPayments(event.contractId);
      final activePayment = _findActiveDepositPayment(payments);
      emit(PaymentLoaded(activePayment));
    } catch (e) {
      emit(PaymentError(e.toString()));
    }
  }

  Future<void> _onCreatePaymentRequested(
    CreatePaymentRequested event,
    Emitter<PaymentState> emit,
  ) async {
    emit(PaymentCreating());
    try {
      final methodStr = event.method == PaymentMethod.online ? 'CHUYEN_KHOAN' : 'TIEN_MAT';
      final payment = await repository.createDepositPayment(event.contractId, methodStr);
      if (payment.trangThai == 'THANH_CONG') {
        emit(PaymentCreateSuccess(payment));
      } else {
        emit(PaymentCreatePending(payment));
      }
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      if (e.toString().contains('Khoản thanh toán cọc đã tồn tại')) {
        // Recovery logic on timeout / existing payment
        try {
          final payments = await repository.getPayments(event.contractId);
          final activePayment = _findActiveDepositPayment(payments);
          if (activePayment != null) {
            final methodStr = event.method == PaymentMethod.online ? 'CHUYEN_KHOAN' : 'TIEN_MAT';
            if (activePayment.phuongThuc != methodStr && activePayment.trangThai == 'CHO_THANH_TOAN') {
               emit(PaymentError('Đang có một yêu cầu thanh toán ${activePayment.phuongThuc} chờ xử lý.'));
               return;
            }
            if (activePayment.trangThai == 'THANH_CONG') {
              emit(PaymentCreateSuccess(activePayment));
            } else {
              emit(PaymentCreatePending(activePayment));
            }
            return;
          } else {
             emit(PaymentError('Lỗi dữ liệu: Báo lỗi trùng lặp nhưng không tìm thấy khoản cọc.'));
             return;
          }
        } catch (e2) {
          emit(PaymentError('Lỗi phục hồi: $e2'));
          return;
        }
      }
      
      if (errorStr.contains('timeout') || errorStr.contains('connection')) {
        emit(PaymentError('Lỗi kết nối. Trạng thái yêu cầu chưa xác định, vui lòng tải lại trang để kiểm tra.'));
        return;
      }

      emit(PaymentError(e.toString()));
    }
  }

  PaymentModel? _findActiveDepositPayment(List<PaymentModel> payments) {
    final depositPayments = payments.where((p) => p.loaiThanhToan == 'TIEN_COC').toList();
    if (depositPayments.isEmpty) return null;

    final successPayments = depositPayments.where((p) => p.trangThai == 'THANH_CONG').toList();
    if (successPayments.isNotEmpty) {
      return successPayments.first;
    }

    final pendingPayments = depositPayments.where((p) => p.trangThai == 'CHO_THANH_TOAN').toList();
    if (pendingPayments.isNotEmpty) {
      if (pendingPayments.length > 1) {
        throw Exception('Dữ liệu không hợp lệ: Tồn tại nhiều khoản cọc đang chờ.');
      }
      return pendingPayments.first;
    }

    return null;
  }
}
