import 'package:equatable/equatable.dart';
import 'package:image_picker/image_picker.dart';
import '../services/identity_scanner.dart';

enum IdentityVerificationStatus {
  initial,
  loading,
  success,
  error,
  confirming,
  confirmError,
  verificationFailed,
  verificationSuccess,
}

class IdentityVerificationState extends Equatable {
  final XFile? frontImage;
  final XFile? backImage;
  final bool isConsentAccepted;
  final IdentityVerificationStatus status;
  final String? errorMessage;
  final ExtractedIdentityData? extractedData;
  final String? manuallyScannedQrData;

  const IdentityVerificationState({
    this.frontImage,
    this.backImage,
    this.isConsentAccepted = false,
    this.status = IdentityVerificationStatus.initial,
    this.errorMessage,
    this.extractedData,
    this.manuallyScannedQrData,
  });

  bool get isReadyToSubmit => isConsentAccepted;

  IdentityVerificationState copyWith({
    XFile? frontImage,
    XFile? backImage,
    bool? isConsentAccepted,
    IdentityVerificationStatus? status,
    String? errorMessage,
    ExtractedIdentityData? extractedData,
    String? manuallyScannedQrData,
    bool clearFrontImage = false,
    bool clearBackImage = false,
    bool clearExtractedData = false,
    bool clearManuallyScannedQrData = false,
  }) {
    return IdentityVerificationState(
      frontImage: clearFrontImage ? null : (frontImage ?? this.frontImage),
      backImage: clearBackImage ? null : (backImage ?? this.backImage),
      isConsentAccepted: isConsentAccepted ?? this.isConsentAccepted,
      status: status ?? this.status,
      errorMessage: errorMessage,
      extractedData: clearExtractedData ? null : (extractedData ?? this.extractedData),
      manuallyScannedQrData: clearManuallyScannedQrData ? null : (manuallyScannedQrData ?? this.manuallyScannedQrData),
    );
  }

  @override
  List<Object?> get props => [
    frontImage?.path,
    backImage?.path,
    isConsentAccepted,
    status,
    errorMessage,
    extractedData,
    manuallyScannedQrData,
  ];
}
