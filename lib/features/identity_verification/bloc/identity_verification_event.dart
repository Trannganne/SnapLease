import 'package:equatable/equatable.dart';
import 'package:image_picker/image_picker.dart';

abstract class IdentityVerificationEvent extends Equatable {
  const IdentityVerificationEvent();

  @override
  List<Object?> get props => [];
}

class LoadSavedIdentity extends IdentityVerificationEvent {
  const LoadSavedIdentity();
}

class PickFrontImage extends IdentityVerificationEvent {
  final ImageSource source;
  const PickFrontImage(this.source);

  @override
  List<Object?> get props => [source];
}

class PickBackImage extends IdentityVerificationEvent {
  final ImageSource source;
  const PickBackImage(this.source);

  @override
  List<Object?> get props => [source];
}

class RemoveFrontImage extends IdentityVerificationEvent {}

class RemoveBackImage extends IdentityVerificationEvent {}

class ToggleConsent extends IdentityVerificationEvent {
  final bool isChecked;
  const ToggleConsent(this.isChecked);

  @override
  List<Object?> get props => [isChecked];
}

class SubmitVerification extends IdentityVerificationEvent {}

class ConfirmVerification extends IdentityVerificationEvent {}

class SetFrontImage extends IdentityVerificationEvent {
  final String path;
  const SetFrontImage(this.path);

  @override
  List<Object?> get props => [path];
}

class SetBackImage extends IdentityVerificationEvent {
  final String path;
  const SetBackImage(this.path);

  @override
  List<Object?> get props => [path];
}

class SetManuallyScannedQr extends IdentityVerificationEvent {
  final String qrData;
  const SetManuallyScannedQr(this.qrData);

  @override
  List<Object?> get props => [qrData];
}
