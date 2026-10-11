import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'rental_event.dart';
import 'rental_state.dart';
import '../../device_detail/data/device_detail_repository.dart';
import '../../identity_verification/data/identity_verification_repository.dart';

export 'rental_event.dart';
export 'rental_state.dart';

class RentalBloc extends Bloc<RentalEvent, RentalState> {
  final DeviceDetailRepository _repository = DeviceDetailRepository();
  final IdentityVerificationRepository _identityRepository = IdentityVerificationRepository();
  final Stopwatch reservationStopwatch = Stopwatch();

  RentalBloc() : super(const RentalState()) {
    on<InitializeRental>(_onInitializeRental);
    on<UpdateRentalPeriod>(_onUpdateRentalPeriod);
    on<UpdateRentalBranch>(_onUpdateRentalBranch);
    on<ToggleConfirmation>(_onToggleConfirmation);
    on<UpdateQuantity>(_onUpdateQuantity);
    on<FetchAvailabilityAndQuote>(_onFetchAvailabilityAndQuote);
    on<CreateContract>(_onCreateContract);
    on<CreateReservation>(_onCreateReservation);
    on<CancelReservation>(_onCancelReservation);
    on<CheckReservationStatus>(_onCheckReservationStatus);
    on<FetchActiveReservation>(_onFetchActiveReservation);
    on<ClearRentalState>(_onClearRentalState);
    on<ClearRentalSession>(_onClearRentalSession);
    on<LoadCustomerProfile>(_onLoadCustomerProfile);
  }

  Future<void> _onLoadCustomerProfile(
    LoadCustomerProfile event,
    Emitter<RentalState> emit,
  ) async {
    emit(state.copyWith(isLoadingProfile: true, profileError: null));
    try {
      final profile = await _identityRepository.getCustomerProfile();
      emit(state.copyWith(isLoadingProfile: false, customerProfile: profile));
    } catch (e) {
      emit(state.copyWith(isLoadingProfile: false, profileError: e.toString()));
    }
  }

  void _onClearRentalState(
    ClearRentalState event,
    Emitter<RentalState> emit,
  ) {
    reservationStopwatch.stop();
    reservationStopwatch.reset();
    emit(const RentalState());
  }

  Future<void> _onClearRentalSession(
    ClearRentalSession event,
    Emitter<RentalState> emit,
  ) async {
    reservationStopwatch.stop();
    reservationStopwatch.reset();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('persistedMaGiuCho');
    emit(state.copyWith(
      clearReservation: true,
      clearContract: true,
    ));
  }

  void _onToggleConfirmation(
    ToggleConfirmation event,
    Emitter<RentalState> emit,
  ) {
    emit(state.copyWith(isConfirmed: event.isConfirmed));
  }

  void _onInitializeRental(InitializeRental event, Emitter<RentalState> emit) {
    if (state.selectedDevice?.id != event.device.id) {
      emit(
        RentalState(
          selectedDevice: event.device,
          pickupDate: null,
          returnDate: null,
          quantity: 1,
          branchId:
              event.device.branches.isNotEmpty
                  ? event.device.branches.first.branchId
                  : null,
          isConfirmed: state.isConfirmed,
        ),
      );
    } else {
      emit(state.copyWith(selectedDevice: event.device));
    }
  }

  void _onUpdateRentalPeriod(
    UpdateRentalPeriod event,
    Emitter<RentalState> emit,
  ) {
    DateTime newPickup = event.pickupDate;
    DateTime newReturn =
        event.returnDate ??
        state.returnDate ??
        newPickup.add(const Duration(days: 1));

    if (event.returnDate == null) {
      if (newReturn.isBefore(newPickup) ||
          newReturn.isAtSameMomentAs(newPickup)) {
        newReturn = newPickup.add(const Duration(days: 1));
      }
    }

    emit(state.copyWith(pickupDate: newPickup, returnDate: newReturn, clearAvailability: true));
    add(const FetchAvailabilityAndQuote());
  }

  void _onUpdateRentalBranch(
    UpdateRentalBranch event,
    Emitter<RentalState> emit,
  ) {
    emit(state.copyWith(branchId: event.branchId, clearAvailability: true));
    add(const FetchAvailabilityAndQuote());
  }

  void _onUpdateQuantity(
    UpdateQuantity event,
    Emitter<RentalState> emit,
  ) {
    if (event.quantity < 1) return;
    emit(state.copyWith(quantity: event.quantity, clearAvailability: true));
    add(const FetchAvailabilityAndQuote());
  }

  Future<void> _onFetchAvailabilityAndQuote(
    FetchAvailabilityAndQuote event,
    Emitter<RentalState> emit,
  ) async {
    if (state.isChecking) return; // Bảo vệ request cập nhật liên tiếp
    if (state.selectedDevice == null ||
        state.branchId == null ||
        state.pickupDate == null ||
        state.returnDate == null) {
      return;
    }

    emit(state.copyWith(
      isChecking: true, 
      clearAvailability: true,
      showInsufficientDeviceDialog: false,
      showBranchNotFoundDialog: false,
    ));

    try {
      if (state.maGiuCho != null) {
        // Cập nhật giữ chỗ hiện tại
        final result = await _repository.updateReservation(
          maGiuCho: state.maGiuCho!,
          maCuaHang: state.branchId!,
          maDongMay: state.selectedDevice!.id,
          soLuong: state.quantity,
          ngayBatDau: state.pickupDate!,
          ngayKetThuc: state.returnDate!,
        );

        final quote = result['quote'];
        emit(state.copyWith(
          isChecking: false,
          availableQuantity: state.quantity, // Đã giữ được thì coi như có đủ số lượng
          priceQuote: quote,
          reservedBranchId: state.branchId,
          reservedPickupDate: state.pickupDate,
          reservedReturnDate: state.returnDate,
          reservedQuantity: state.quantity,
          isConfirmed: false, // Force check box again after changing
        ));
      } else {
        // Luồng thông thường (chưa tạo giữ chỗ)
        final available = await _repository.checkAvailability(
          state.branchId!,
          state.selectedDevice!.id,
          state.pickupDate!,
          state.returnDate!,
        );

        final quote = await _repository.getPriceQuote(
          state.branchId!,
          state.selectedDevice!.id,
          state.quantity,
          state.pickupDate!,
          state.returnDate!,
        );

        emit(state.copyWith(
          isChecking: false,
          availableQuantity: available,
          priceQuote: quote,
        ));
      }
    } catch (e) {
      String errorMessage = e.toString();
      if (errorMessage.startsWith('Exception: ')) {
        errorMessage = errorMessage.substring('Exception: '.length);
      }
      
      if (state.maGiuCho != null) {
        if (errorMessage.contains('[INSUFFICIENT_DEVICES]')) {
          // Báo hiệu hiện dialog thiếu máy, không xóa error vì ta sẽ revert data
          // Khôi phục lại trạng thái hợp lệ đã giữ chỗ ban đầu
          emit(state.copyWith(
            isChecking: false,
            showInsufficientDeviceDialog: true,
            checkError: null,
            branchId: state.reservedBranchId,
            pickupDate: state.reservedPickupDate,
            returnDate: state.reservedReturnDate,
            quantity: state.reservedQuantity ?? state.quantity,
          ));
          return;
        }

        if (errorMessage.contains('[BRANCH_NOT_FOUND]')) {
          emit(state.copyWith(
            isChecking: false,
            showBranchNotFoundDialog: true,
            checkError: null,
            branchId: state.reservedBranchId,
            pickupDate: state.reservedPickupDate,
            returnDate: state.reservedReturnDate,
            quantity: state.reservedQuantity ?? state.quantity,
          ));
          return;
        }

        try {
          // Với timeout/lỗi mạng, GET lại đúng lượt để xác định Backend đã cập nhật hay chưa
          final actualHold = await _repository.getReservationStatus(state.maGiuCho!);
          final actualBranchId = actualHold['maCuaHang'] as String?;
          final chiTiet = (actualHold['chiTiet'] as List?)?.first;
          final actualPickup = chiTiet?['ngayBatDau'] != null ? DateTime.parse(chiTiet!['ngayBatDau'] as String).toLocal() : null;
          final actualReturn = chiTiet?['ngayKetThuc'] != null ? DateTime.parse(chiTiet!['ngayKetThuc'] as String).toLocal() : null;
          final actualQuantity = chiTiet?['soLuong'] as int?;

          // Nếu Backend đã cập nhật thành công (do timeout lúc nhận response)
          if (actualBranchId == state.branchId &&
              actualPickup != null && actualPickup.isAtSameMomentAs(state.pickupDate!) &&
              actualReturn != null && actualReturn.isAtSameMomentAs(state.returnDate!) &&
              actualQuantity == state.quantity) {
              
            // Lấy lại quote vì GET không trả về quote
            final quote = await _repository.getPriceQuote(
              state.branchId!,
              state.selectedDevice!.id,
              state.quantity,
              state.pickupDate!,
              state.returnDate!,
            );

            emit(state.copyWith(
              isChecking: false,
              availableQuantity: state.quantity,
              priceQuote: quote,
              reservedBranchId: state.branchId,
              reservedPickupDate: state.pickupDate,
              reservedReturnDate: state.returnDate,
              reservedQuantity: state.quantity,
              isConfirmed: false,
            ));
            return;
          } else {
            // Backend chưa cập nhật, cập nhật state với giá trị thực tế từ server
            emit(state.copyWith(
              isChecking: false,
              checkError: errorMessage,
              branchId: actualBranchId ?? state.reservedBranchId,
              pickupDate: actualPickup ?? state.reservedPickupDate,
              returnDate: actualReturn ?? state.reservedReturnDate,
              quantity: actualQuantity ?? state.reservedQuantity ?? state.quantity,
            ));
            return;
          }
        } catch (fetchError) {
          // Lỗi khi GET lại (có thể do đứt mạng hẳn), phục hồi UI về giá trị an toàn đã lưu
          emit(state.copyWith(
            isChecking: false,
            checkError: errorMessage,
            branchId: state.reservedBranchId,
            pickupDate: state.reservedPickupDate,
            returnDate: state.reservedReturnDate,
            quantity: state.reservedQuantity ?? state.quantity,
          ));
          return;
        }
      } else {
        emit(state.copyWith(
          isChecking: false,
          checkError: errorMessage,
        ));
      }
    }
  }

  Future<void> _onCreateReservation(
    CreateReservation event,
    Emitter<RentalState> emit,
  ) async {
    if (!state.isValidToRent) return;
    
    emit(state.copyWith(isCreatingReservation: true, reservationError: null));
    try {
      // Generate idempotencyKey if null
      final idempotencyKey = state.idempotencyKey ?? const Uuid().v4();
      
      final result = await _repository.createReservation(
        maCuaHang: state.branchId!,
        maDongMay: state.selectedDevice!.id,
        soLuong: state.quantity,
        ngayBatDau: state.pickupDate!,
        ngayKetThuc: state.returnDate!,
        idempotencyKey: idempotencyKey,
      );

      final hetHanLucApi = DateTime.parse(result['hetHanLuc']);
      final thoiGianServerApi = DateTime.parse(result['thoiGianServer']);
      final timeRemaining = hetHanLucApi.difference(thoiGianServerApi);

      reservationStopwatch.reset();
      reservationStopwatch.start();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('persistedMaGiuCho', result['maGiuCho']);

      emit(state.copyWith(
        isCreatingReservation: false,
        idempotencyKey: idempotencyKey,
        maGiuCho: result['maGiuCho'],
        initialTimeRemaining: timeRemaining,
        daXacNhanThongTin: result['daXacNhanThongTin'] ?? false,
        reservedBranchId: state.branchId,
        reservedPickupDate: state.pickupDate,
        reservedReturnDate: state.returnDate,
        reservedQuantity: state.quantity,
      ));
    } catch (e) {
      String errorMessage = e.toString();
      if (errorMessage.startsWith('Exception: ')) {
        errorMessage = errorMessage.substring('Exception: '.length);
      }
      emit(state.copyWith(
        isCreatingReservation: false,
        reservationError: errorMessage,
      ));
    }
  }

  Future<void> _onCancelReservation(
    CancelReservation event,
    Emitter<RentalState> emit,
  ) async {
    if (state.maGiuCho == null) return;
    final maGiuChoToCancel = state.maGiuCho!;

    emit(state.copyWith(
      clearReservation: true,
    ));

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('persistedMaGiuCho');

    try {
      await _repository.cancelReservation(maGiuChoToCancel);
    } catch (_) {}
  }

  Future<void> _onCheckReservationStatus(
    CheckReservationStatus event,
    Emitter<RentalState> emit,
  ) async {
    if (state.maGiuCho == null) return;
    try {
      final status = await _repository.getReservationStatus(state.maGiuCho!);
      if (status['trangThai'] == 'HET_HAN' || status['trangThai'] == 'DA_HUY') {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('persistedMaGiuCho');
        emit(state.copyWith(
          maGiuCho: null,
          idempotencyKey: null,
          initialTimeRemaining: null,
          isReservationExpired: true,
        ));
      } else if (status['trangThai'] == 'DA_CHUYEN_HOP_DONG') {
        final recoveredId = await _repository.getContractIdByHold(state.maGiuCho!);
        if (recoveredId != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('persistedMaGiuCho');
          emit(state.copyWith(
            contractId: recoveredId,
          ));
        }
      }
    } catch (_) {
      // Ignore network errors, do not treat as expired.
    }
  }

  Future<void> _onFetchActiveReservation(
    FetchActiveReservation event,
    Emitter<RentalState> emit,
  ) async {
    emit(state.copyWith(isSyncingReservation: true));

    if (state.maGiuCho != null) {
      try {
        final status = await _repository.getReservationStatus(state.maGiuCho!);
        if (status['trangThai'] == 'HET_HAN' || status['trangThai'] == 'DA_HUY') {
          emit(state.copyWith(
            maGiuCho: null,
            idempotencyKey: null,
            initialTimeRemaining: null,
            isReservationExpired: true,
            isSyncingReservation: false,
          ));
          return;
        } else if (status['trangThai'] == 'DA_CHUYEN_HOP_DONG') {
          final recoveredId = await _repository.getContractIdByHold(state.maGiuCho!);
          if (recoveredId != null) {
            emit(state.copyWith(
              contractId: recoveredId,
              isSyncingReservation: false,
            ));
            return;
          }
        }
      } catch (_) {
        emit(state.copyWith(isSyncingReservation: false));
        return;
      }
    } else {
      // COLD START:
      final prefs = await SharedPreferences.getInstance();
      final persistedMaGiuCho = prefs.getString('persistedMaGiuCho');
      
      if (persistedMaGiuCho != null) {
        try {
          final status = await _repository.getReservationStatus(persistedMaGiuCho);
          if (status['trangThai'] == 'DANG_GIU') {
             await _repository.cancelReservation(persistedMaGiuCho);
             await prefs.remove('persistedMaGiuCho');
          } else if (status['trangThai'] == 'HET_HAN' || status['trangThai'] == 'DA_HUY') {
             await prefs.remove('persistedMaGiuCho');
          } else if (status['trangThai'] == 'DA_CHUYEN_HOP_DONG') {
             final recoveredId = await _repository.getContractIdByHold(persistedMaGiuCho);
             if (recoveredId != null) {
                await prefs.remove('persistedMaGiuCho');
                emit(state.copyWith(
                  contractId: recoveredId,
                  isSyncingReservation: false,
                ));
                return;
             }
          }
        } catch (_) {
          // ignore
        }
      }
    }

    emit(state.copyWith(isSyncingReservation: false));
  }

  Future<void> _onCreateContract(
    CreateContract event,
    Emitter<RentalState> emit,
  ) async {
    if (state.maGiuCho == null || state.isCreatingContract) return;

    emit(state.copyWith(
      isCreatingContract: true,
      createContractError: null,
    ));

    try {
      final result = await _repository.createContract(state.maGiuCho!);
      final contractId = result['maHopDong'] as String;

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('persistedMaGiuCho');

      emit(state.copyWith(
        isCreatingContract: false,
        contractId: contractId,
      ));
    } on ContractAlreadyCreatedException catch (e) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('persistedMaGiuCho');
      
      emit(state.copyWith(
        isCreatingContract: false,
        contractId: e.maHopDong,
      ));
    } catch (e) {
      String errorMessage = e.toString();
      if (errorMessage.startsWith('Exception: ')) {
        errorMessage = errorMessage.substring('Exception: '.length);
      }

      // If there's a timeout or network error, verify with backend
      try {
        final actualHold = await _repository.getReservationStatus(state.maGiuCho!);
        if (actualHold['trangThai'] == 'DA_CHUYEN_HOP_DONG') {
          // Attempt to fetch the contract ID
          final recoveredId = await _repository.getContractIdByHold(state.maGiuCho!);
          if (recoveredId != null) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('persistedMaGiuCho');
            emit(state.copyWith(
              isCreatingContract: false,
              contractId: recoveredId,
            ));
            return;
          }
          errorMessage = 'Hợp đồng đã được tạo thành công nhưng kết nối bị gián đoạn. Vui lòng thử lại để tải dữ liệu.';
        }
      } catch (_) {}

      emit(state.copyWith(
        isCreatingContract: false,
        createContractError: errorMessage,
      ));
    }
  }


}
