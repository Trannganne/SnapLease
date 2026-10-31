import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:async';
import '../../../core/storage/token_storage.dart';
import 'identity_verification_event.dart';
import 'identity_verification_state.dart';
import '../services/identity_scanner.dart';
import '../data/identity_verification_repository.dart';

class IdentityVerificationBloc
    extends Bloc<IdentityVerificationEvent, IdentityVerificationState> {
  final ImagePicker _imagePicker;
  final IdentityScanner _scanner;
  final IdentityVerificationRepository _repository;
  late final StreamSubscription<void> _sessionChange;
  bool _confirming = false;
  bool _uploadUncertain = false;
  static const int maxFileSize = 10 * 1024 * 1024; // 10MB
  String? _maGiayToCache;
  int _scanGeneration = 0;

  IdentityVerificationBloc({
    ImagePicker? imagePicker,
    IdentityScanner? scanner,
    IdentityVerificationRepository? repository,
  }) : _imagePicker = imagePicker ?? ImagePicker(),
       _scanner = scanner ?? IdentityScanner(),
       _repository = repository ?? IdentityVerificationRepository(),
       super(const IdentityVerificationState()) {
    _sessionChange = TokenStorage.willChange.listen((_) {
      _scanGeneration++;
      _maGiayToCache = null;
      ScanDebugData.clearFront();
      ScanDebugData.backImagePath = null;
      ScanDebugData.imageSize = null;
      ScanDebugData.issuerRects.clear();
      ScanDebugData.issuerTexts.clear();
      if (!isClosed) add(const _IdentitySessionChanged());
    });
    on<_IdentitySessionChanged>((event, emit) {
      _uploadUncertain = false;
      emit(const IdentityVerificationState());
    });
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
    on<LoadSavedIdentity>(_onLoadSavedIdentity);
  }

  Future<void> _onLoadSavedIdentity(
    LoadSavedIdentity event,
    Emitter<IdentityVerificationState> emit,
  ) async {
    if (_confirming || state.isLoadingProfile) return;
    final generation = ++_scanGeneration;
    final session = TokenStorage.generation;
    emit(state.copyWith(isLoadingProfile: true));
    try {
      final saved = await _repository.getSavedIdentity();
      if (generation != _scanGeneration ||
          session != TokenStorage.generation ||
          emit.isDone) {
        return;
      }
      emit(
        state.copyWith(
          isLoadingProfile: false,
          savedProfile: saved.profile,
          savedDocumentId: saved.documentId,
          savedDocumentNumber: saved.documentNumber,
          savedDocumentStatus: saved.status,
          savedDocumentHasImages: saved.hasImages,
          savedDocumentMatchesProfile: saved.matchesProfile,
        ),
      );
    } catch (_) {
      if (generation != _scanGeneration ||
          session != TokenStorage.generation ||
          emit.isDone) {
        return;
      }
      emit(
        state.copyWith(
          isLoadingProfile: false,
          profileError:
              'Không thể kiểm tra hồ sơ đã lưu. Vui lòng thử lại trước khi gửi giấy tờ.',
        ),
      );
    }
  }

  @override
  Future<void> close() {
    _scanGeneration++;
    _sessionChange.cancel();
    ScanDebugData.clearFront();
    ScanDebugData.backImagePath = null;
    ScanDebugData.issuerTexts.clear();
    _scanner.dispose();
    return super.close();
  }

  Future<void> _onPickFrontImage(
    PickFrontImage event,
    Emitter<IdentityVerificationState> emit,
  ) async {
    if (_confirming) return;
    final generation = ++_scanGeneration;
    try {
      final XFile? file = await _imagePicker.pickImage(source: event.source);
      if (generation != _scanGeneration || emit.isDone) return;
      if (file != null) {
        final length = await file.length();
        if (generation != _scanGeneration || emit.isDone) return;
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
        _maGiayToCache = null;
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
      if (generation != _scanGeneration || emit.isDone) return;
      emit(
        state.copyWith(
          status: IdentityVerificationStatus.error,
          errorMessage: 'Không thể chọn ảnh. Vui lòng thử lại.',
        ),
      );
    }
  }

  Future<void> _onPickBackImage(
    PickBackImage event,
    Emitter<IdentityVerificationState> emit,
  ) async {
    if (_confirming) return;
    final generation = ++_scanGeneration;
    try {
      final XFile? file = await _imagePicker.pickImage(source: event.source);
      if (generation != _scanGeneration || emit.isDone) return;
      if (file != null) {
        final length = await file.length();
        if (generation != _scanGeneration || emit.isDone) return;
        if (length > maxFileSize) {
          emit(
            state.copyWith(
              status: IdentityVerificationStatus.error,
              errorMessage: 'Kích thước ảnh vượt quá 10MB.',
            ),
          );
          return;
        }
        _maGiayToCache = null;
        emit(
          state.copyWith(
            backImage: file,
            status: IdentityVerificationStatus.initial, // clear error
            clearExtractedData: true,
          ),
        );
      }
    } catch (e) {
      if (generation != _scanGeneration || emit.isDone) return;
      emit(
        state.copyWith(
          status: IdentityVerificationStatus.error,
          errorMessage: 'Không thể chọn ảnh. Vui lòng thử lại.',
        ),
      );
    }
  }

  void _onSetFrontImage(
    SetFrontImage event,
    Emitter<IdentityVerificationState> emit,
  ) {
    if (_confirming) return;
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
    emit(
      state.copyWith(
        frontImage: XFile(event.path),
        status: IdentityVerificationStatus.initial,
        clearExtractedData: true,
        clearManuallyScannedQrData: true,
      ),
    );
  }

  void _onSetBackImage(
    SetBackImage event,
    Emitter<IdentityVerificationState> emit,
  ) {
    if (_confirming) return;
    _maGiayToCache = null;
    _scanGeneration++;
    emit(
      state.copyWith(
        backImage: XFile(event.path),
        status: IdentityVerificationStatus.initial,
        clearExtractedData: true,
      ),
    );
  }

  void _onRemoveFrontImage(
    RemoveFrontImage event,
    Emitter<IdentityVerificationState> emit,
  ) {
    if (_confirming) return;
    _maGiayToCache = null;
    _scanGeneration++;
    emit(
      state.copyWith(
        clearFrontImage: true,
        status: IdentityVerificationStatus.initial,
        clearExtractedData: true,
        clearManuallyScannedQrData: true,
      ),
    );
  }

  void _onRemoveBackImage(
    RemoveBackImage event,
    Emitter<IdentityVerificationState> emit,
  ) {
    if (_confirming) return;
    _maGiayToCache = null;
    _scanGeneration++;
    emit(
      state.copyWith(
        clearBackImage: true,
        status: IdentityVerificationStatus.initial,
        clearExtractedData: true,
      ),
    );
  }

  void _onToggleConsent(
    ToggleConsent event,
    Emitter<IdentityVerificationState> emit,
  ) {
    if (_confirming) return;
    emit(state.copyWith(isConsentAccepted: event.isChecked));
  }

  void _onSetManuallyScannedQr(
    SetManuallyScannedQr event,
    Emitter<IdentityVerificationState> emit,
  ) {
    if (_confirming) return;
    emit(
      state.copyWith(
        manuallyScannedQrData: event.qrData,
        status: IdentityVerificationStatus.initial,
        clearExtractedData: true,
      ),
    );
    // Immediately submit to process the new QR
    add(SubmitVerification());
  }

  Future<void> _onSubmitVerification(
    SubmitVerification event,
    Emitter<IdentityVerificationState> emit,
  ) async {
    if (_confirming || state.status == IdentityVerificationStatus.loading) {
      return;
    }
    if (!state.isReadyToSubmit ||
        state.frontImage == null ||
        state.backImage == null) {
      return;
    }

    final currentGen = ++_scanGeneration;
    emit(state.copyWith(status: IdentityVerificationStatus.loading));

    final frontFile = File(state.frontImage!.path);
    final backFile = File(state.backImage!.path);

    ExtractedIdentityData extractedData;
    try {
      extractedData = await _scanner.scanBothSides(
        frontFile,
        backFile,
        manuallyScannedQr: state.manuallyScannedQrData,
      );
    } catch (_) {
      if (currentGen != _scanGeneration || emit.isDone) return;
      emit(
        state.copyWith(
          status: IdentityVerificationStatus.error,
          errorMessage:
              'Không đọc được ảnh CCCD. Vui lòng kiểm tra quyền truy cập và chụp lại hai mặt rõ nét.',
        ),
      );
      return;
    }

    if (currentGen != _scanGeneration || emit.isDone) return;

    if (extractedData.isValid) {
      emit(
        state.copyWith(
          status: IdentityVerificationStatus.success,
          extractedData: extractedData,
        ),
      );
    } else {
      emit(
        state.copyWith(
          status: IdentityVerificationStatus.error,
          errorMessage:
              extractedData.error ?? 'Dữ liệu trích xuất không đầy đủ',
        ),
      );
    }
  }

  Future<void> _onConfirmVerification(
    ConfirmVerification event,
    Emitter<IdentityVerificationState> emit,
  ) async {
    final data = state.extractedData;
    if (state.status != IdentityVerificationStatus.success &&
        state.status != IdentityVerificationStatus.confirmError) {
      return;
    }
    if (_confirming ||
        state.isLoadingProfile ||
        state.profileError != null ||
        state.status == IdentityVerificationStatus.verificationSuccess ||
        data == null ||
        !data.isValid ||
        !state.isConsentAccepted ||
        state.frontImage == null ||
        state.backImage == null) {
      return;
    }
    if (_uploadUncertain) {
      emit(
        state.copyWith(
          status: IdentityVerificationStatus.confirmError,
          errorMessage:
              'Kết quả tải giấy tờ chưa rõ. Vui lòng quay lại Tài khoản để kiểm tra trước khi gửi lại.',
        ),
      );
      return;
    }
    _confirming = true;
    final generation = _scanGeneration;
    final session = TokenStorage.generation;
    bool current() =>
        generation == _scanGeneration &&
        session == TokenStorage.generation &&
        !TokenStorage.isChanging &&
        !emit.isDone;

    emit(state.copyWith(status: IdentityVerificationStatus.confirming));

    try {
      final token = await TokenStorage.getToken();
      if (!current()) return;
      if (token == null) {
        throw const IdentityRequestFailure('Vui lòng đăng nhập lại.');
      }
      final documentId =
          _maGiayToCache ??
          (state.savedDocumentNumber == data.cccd!.value.trim() &&
                  state.savedDocumentHasImages &&
                  state.savedDocumentStatus == 'CHO_XAC_MINH'
              ? state.savedDocumentId
              : null) ??
          await _repository.uploadIdentityDocuments(
            frontImage: state.frontImage!,
            backImage: state.backImage!,
            cccd: data.cccd!.value,
            hoTen: data.hoTen!.value,
            sessionToken: token,
          );
      if (!current()) return;
      _maGiayToCache = documentId;

      // Confirm info
      await _repository.confirmIdentity(
        maGiayTo: _maGiayToCache!,
        data: data,
        sessionToken: token,
      );

      if (!current()) return;
      // Re-read server state before reporting success or navigating.
      final saved = await _repository.getSavedIdentity(sessionToken: token);
      if (!current()) return;
      if (!saved.matchesProfile || saved.documentId != documentId) {
        throw const IdentityRequestFailure(
          'Thông tin trên máy chủ chưa khớp giấy tờ. Vui lòng mở lại hồ sơ để kiểm tra.',
        );
      }
      emit(
        state.copyWith(
          status: IdentityVerificationStatus.verificationSuccess,
          savedProfile: saved.profile,
          savedDocumentId: saved.documentId,
          savedDocumentNumber: saved.documentNumber,
          savedDocumentStatus: saved.status,
          savedDocumentHasImages: saved.hasImages,
          savedDocumentMatchesProfile: true,
        ),
      );
    } catch (e) {
      if (!current()) return;
      if (e is IdentityRequestFailure && e.uncertain) _uploadUncertain = true;
      emit(
        state.copyWith(
          status: IdentityVerificationStatus.confirmError,
          errorMessage:
              e is IdentityRequestFailure
                  ? e.message
                  : 'Không thể lưu hồ sơ. Vui lòng kiểm tra lại.',
        ),
      );
    } finally {
      _confirming = false;
    }
  }
}

class _IdentitySessionChanged extends IdentityVerificationEvent {
  const _IdentitySessionChanged();
}
