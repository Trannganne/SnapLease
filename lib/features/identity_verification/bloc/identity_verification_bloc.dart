import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'identity_verification_event.dart';
import 'identity_verification_state.dart';
import '../services/identity_scanner.dart';
import '../data/identity_verification_repository.dart';

class IdentityVerificationBloc
    extends Bloc<IdentityVerificationEvent, IdentityVerificationState> {
  final ImagePicker _imagePicker = ImagePicker();
  final IdentityScanner _scanner = IdentityScanner();
  final IdentityVerificationRepository _repository = IdentityVerificationRepository();
  static const int maxFileSize = 10 * 1024 * 1024; // 10MB
  String? _maGiayToCache;
  int _scanGeneration = 0;

  IdentityVerificationBloc() : super(const IdentityVerificationState()) {
    on<PickFrontImage>(_onPickFrontImage);
    on<PickBackImage>(_onPickBackImage);
    on<RemoveFrontImage>(_onRemoveFrontImage);
    on<RemoveBackImage>(_onRemoveBackImage);
    on<ToggleConsent>(_onToggleConsent);
    on<SubmitVerification>(_onSubmitVerification);
    on<ConfirmVerification>(_onConfirmVerification);
    on<SetFrontImage>(_onSetFrontImage);
    on<SetBackImage>(_onSetBackImage);
    on<SetManuallyScannedQr>(_onSetManuallyScannedQr);
  }

  @override
  Future<void> close() {
    _scanner.dispose();
    return super.close();
  }

  Future<void> _onPickFrontImage(
    PickFrontImage event,
    Emitter<IdentityVerificationState> emit,
  ) async {
    _maGiayToCache = null;
    _scanGeneration++;
    try {
      final XFile? file = await _imagePicker.pickImage(source: event.source);
      if (file != null) {
        final length = await file.length();
        if (length > maxFileSize) {
          emit(
            state.copyWith(
              status: IdentityVerificationStatus.error,
              errorMessage: 'Kích thước ảnh vượt quá 10MB.',
            ),
          );
          return;
        }
        if (ScanDebugData.enableDebug) {
          ScanDebugData.clearFront();
          ScanDebugData.frontImagePath = file.path;
          _scanner.getOrCreateQrFallbackCrop(File(file.path));
        }

        emit(
          state.copyWith(
            frontImage: file,
            status: IdentityVerificationStatus.initial, // clear error
            clearExtractedData: true,
            clearManuallyScannedQrData: true,
          ),
        );
      }
    } catch (e) {
      emit(
        state.copyWith(
          status: IdentityVerificationStatus.error,
          errorMessage: 'Lỗi khi chọn ảnh: $e',
        ),
      );
    }
  }

  Future<void> _onPickBackImage(
    PickBackImage event,
    Emitter<IdentityVerificationState> emit,
  ) async {
    _maGiayToCache = null;
    _scanGeneration++;
    try {
      final XFile? file = await _imagePicker.pickImage(source: event.source);
      if (file != null) {
        final length = await file.length();
        if (length > maxFileSize) {
          emit(
            state.copyWith(
              status: IdentityVerificationStatus.error,
              errorMessage: 'Kích thước ảnh vượt quá 10MB.',
            ),
          );
          return;
        }
        emit(
          state.copyWith(
            backImage: file,
            status: IdentityVerificationStatus.initial, // clear error
            clearExtractedData: true,
          ),
        );
      }
    } catch (e) {
      emit(
        state.copyWith(
          status: IdentityVerificationStatus.error,
          errorMessage: 'Lỗi khi chọn ảnh: $e',
        ),
      );
    }
  }

  void _onSetFrontImage(
    SetFrontImage event,
    Emitter<IdentityVerificationState> emit,
  ) {
    _scanGeneration++;
    
    if (ScanDebugData.enableDebug) {
      // Don't call clearFront() here because CustomCameraPage just set rawCapturedImagePath and cropRect!
      // But we need to reset the scanned state and barcode results.
      ScanDebugData.barcodeCount = -1;
      ScanDebugData.barcodeTypes.clear();
      ScanDebugData.hasRawValue = false;
      ScanDebugData.qrException = null;
      ScanDebugData.barcodeDiagnostic = null;
      ScanDebugData.isScanned = false;
      ScanDebugData.fallbackImagePath = null;
      ScanDebugData.frontImageSize = null;
      ScanDebugData.fallbackCropRect = null;
      
      ScanDebugData.frontImagePath = event.path;
      _scanner.getOrCreateQrFallbackCrop(File(event.path));
    }

    _maGiayToCache = null;
    emit(state.copyWith(
      frontImage: XFile(event.path),
      status: IdentityVerificationStatus.initial,
      clearExtractedData: true,
      clearManuallyScannedQrData: true,
    ));
  }

  void _onSetBackImage(
    SetBackImage event,
    Emitter<IdentityVerificationState> emit,
  ) {
    _maGiayToCache = null;
    _scanGeneration++;
    emit(state.copyWith(
      backImage: XFile(event.path),
      status: IdentityVerificationStatus.initial,
      clearExtractedData: true,
    ));
  }

  void _onRemoveFrontImage(
    RemoveFrontImage event,
    Emitter<IdentityVerificationState> emit,
  ) {
    _maGiayToCache = null;
    _scanGeneration++;
    emit(state.copyWith(
      clearFrontImage: true,
      status: IdentityVerificationStatus.initial,
      clearExtractedData: true,
      clearManuallyScannedQrData: true,
    ));
  }

  void _onRemoveBackImage(
    RemoveBackImage event,
    Emitter<IdentityVerificationState> emit,
  ) {
    _maGiayToCache = null;
    _scanGeneration++;
    emit(state.copyWith(
      clearBackImage: true,
      status: IdentityVerificationStatus.initial,
      clearExtractedData: true,
    ));
  }

  void _onToggleConsent(
    ToggleConsent event,
    Emitter<IdentityVerificationState> emit,
  ) {
    emit(state.copyWith(isConsentAccepted: event.isChecked));
  }

  void _onSetManuallyScannedQr(
    SetManuallyScannedQr event,
    Emitter<IdentityVerificationState> emit,
  ) {
    emit(state.copyWith(
      manuallyScannedQrData: event.qrData,
      status: IdentityVerificationStatus.initial,
      clearExtractedData: true,
    ));
    // Immediately submit to process the new QR
    add(SubmitVerification());
  }

  Future<void> _onSubmitVerification(
    SubmitVerification event,
    Emitter<IdentityVerificationState> emit,
  ) async {
    if (!state.isReadyToSubmit || state.frontImage == null || state.backImage == null) return;

    final currentGen = ++_scanGeneration;
    emit(state.copyWith(status: IdentityVerificationStatus.loading));

    final frontFile = File(state.frontImage!.path);
    final backFile = File(state.backImage!.path);
    
    final extractedData = await _scanner.scanBothSides(
      frontFile, 
      backFile, 
      manuallyScannedQr: state.manuallyScannedQrData,
    );

    if (currentGen != _scanGeneration) return;

    if (extractedData.isValid) {
      emit(state.copyWith(
        status: IdentityVerificationStatus.success,
        extractedData: extractedData,
      ));
    } else {
      emit(state.copyWith(
        status: IdentityVerificationStatus.error,
        errorMessage: extractedData.error ?? 'Dữ liệu trích xuất không đầy đủ',
      ));
    }
  }

  Future<void> _onConfirmVerification(
    ConfirmVerification event,
    Emitter<IdentityVerificationState> emit,
  ) async {
    final data = state.extractedData;
    if (data == null || !data.isValid) return;

    emit(state.copyWith(status: IdentityVerificationStatus.confirming));

    try {
      _maGiayToCache ??= await _repository.uploadIdentityDocuments(
        frontImage: state.frontImage!,
        backImage: state.backImage!,
        cccd: data.cccd!.value,
        hoTen: data.hoTen!.value,
      );

      // Confirm info
      await _repository.confirmIdentity(
        maGiayTo: _maGiayToCache!,
        data: data,
      );

      emit(state.copyWith(status: IdentityVerificationStatus.verificationSuccess));
    } catch (e) {
      emit(state.copyWith(
        status: IdentityVerificationStatus.confirmError,
        errorMessage: e.toString(),
      ));
    }
  }
}
