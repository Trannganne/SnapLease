import 'package:equatable/equatable.dart';
import 'package:image_picker/image_picker.dart';
import '../services/identity_scanner.dart';
import '../../../domain/entities/customer_profile.dart';

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
  final bool isLoadingProfile;
  final String? profileError;
  final CustomerProfile? savedProfile;
  final String? savedDocumentId;
  final String? savedDocumentNumber;
  final String? savedDocumentStatus;
  final bool savedDocumentHasImages;
  final bool savedDocumentMatchesProfile;

  const IdentityVerificationState({
    this.frontImage,
    this.backImage,
    this.isConsentAccepted = false,
    this.status = IdentityVerificationStatus.initial,
    this.errorMessage,
    this.extractedData,
    this.manuallyScannedQrData,
    this.isLoadingProfile = false,
    this.profileError,
    this.savedProfile,
    this.savedDocumentId,
    this.savedDocumentNumber,
    this.savedDocumentStatus,
    this.savedDocumentHasImages = false,
    this.savedDocumentMatchesProfile = false,
  });

  bool get isReadyToSubmit => isConsentAccepted;

  // State contains document numbers and local photo paths; keep debug strings opaque.
  @override
  bool get stringify => false;

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
    bool? isLoadingProfile,
    String? profileError,
    CustomerProfile? savedProfile,
    String? savedDocumentId,
    String? savedDocumentNumber,
    String? savedDocumentStatus,
    bool? savedDocumentHasImages,
    bool? savedDocumentMatchesProfile,
  }) {
    return IdentityVerificationState(
      frontImage: clearFrontImage ? null : (frontImage ?? this.frontImage),
      backImage: clearBackImage ? null : (backImage ?? this.backImage),
      isConsentAccepted: isConsentAccepted ?? this.isConsentAccepted,
      status: status ?? this.status,
      errorMessage: errorMessage,
      extractedData:
          clearExtractedData ? null : (extractedData ?? this.extractedData),
      manuallyScannedQrData:
          clearManuallyScannedQrData
              ? null
              : (manuallyScannedQrData ?? this.manuallyScannedQrData),
      isLoadingProfile: isLoadingProfile ?? this.isLoadingProfile,
      profileError: profileError,
      savedProfile: savedProfile ?? this.savedProfile,
      savedDocumentId: savedDocumentId ?? this.savedDocumentId,
      savedDocumentNumber: savedDocumentNumber ?? this.savedDocumentNumber,
      savedDocumentStatus: savedDocumentStatus ?? this.savedDocumentStatus,
      savedDocumentHasImages:
          savedDocumentHasImages ?? this.savedDocumentHasImages,
      savedDocumentMatchesProfile:
          savedDocumentMatchesProfile ?? this.savedDocumentMatchesProfile,
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
    isLoadingProfile,
    profileError,
    savedProfile,
    savedDocumentId,
    savedDocumentNumber,
    savedDocumentStatus,
    savedDocumentHasImages,
    savedDocumentMatchesProfile,
  ];
}
