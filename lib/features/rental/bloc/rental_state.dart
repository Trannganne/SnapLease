import 'package:equatable/equatable.dart';
import '../../../core/config/app_config.dart';
import '../../../core/formatters/rental_time_formatter.dart';
import '../../../domain/entities/device_detail.dart';
import '../../../domain/entities/customer_profile.dart';
import '../../cart/domain/models/cart_item_model.dart';

class RentalState extends Equatable {
  final List<CartItemModel> cartItems;
  final String? cartEditError;
  final bool cartEditNeedsReconciliation;
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
  final DateTime? reservationServerTime;
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
    this.cartItems = const [],
    this.cartEditError,
    this.cartEditNeedsReconciliation = false,
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
    this.reservationServerTime,
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
        branchId!.isNotEmpty &&
        RentalTimeFormatter.periodError(pickupDate, returnDate) == null &&
        quantity > 0 &&
        availableQuantity != null &&
        availableQuantity! >= quantity &&
        priceQuote != null &&
        !cartEditNeedsReconciliation &&
        !isReservationExpired &&
        !isSyncingReservation &&
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

  num get dailyPrice {
    if (priceQuote != null) return priceQuote!['giaThueNgay'] as num;
    if (AppConfig.enableDemoMode) return 500000;
    throw StateError('Chưa có báo giá từ server');
  }

  num get subtotal {
    if (priceQuote != null) return priceQuote!['tongTienThue'] as num;
    if (AppConfig.enableDemoMode) return dailyPrice * rentalDays * quantity;
    throw StateError('Chưa có báo giá từ server');
  }

  int get discountPercent {
    if (priceQuote != null) {
      return (priceQuote!['phanTramGiamGia'] as num).toInt();
    }
    if (AppConfig.enableDemoMode) return 5;
    throw StateError('Chưa có báo giá từ server');
  }

  num get discountAmount =>
      priceQuote == null ? 0 : dailyPrice * rentalDays * quantity - subtotal;
  num get rentalAfterDiscount => subtotal;

  num get deposit {
    if (priceQuote != null) return priceQuote!['tongTienCoc'] as num;
    if (AppConfig.enableDemoMode) return 5000000 * quantity;
    throw StateError('Chưa có báo giá từ server');
  }

  num get totalPayment => rentalAfterDiscount + deposit;

  RentalState copyWith({
    List<CartItemModel>? cartItems,
    String? cartEditError,
    bool? cartEditNeedsReconciliation,
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
    DateTime? reservationServerTime,
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
    bool clearBranch = false,
  }) {
    return RentalState(
      cartItems: clearReservation ? const [] : (cartItems ?? this.cartItems),
      cartEditError: cartEditError,
      cartEditNeedsReconciliation:
          clearReservation
              ? false
              : (cartEditNeedsReconciliation ??
                  this.cartEditNeedsReconciliation),
      selectedDevice: selectedDevice ?? this.selectedDevice,
      pickupDate: pickupDate ?? this.pickupDate,
      returnDate: returnDate ?? this.returnDate,
      branchId: clearBranch ? null : (branchId ?? this.branchId),
      quantity: quantity ?? this.quantity,
      availableQuantity:
          clearAvailability
              ? null
              : (availableQuantity ?? this.availableQuantity),
      priceQuote: clearAvailability ? null : (priceQuote ?? this.priceQuote),
      isChecking: isChecking ?? this.isChecking,
      checkError: clearAvailability ? null : (checkError ?? this.checkError),
      isConfirmed: clearReservation ? false : (isConfirmed ?? this.isConfirmed),
      idempotencyKey:
          clearReservation ? null : (idempotencyKey ?? this.idempotencyKey),
      maGiuCho: clearReservation ? null : (maGiuCho ?? this.maGiuCho),
      initialTimeRemaining:
          clearReservation
              ? null
              : (initialTimeRemaining ?? this.initialTimeRemaining),
      reservationServerTime:
          clearReservation
              ? null
              : (reservationServerTime ?? this.reservationServerTime),
      isSyncingReservation:
          clearReservation
              ? false
              : (isSyncingReservation ?? this.isSyncingReservation),
      daXacNhanThongTin: daXacNhanThongTin ?? this.daXacNhanThongTin,
      isCreatingReservation:
          isCreatingReservation ?? this.isCreatingReservation,
      reservationError: clearReservation ? null : reservationError,
      isReservationExpired:
          clearReservation
              ? (isReservationExpired ?? false)
              : (isReservationExpired ?? this.isReservationExpired),
      reservedBranchId:
          clearReservation ? null : (reservedBranchId ?? this.reservedBranchId),
      reservedPickupDate:
          clearReservation
              ? null
              : (reservedPickupDate ?? this.reservedPickupDate),
      reservedReturnDate:
          clearReservation
              ? null
              : (reservedReturnDate ?? this.reservedReturnDate),
      reservedQuantity:
          clearReservation ? null : (reservedQuantity ?? this.reservedQuantity),
      customerProfile: customerProfile ?? this.customerProfile,
      isLoadingProfile: isLoadingProfile ?? this.isLoadingProfile,
      profileError: profileError,
      showInsufficientDeviceDialog:
          showInsufficientDeviceDialog ?? this.showInsufficientDeviceDialog,
      showBranchNotFoundDialog:
          showBranchNotFoundDialog ?? this.showBranchNotFoundDialog,
      isCreatingContract: isCreatingContract ?? this.isCreatingContract,
      contractId: clearContract ? null : (contractId ?? this.contractId),
      createContractError: clearContract ? null : createContractError,
    );
  }

  @override
  List<Object?> get props => [
    cartItems,
    cartEditError,
    cartEditNeedsReconciliation,
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
    reservationServerTime,
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
