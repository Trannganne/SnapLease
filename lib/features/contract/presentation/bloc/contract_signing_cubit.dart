import 'dart:typed_data';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/contract_signing_repository.dart';
import '../../services/contract_pdf_service.dart';
import 'contract_signing_state.dart';

class ContractSigningCubit extends Cubit<ContractSigningState> {
  final ContractSigningRepository _repository;

  ContractSigningCubit(this._repository) : super(ContractSigningInitial());

  Future<void> requestOtp(ContractModel contract, Uint8List pdfBytes, bool daDongYDieuKhoan) async {
    emit(ContractSigningLoading());
    try {
      final result = await _repository.uploadPdfAndRequestOtp(contract, pdfBytes, daDongYDieuKhoan);
      
      emit(ContractSigningOtpSent(
        maXacNhan: result.maXacNhan,
        emailMask: result.emailMask,
        expiredAt: result.expiredAt,
      ));
    } catch (e) {
      emit(ContractSigningFailure(e.toString()));
    }
  }

  Future<void> verifyOtp(ContractModel contract, String maXacNhan, String otp, String emailMask, DateTime expiredAt, bool daDongYDieuKhoan) async {
    emit(ContractSigningOtpVerifying(maXacNhan: maXacNhan, emailMask: emailMask, expiredAt: expiredAt));
    try {
      final updatedContract = await _repository.verifyOtp(contract, maXacNhan, otp, daDongYDieuKhoan);
      emit(ContractSigningSuccess(updatedContract));
    } catch (e) {
      emit(ContractSigningFailure(e.toString()));
    }
  }
}
