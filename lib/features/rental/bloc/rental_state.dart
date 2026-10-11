import 'package:equatable/equatable.dart';
import '../../../core/config/app_config.dart';
import '../../../domain/entities/device_detail.dart';
import '../../../domain/entities/customer_profile.dart';

class RentalState extends Equatable {
  final DeviceDetail? selectedDevice;
  final DateTime? pickupDate;
  final DateTime? returnDate;
  final String? branchId;
  final int quantity;
  final int? availableQuantity;
  final Map<String, dynamic>? priceQuote;
  final bool isChecking;
  final String? checkError;
  final bool isConfirmed;
  final bool showInsufficientDeviceDialog;
  final bool showBranchNotFoundDialog;

  // Reservation
  final String? idempotencyKey;
  final String? maGiuCho;
  final Duration? initialTimeRemaining;
  final bool isSyncingReservation;
  final bool daXacNhanThongTin;
  final bool isCreatingReservation;
  final String? reservationError;
  final bool isReservationExpired;

  final String? reservedBranchId;
  final DateTime? reservedPickupDate;
  final DateTime? reservedReturnDate;
  final int? reservedQuantity;

  // Profile
  final CustomerProfile? customerProfile;
  final bool isLoadingProfile;
  final String? profileError;

  // Contract
  final bool isCreatingContract;
  final String? contractId;
  final String? createContractError;

  const RentalState({
    this.selectedDevice,
    this.pickupDate,
    this.returnDate,
    this.branchId,
    this.quantity = 1,
    this.availableQuantity,
    this.priceQuote,
    this.isChecking = false,
    this.checkError,
    this.isConfirmed = false,
    this.showInsufficientDeviceDialog = false,
    this.showBranchNotFoundDialog = false,
    this.idempotencyKey,
    this.maGiuCho,
    this.initialTimeRemaining,
    this.isSyncingReservation = false,
    this.daXacNhanThongTin = false,
    this.isCreatingReservation = false,
    this.reservationError,
    this.isReservationExpired = false,
    this.reservedBranchId,
    this.reservedPickupDate,
    this.reservedReturnDate,
    this.reservedQuantity,
    this.customerProfile,
    this.isLoadingProfile = false,
    this.profileError,
    this.isCreatingContract = false,
    this.contractId,
    this.createContractError,
  });

  bool get isValidToRent {
    return selectedDevice != null &&
        pickupDate != null &&
        returnDate != null &&
        branchId != null &&
        quantity > 0 &&
        availableQuantity != null &&
        availableQuantity! >= quantity &&
        priceQuote != null &&
        !isChecking &&
        checkError == null;
  }

  bool get isCriteriaMatchingReservation {
    if (maGiuCho == null) return true;
    return branchId == reservedBranchId &&
        pickupDate == reservedPickupDate &&
        returnDate == reservedReturnDate &&
        quantity == reservedQuantity;
  }

  bool get isValidForDemo {
    return selectedDevice != null &&
        pickupDate != null &&
        returnDate != null &&
        branchId != null &&
        quantity > 0;
  }

  // Getters for RentalConfirmationPage compatibility
  // Must only be accessed when priceQuote != null (i.e. isValidToRent == true)
  int get rentalDays {
    if (priceQuote != null) return priceQuote!['soNgayTinhPhi'];
    if (AppConfig.enableDemoMode) {
      if (pickupDate != null && returnDate != null) {
        final diff = returnDate!.difference(pickupDate!).inDays;
        return diff > 0 ? diff : 1;
      }
      return 1;
    }
    throw StateError('Chưa có báo giá từ server');
  }

  int get dailyPrice {
    if (priceQuote != null) return (priceQuote!['giaThueNgay'] as num).toInt();
    if (AppConfig.enableDemoMode) return 500000;
    throw StateError('Chưa có báo giá từ server');
  }

  int get subtotal {
    if (priceQuote != null) return (priceQuote!['tongTienThue'] as num).toInt();
    if (AppConfig.enableDemoMode) return dailyPrice * rentalDays * quantity;
    throw StateError('Chưa có báo giá từ server');
  }

  int get discountPercent {
    if (priceQuote != null)
      return (priceQuote!['phanTramGiamGia'] as num).toInt();
    if (AppConfig.enableDemoMode) return 5;
    throw StateError('Chưa có báo giá từ server');
  }

  int get discountAmount => (subtotal * discountPercent / 100).round();
  int get rentalAfterDiscount => subtotal - discountAmount;

  int get deposit {
    if (priceQuote != null) return (priceQuote!['tongTienCoc'] as num).toInt();
    if (AppConfig.enableDemoMode) return 5000000 * quantity;
    throw StateError('Chưa có báo giá từ server');
  }

  int get totalPayment => rentalAfterDiscount + deposit;

  RentalState copyWith({
    DeviceDetail? selectedDevice,
    DateTime? pickupDate,
    DateTime? returnDate,
    String? branchId,
    int? quantity,
    int? availableQuantity,
    Map<String, dynamic>? priceQuote,
    bool? isChecking,
    String? checkError,
    bool? isConfirmed,
    String? idempotencyKey,
    String? maGiuCho,
    Duration? initialTimeRemaining,
    bool? isSyncingReservation,
    bool? daXacNhanThongTin,
    bool? isCreatingReservation,
    String? reservationError,
    bool? isReservationExpired,
    String? reservedBranchId,
    DateTime? reservedPickupDate,
    DateTime? reservedReturnDate,
    int? reservedQuantity,
    CustomerProfile? customerProfile,
    bool? isLoadingProfile,
    String? profileError,
    bool? showInsufficientDeviceDialog,
    bool? showBranchNotFoundDialog,
    bool? isCreatingContract,
    String? contractId,
    String? createContractError,
    bool clearAvailability = false,
    bool clearReservation = false,
    bool clearContract = false,
  }) {
    return RentalState(
      selectedDevice: selectedDevice ?? this.selectedDevice,
      pickupDate: pickupDate ?? this.pickupDate,
      returnDate: returnDate ?? this.returnDate,
      branchId: branchId ?? this.branchId,
      quantity: quantity ?? this.quantity,
      availableQuantity:
          clearAvailability
              ? null
              : (availableQuantity ?? this.availableQuantity),
      priceQuote: clearAvailability ? null : (priceQuote ?? this.priceQuote),
      isChecking: isChecking ?? this.isChecking,
      checkError: clearAvailability ? null : (checkError ?? this.checkError),
      isConfirmed: clearReservation ? false : (isConfirmed ?? this.isConfirmed),
      idempotencyKey: clearReservation ? null : (idempotencyKey ?? this.idempotencyKey),
      maGiuCho: clearReservation ? null : (maGiuCho ?? this.maGiuCho),
      initialTimeRemaining: clearReservation ? null : (initialTimeRemaining ?? this.initialTimeRemaining),
      isSyncingReservation: clearReservation ? false : (isSyncingReservation ?? this.isSyncingReservation),
      daXacNhanThongTin: daXacNhanThongTin ?? this.daXacNhanThongTin,
      isCreatingReservation:
          isCreatingReservation ?? this.isCreatingReservation,
      reservationError: clearReservation ? null : reservationError,
      isReservationExpired: clearReservation ? false : (isReservationExpired ?? this.isReservationExpired),
      reservedBranchId: clearReservation ? null : (reservedBranchId ?? this.reservedBranchId),
      reservedPickupDate: clearReservation ? null : (reservedPickupDate ?? this.reservedPickupDate),
      reservedReturnDate: clearReservation ? null : (reservedReturnDate ?? this.reservedReturnDate),
      reservedQuantity: clearReservation ? null : (reservedQuantity ?? this.reservedQuantity),
      customerProfile: customerProfile ?? this.customerProfile,
      isLoadingProfile: isLoadingProfile ?? this.isLoadingProfile,
      profileError: profileError,
      showInsufficientDeviceDialog: showInsufficientDeviceDialog ?? this.showInsufficientDeviceDialog,
      showBranchNotFoundDialog: showBranchNotFoundDialog ?? this.showBranchNotFoundDialog,
      isCreatingContract: isCreatingContract ?? this.isCreatingContract,
      contractId: clearContract ? null : (contractId ?? this.contractId),
      createContractError: clearContract ? null : createContractError,
    );
  }

  @override
  List<Object?> get props => [
    selectedDevice,
    pickupDate,
    returnDate,
    branchId,
    quantity,
    availableQuantity,
    priceQuote,
    isChecking,
    checkError,
    isConfirmed,
    idempotencyKey,
    maGiuCho,
    initialTimeRemaining,
    isSyncingReservation,
    daXacNhanThongTin,
    isCreatingReservation,
    reservationError,
    isReservationExpired,
    reservedBranchId,
    reservedPickupDate,
    reservedReturnDate,
    reservedQuantity,
    customerProfile,
    isLoadingProfile,
    profileError,
    showInsufficientDeviceDialog,
    showBranchNotFoundDialog,
    isCreatingContract,
    contractId,
    createContractError,
  ];
}
