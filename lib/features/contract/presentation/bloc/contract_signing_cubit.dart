import 'dart:typed_data';
import 'dart:async';
import '../../../../core/storage/token_storage.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/contract_signing_repository.dart';
import '../../services/contract_pdf_service.dart';
import 'contract_signing_state.dart';

class ContractSigningCubit extends Cubit<ContractSigningState> {
  final ContractSigningRepository _repository;
  int _generation = 0;
  StreamSubscription<void>? _session;

  ContractSigningCubit(this._repository) : super(ContractSigningInitial()) {
    _session = TokenStorage.changes.listen((_) {
      ++_generation;
      if (!isClosed) {
        emit(const ContractSigningFailure('Phiên đăng nhập đã thay đổi.'));
      }
    });
  }
  @override
  Future<void> close() {
    ++_generation;
    _session?.cancel();
    return super.close();
  }

  Future<void> requestOtp(
    ContractModel contract,
    Uint8List pdfBytes,
    bool daDongYDieuKhoan,
  ) async {
    if (state is ContractSigningLoading ||
        state is ContractSigningOtpVerifying ||
        isClosed) {
      return;
    }
    final generation = _generation;
    emit(ContractSigningLoading());
    try {
      final result = await _repository.uploadPdfAndRequestOtp(
        contract,
        pdfBytes,
        daDongYDieuKhoan,
      );
      if (isClosed || generation != _generation) return;

      emit(
        ContractSigningOtpSent(
          maXacNhan: result.maXacNhan,
          emailMask: result.emailMask,
          expiredAt: result.expiredAt,
        ),
      );
    } catch (e) {
      if (isClosed || generation != _generation) return;
      emit(ContractSigningFailure(e.toString()));
    }
  }

  Future<void> verifyOtp(
    ContractModel contract,
    String maXacNhan,
    String otp,
    String emailMask,
    DateTime expiredAt,
    bool daDongYDieuKhoan,
  ) async {
    if (state is ContractSigningLoading ||
        state is ContractSigningOtpVerifying ||
        isClosed) {
      return;
    }
    final generation = _generation;
    emit(
      ContractSigningOtpVerifying(
        maXacNhan: maXacNhan,
        emailMask: emailMask,
        expiredAt: expiredAt,
      ),
    );
    try {
      final updatedContract = await _repository.verifyOtp(
        contract,
        maXacNhan,
        otp,
        daDongYDieuKhoan,
      );
      if (isClosed || generation != _generation) return;
      emit(ContractSigningSuccess(updatedContract));
    } catch (e) {
      if (isClosed || generation != _generation) return;
      emit(ContractSigningFailure(e.toString()));
    }
  }
}
