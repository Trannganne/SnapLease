import 'package:flutter_bloc/flutter_bloc.dart';
import 'payment_event.dart';
import 'payment_state.dart';
import '../data/payment_repository.dart';
import '../domain/models/payment_model.dart';
import '../domain/enums/payment_method.dart';

class PaymentBloc extends Bloc<PaymentEvent, PaymentState> {
  final PaymentRepository repository;
  bool _creating = false;
  int _readGeneration = 0;

  PaymentBloc({required this.repository}) : super(PaymentInitial()) {
    on<LoadPaymentStatus>(_onLoadPaymentStatus);
    on<CreatePaymentRequested>(_onCreatePaymentRequested);
    on<CheckPaymentStatus>(_onCheckPaymentStatus);
  }

  Future<void> _onLoadPaymentStatus(
    LoadPaymentStatus event,
    Emitter<PaymentState> emit,
  ) async {
    if (_creating) return;
    final generation = ++_readGeneration;
    emit(PaymentLoading());
    try {
      final payments = await repository.getPayments(event.contractId);
      if (emit.isDone || generation != _readGeneration) return;
      final activePayment = _findActiveDepositPayment(payments);
      emit(PaymentLoaded(activePayment));
    } catch (e) {
      if (emit.isDone || generation != _readGeneration) return;
      emit(PaymentError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onCreatePaymentRequested(
    CreatePaymentRequested event,
    Emitter<PaymentState> emit,
  ) async {
    if (_creating) return;
    _creating = true;
    ++_readGeneration;
    try {
      await _createPayment(event, emit);
    } finally {
      _creating = false;
    }
  }

  Future<void> _createPayment(
    CreatePaymentRequested event,
    Emitter<PaymentState> emit,
  ) async {
    emit(PaymentCreating());
    final String targetMethodStr;
    switch (event.method) {
      case PaymentMethod.vnpay:
        targetMethodStr = 'VI_DIEN_TU';
        break;
      case PaymentMethod.cashOnHandover:
        targetMethodStr = 'TIEN_MAT';
        break;
      case PaymentMethod.online:
        targetMethodStr = 'CHUYEN_KHOAN';
        break;
    }

    try {
      // 1. GET lại khoản cọc hiện có trước khi tạo
      final existingPayments = await repository.getPayments(event.contractId);
      final active = _findActiveDepositPayment(existingPayments);

      if (active != null) {
        if (active.trangThai == 'THANH_CONG') {
          emit(PaymentCreateSuccess(active));
          return;
        }
        if (active.trangThai == 'CHO_THANH_TOAN') {
          if (active.phuongThuc == targetMethodStr) {
            if (targetMethodStr == 'VI_DIEN_TU') {
              final vnpayPayment = await repository.createVnpayPaymentUrl(
                active.maThanhToan,
              );
              final paymentUrl = vnpayPayment.duongDanThanhToan;
              if (paymentUrl != null && paymentUrl.isNotEmpty) {
                emit(PaymentOpenUrl(url: paymentUrl, payment: vnpayPayment));
              }
              emit(PaymentCreatePending(vnpayPayment));
              return;
            } else {
              emit(PaymentCreatePending(active));
              return;
            }
          } else {
            final methodLabel =
                active.phuongThuc == 'TIEN_MAT'
                    ? 'Tiền mặt'
                    : (active.phuongThuc == 'VI_DIEN_TU'
                        ? 'VNPAY'
                        : 'Chuyển khoản BIDV');
            emit(
              PaymentError(
                'Hợp đồng đã có khoản cọc bằng phương thức $methodLabel đang chờ xử lý.',
              ),
            );
            return;
          }
        }
      }

      // 2. Tạo giao dịch mới nếu chưa có
      final payment = await repository.createDepositPayment(
        event.contractId,
        targetMethodStr,
      );
      if (payment.trangThai == 'THANH_CONG') {
        emit(PaymentCreateSuccess(payment));
        return;
      }

      if (targetMethodStr == 'VI_DIEN_TU') {
        final vnpayPayment = await repository.createVnpayPaymentUrl(
          payment.maThanhToan,
        );
        final paymentUrl = vnpayPayment.duongDanThanhToan;
        if (paymentUrl != null && paymentUrl.isNotEmpty) {
          emit(PaymentOpenUrl(url: paymentUrl, payment: vnpayPayment));
        }
        emit(PaymentCreatePending(vnpayPayment));
      } else {
        emit(PaymentCreatePending(payment));
      }
    } catch (e) {
      final errorStr = e.toString().toLowerCase();

      // Phục hồi khi xung đột (409) hoặc lỗi mạng/timeout
      if (e is PaymentRequestUncertain ||
          e.toString().contains('Khoản thanh toán cọc đã tồn tại') ||
          errorStr.contains('timeout') ||
          errorStr.contains('connection')) {
        try {
          final recoveryPayments = await repository.getPayments(
            event.contractId,
          );
          final recovered = _findActiveDepositPayment(recoveryPayments);
          if (recovered != null) {
            if (recovered.trangThai == 'THANH_CONG') {
              emit(PaymentCreateSuccess(recovered));
              return;
            }
            if (recovered.phuongThuc == targetMethodStr &&
                recovered.trangThai == 'CHO_THANH_TOAN') {
              // A read can recover the payment ID, but cannot resolve a timed-out
              // link request. Stop here rather than POST/open the gateway again.
              emit(PaymentCreatePending(recovered));
              if (targetMethodStr == 'VI_DIEN_TU') {
                emit(
                  const PaymentError(
                    'Chưa xác định kết quả yêu cầu VNPAY. Vui lòng kiểm tra trạng thái; không thanh toán lại khoản này.',
                  ),
                );
              }
              return;
            } else if (recovered.trangThai == 'CHO_THANH_TOAN') {
              final label =
                  recovered.phuongThuc == 'TIEN_MAT'
                      ? 'Tiền mặt'
                      : (recovered.phuongThuc == 'VI_DIEN_TU'
                          ? 'VNPAY'
                          : 'Chuyển khoản BIDV');
              emit(
                PaymentError(
                  'Đang có một yêu cầu thanh toán $label chờ xử lý.',
                ),
              );
              return;
            }
          } else if (e is PaymentRequestUncertain ||
              errorStr.contains('timeout') ||
              errorStr.contains('connection')) {
            emit(
              const PaymentError(
                'Chưa xác định trạng thái giao dịch do lỗi kết nối. Vui lòng tải lại trang để kiểm tra.',
              ),
            );
            return;
          } else {
            emit(
              const PaymentError(
                'Lỗi dữ liệu: Báo lỗi tồn tại nhưng không tìm thấy khoản cọc.',
              ),
            );
            return;
          }
        } catch (_) {
          emit(
            const PaymentError(
              'Chưa xác định trạng thái giao dịch. Vui lòng tải lại trang để kiểm tra.',
            ),
          );
          return;
        }
      }

      emit(PaymentError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onCheckPaymentStatus(
    CheckPaymentStatus event,
    Emitter<PaymentState> emit,
  ) async {
    if (_creating) return;
    final generation = ++_readGeneration;
    emit(PaymentChecking());
    try {
      PaymentModel? payment;
      if (event.paymentId != null && event.paymentId!.isNotEmpty) {
        payment = await repository.getPaymentById(event.paymentId!);
      } else {
        final payments = await repository.getPayments(event.contractId);
        payment = _findActiveDepositPayment(payments);
      }

      if (payment == null) {
        if (emit.isDone || generation != _readGeneration) return;
        emit(const PaymentError('Không tìm thấy thông tin giao dịch cọc.'));
        return;
      }

      if (payment.maHopDong != event.contractId ||
          payment.loaiThanhToan != 'TIEN_COC') {
        throw StateError('Khoản thanh toán không khớp tiền cọc của hợp đồng.');
      }

      if (payment.trangThai == 'CHO_THANH_TOAN' &&
          payment.nhaCungCap == 'VNPAY') {
        payment = await repository.reconcileVnpayPayment(payment.maThanhToan);
      }

      if (emit.isDone || generation != _readGeneration) return;

      if (payment.trangThai == 'THANH_CONG') {
        emit(PaymentCreateSuccess(payment));
      } else if (payment.lastVnpayAttemptFailed) {
        emit(
          const PaymentError(
            'Yêu cầu VNPAY vừa đối soát đã bị hủy hoặc không thành công. Khoản cọc chưa được thanh toán.',
          ),
        );
      } else if (payment.trangThai == 'CHO_THANH_TOAN') {
        final String message =
            payment.phuongThuc == 'VI_DIEN_TU'
                ? 'Chưa xác minh được kết quả từ VNPAY. Vui lòng kiểm tra lại; không thanh toán lại khoản này.'
                : 'Đang chờ cửa hàng xác nhận. Vui lòng không thực hiện lại nếu bạn đã thanh toán.';
        emit(
          PaymentStatusChecked(
            payment: payment,
            message: message,
            isStillPending: true,
          ),
        );
      } else if (payment.trangThai == 'THAT_BAI') {
        emit(
          const PaymentError(
            'Giao dịch cọc thanh toán không thành công hoặc đã bị hủy.',
          ),
        );
      } else {
        emit(PaymentError('Giao dịch cọc ở trạng thái: ${payment.trangThai}.'));
      }
    } catch (e) {
      if (emit.isDone || generation != _readGeneration) return;
      emit(
        PaymentError(
          'Lỗi kết nối khi kiểm tra trạng thái: ${e.toString().replaceAll('Exception: ', '')}',
        ),
      );
    }
  }

  PaymentModel? _findActiveDepositPayment(List<PaymentModel> payments) {
    final depositPayments =
        payments.where((p) => p.loaiThanhToan == 'TIEN_COC').toList();
    if (depositPayments.isEmpty) return null;

    final successPayments =
        depositPayments.where((p) => p.trangThai == 'THANH_CONG').toList();
    if (successPayments.isNotEmpty) {
      return successPayments.first;
    }

    final pendingPayments =
        depositPayments.where((p) => p.trangThai == 'CHO_THANH_TOAN').toList();
    if (pendingPayments.isNotEmpty) {
      if (pendingPayments.length > 1) {
        throw Exception(
          'Dữ liệu mâu thuẫn: Tồn tại nhiều khoản cọc đang chờ xử lý.',
        );
      }
      return pendingPayments.first;
    }

    return null;
  }
}
