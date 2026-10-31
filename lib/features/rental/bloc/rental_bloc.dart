import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import '../../../core/storage/token_storage.dart';
import '../../../core/formatters/rental_time_formatter.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'rental_event.dart';
import 'rental_state.dart';
import '../../device_detail/data/device_detail_repository.dart';
import '../../identity_verification/data/identity_verification_repository.dart';
import '../../cart/data/repositories/dio_cart_repository.dart';
import '../../../domain/entities/device_detail.dart';
import '../../cart/domain/models/cart_item_model.dart';

export 'rental_event.dart';
export 'rental_state.dart';

class RentalBloc extends Bloc<RentalEvent, RentalState> {
  int _sessionGeneration = 0;
  int _availabilityGeneration = 0;
  int _holdGeneration = 0;
  bool _editingHold = false;
  UpdateCartHold? _queuedHoldEdit;

  Future<List<BranchAvailability>> eligibleBranches() async {
    final before = state;
    final session = _sessionGeneration;
    final revision = _availabilityGeneration;
    final error = RentalTimeFormatter.periodError(
      before.pickupDate,
      before.returnDate,
    );
    if (error != null) throw StateError(error);
    final quantities = <String, int>{};
    if (before.cartItems.isEmpty) {
      if (before.selectedDevice == null) return [];
      quantities[before.selectedDevice!.id] = before.quantity;
    } else {
      for (final line in before.cartItems) {
        quantities.update(
          line.modelId,
          (n) => n + line.quantity,
          ifAbsent: () => line.quantity,
        );
      }
    }
    final eligible = <BranchAvailability>[];
    for (final branch
        in before.selectedDevice?.branches ?? <BranchAvailability>[]) {
      var valid =
          before.maGiuCho != null &&
          before.isCriteriaMatchingReservation &&
          !before.isReservationExpired &&
          branch.branchId == before.branchId;
      if (!valid) {
        valid = true;
        for (final entry in quantities.entries) {
          final count = await _repository.checkAvailability(
            branch.branchId,
            entry.key,
            before.pickupDate!,
            before.returnDate!,
          );
          if (count < entry.value) {
            valid = false;
            break;
          }
        }
      }
      if (valid) eligible.add(branch);
    }
    if (isClosed ||
        session != _sessionGeneration ||
        revision != _availabilityGeneration ||
        state.maGiuCho != before.maGiuCho ||
        state.contractId != before.contractId ||
        state.branchId != before.branchId ||
        state.pickupDate != before.pickupDate ||
        state.returnDate != before.returnDate ||
        state.quantity != before.quantity) {
      throw StateError(
        'Thông tin thuê đã thay đổi. Hãy mở lại danh sách chi nhánh.',
      );
    }
    return eligible;
  }

  StreamSubscription<void>? _session;
  @override
  Future<void> close() {
    ++_sessionGeneration;
    _session?.cancel();
    return super.close();
  }

  final DeviceDetailRepository _repository;
  final IdentityVerificationRepository _identityRepository;
  final Stopwatch reservationStopwatch = Stopwatch();
  final DioCartRepository _cartRepository;

  RentalBloc({
    DeviceDetailRepository? repository,
    IdentityVerificationRepository? identityRepository,
    DioCartRepository? cartRepository,
  }) : _repository = repository ?? DeviceDetailRepository(),
       _identityRepository =
           identityRepository ?? IdentityVerificationRepository(),
       _cartRepository = cartRepository ?? DioCartRepository(),
       super(const RentalState()) {
    _session = TokenStorage.changes.listen((_) {
      _cartRepository.invalidateSession();
      ++_sessionGeneration;
      add(const ClearRentalState());
    });
    on<AdoptCartCheckout>((event, emit) async {
      final generation = _sessionGeneration;
      if (event.items.isEmpty ||
          state.isCreatingReservation ||
          state.isCreatingContract ||
          state.isChecking) {
        return;
      }
      emit(const RentalState(isCreatingReservation: true));
      try {
        final rows = event.hold['cartItems'];
        final items =
            rows is List
                ? rows
                    .map(
                      (row) => DioCartRepository.fromJson(
                        Map<String, dynamic>.from(row as Map),
                      ),
                    )
                    .toList()
                : event.items;
        final device = await _repository.getDeviceDetail(items.first.modelId);
        if (isClosed || generation != _sessionGeneration) return;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'persistedMaGiuCho',
          event.hold['maGiuCho'] as String,
        );
        if (isClosed || generation != _sessionGeneration) return;
        reservationStopwatch
          ..reset()
          ..start();
        emit(_cartSnapshot(event.hold, items, device));
      } catch (e) {
        if (isClosed || generation != _sessionGeneration) return;
        emit(RentalState(reservationError: e.toString()));
      }
    });
    on<InitializeRental>(_onInitializeRental);
    on<UpdateCartHold>(_onUpdateCartHold);
    on<ReconcileCartHold>((event, emit) async {
      if (state.isChecking ||
          state.isCreatingContract ||
          state.cartItems.isEmpty) {
        return;
      }
      final before = state;
      emit(state.copyWith(isChecking: true));
      await _reconcileCartHold(before, emit);
    });
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

  RentalState _cartSnapshot(
    Map<String, dynamic> hold,
    List<CartItemModel> items,
    DeviceDetail device,
  ) {
    if (hold['trangThai'] != 'DANG_GIU' ||
        items.isEmpty ||
        RentalTimeFormatter.instant(hold['hetHanLuc'] as String).difference(
              RentalTimeFormatter.instant(hold['thoiGianServer'] as String),
            ) <=
            Duration.zero) {
      throw const FormatException(
        'Giữ chỗ không còn hiệu lực. Hãy kiểm tra lại.',
      );
    }
    final quotes = (hold['baoGia'] as List).cast<Map<String, dynamic>>();
    final quantity = items.fold<int>(0, (sum, item) => sum + item.quantity);
    return RentalState(
      selectedDevice: device,
      cartItems: items,
      branchId: items.first.branchId,
      pickupDate: items.first.startDate,
      returnDate: items.first.endDate,
      quantity: quantity,
      availableQuantity: quantity,
      priceQuote: {
        'soNgayTinhPhi': items.first.rentalDays,
        'giaThueNgay': quotes.fold<num>(
          0,
          (sum, quote) =>
              sum + (quote['donGiaSauGiam'] as num) * (quote['soLuong'] as num),
        ),
        'tongTienThue': quotes.fold<num>(
          0,
          (sum, quote) => sum + (quote['tongTienThue'] as num),
        ),
        'tongTienCoc': quotes.fold<num>(
          0,
          (sum, quote) => sum + (quote['tongTienCoc'] as num),
        ),
        'phanTramGiamGia': 0,
      },
      maGiuCho: hold['maGiuCho'] as String,
      initialTimeRemaining: RentalTimeFormatter.instant(
        hold['hetHanLuc'] as String,
      ).difference(
        RentalTimeFormatter.instant(hold['thoiGianServer'] as String),
      ),
      reservationServerTime: RentalTimeFormatter.instant(
        hold['thoiGianServer'] as String,
      ),
      daXacNhanThongTin: hold['daXacNhanThongTin'] == true,
      reservedBranchId: items.first.branchId,
      reservedPickupDate: items.first.startDate,
      reservedReturnDate: items.first.endDate,
      reservedQuantity: quantity,
    );
  }

  Duration _syncReservationClock(Map<String, dynamic> actual) {
    final remaining = RentalTimeFormatter.instant(
      actual['hetHanLuc'] as String,
    ).difference(
      RentalTimeFormatter.instant(actual['thoiGianServer'] as String),
    );
    reservationStopwatch
      ..reset()
      ..start();
    return remaining;
  }

  void _acceptCartSnapshot(
    Map<String, dynamic> actual,
    RentalState before,
    Emitter<RentalState> emit, {
    String? notice,
  }) {
    if (actual['maGiuCho'] != before.maGiuCho) {
      throw const FormatException('Sai lượt giữ chỗ');
    }
    if (actual['trangThai'] != 'DANG_GIU') {
      emit(
        before.copyWith(
          isChecking: false,
          isReservationExpired: [
            'HET_HAN',
            'DA_HUY',
          ].contains(actual['trangThai']),
          cartEditNeedsReconciliation:
              actual['trangThai'] == 'DA_CHUYEN_HOP_DONG',
          cartEditError:
              'Giữ chỗ không còn được chỉnh sửa. Hãy kiểm tra lại trạng thái thuê.',
        ),
      );
      return;
    }
    final items =
        (actual['cartItems'] as List)
            .map(
              (row) => DioCartRepository.fromJson(
                Map<String, dynamic>.from(row as Map),
              ),
            )
            .toList();
    if (items.isEmpty) throw const FormatException('Thiếu lựa chọn giữ chỗ');
    final snapshot = _cartSnapshot(actual, items, before.selectedDevice!);
    final priceChanged =
        before.priceQuote != null &&
        (before.priceQuote!['tongTienThue'] !=
                snapshot.priceQuote!['tongTienThue'] ||
            before.priceQuote!['tongTienCoc'] !=
                snapshot.priceQuote!['tongTienCoc']);
    final remaining = _syncReservationClock(actual);
    emit(
      snapshot.copyWith(
        // Re-anchor to the server deadline, including a committed edit found by GET.
        initialTimeRemaining: remaining,
        isChecking: _editingHold && _queuedHoldEdit != null,
        customerProfile: state.customerProfile,
        cartEditError:
            notice ??
            (priceChanged
                ? 'Báo giá đã thay đổi. Vui lòng kiểm tra lại giá thuê, tiền cọc và tổng tiền.'
                : null),
      ),
    );
  }

  Future<void> _reconcileCartHold(
    RentalState before,
    Emitter<RentalState> emit, {
    String? notice,
  }) async {
    final generation = _sessionGeneration;
    final read = ++_holdGeneration;
    try {
      final actual = await _cartRepository.getHeldCart(before.maGiuCho!);
      if (isClosed ||
          generation != _sessionGeneration ||
          read != _holdGeneration ||
          state.maGiuCho != before.maGiuCho) {
        return;
      }
      _acceptCartSnapshot(actual, before, emit, notice: notice);
    } catch (_) {
      if (isClosed ||
          generation != _sessionGeneration ||
          read != _holdGeneration ||
          state.maGiuCho != before.maGiuCho) {
        return;
      }
      emit(
        before.copyWith(
          isChecking: false,
          cartEditNeedsReconciliation: true,
          cartEditError:
              'Chưa xác định kết quả. Kiểm tra lại giữ chỗ trước khi tiếp tục; ứng dụng không tự gửi lại.',
        ),
      );
    }
  }

  Future<void> _onUpdateCartHold(
    UpdateCartHold event,
    Emitter<RentalState> emit,
  ) async {
    if (_editingHold) {
      _queuedHoldEdit = event;
      return;
    }
    if (state.cartItems.isEmpty ||
        state.maGiuCho == null ||
        state.isChecking ||
        state.isCreatingContract ||
        state.isReservationExpired ||
        state.contractId != null) {
      return;
    }
    final periodError = RentalTimeFormatter.periodError(
      event.pickup,
      event.dropoff,
    );
    if (periodError != null) {
      emit(state.copyWith(cartEditError: periodError, isConfirmed: false));
      return;
    }
    _editingHold = true;
    ++_holdGeneration;
    ++_availabilityGeneration;
    try {
      var next = event;
      while (true) {
        await _applyHoldEdit(next, emit);
        final queued = _queuedHoldEdit;
        _queuedHoldEdit = null;
        if (queued == null ||
            isClosed ||
            state.cartEditNeedsReconciliation ||
            state.maGiuCho == null ||
            state.isReservationExpired ||
            state.contractId != null) {
          break;
        }
        final invalid = RentalTimeFormatter.periodError(
          queued.pickup,
          queued.dropoff,
        );
        if (invalid != null) {
          emit(
            state.copyWith(
              isChecking: false,
              cartEditError: invalid,
              isConfirmed: false,
            ),
          );
          break;
        }
        ++_holdGeneration;
        ++_availabilityGeneration;
        next = queued;
      }
    } finally {
      _editingHold = false;
      _queuedHoldEdit = null;
    }
  }

  Future<void> _applyHoldEdit(
    UpdateCartHold event,
    Emitter<RentalState> emit,
  ) async {
    final before = state;
    final generation = _sessionGeneration;
    emit(state.copyWith(isChecking: true, isConfirmed: false));
    if (before.cartEditNeedsReconciliation) {
      await _reconcileCartHold(before, emit);
      return;
    }
    try {
      final actual = await _cartRepository.updateHeldCart(
        before.maGiuCho!,
        before.cartItems,
        branchId: event.branchId,
        pickup: event.pickup,
        dropoff: event.dropoff,
      );
      if (isClosed ||
          generation != _sessionGeneration ||
          state.maGiuCho != before.maGiuCho) {
        return;
      }
      _acceptCartSnapshot(actual, before, emit);
    } catch (error) {
      if (isClosed ||
          generation != _sessionGeneration ||
          state.maGiuCho != before.maGiuCho) {
        return;
      }
      if (error is CartHoldEditFailure &&
          !error.uncertain &&
          ['INSUFFICIENT_DEVICES', 'BRANCH_NOT_FOUND'].contains(error.code)) {
        emit(before.copyWith(isChecking: false, cartEditError: error.message));
      } else {
        // PUT is never retried. GET the same hold, including its actual versions and quotes.
        await _reconcileCartHold(
          before,
          emit,
          notice:
              error is CartHoldEditFailure && error.uncertain
                  ? 'Đã kiểm tra lại giữ chỗ. Hãy xác nhận thông tin thực tế đang hiển thị trước khi tiếp tục.'
                  : error.toString(),
        );
      }
    }
  }

  Future<void> _onLoadCustomerProfile(
    LoadCustomerProfile event,
    Emitter<RentalState> emit,
  ) async {
    final session = _sessionGeneration;
    emit(state.copyWith(isLoadingProfile: true, profileError: null));
    try {
      final profile = await _identityRepository.getCustomerProfile();
      if (isClosed || session != _sessionGeneration) return;
      emit(
        state.copyWith(
          isLoadingProfile: false,
          customerProfile: profile,
          daXacNhanThongTin: profile.daXacNhanThongTin,
        ),
      );
    } catch (e) {
      if (isClosed || session != _sessionGeneration) return;
      emit(state.copyWith(isLoadingProfile: false, profileError: e.toString()));
    }
  }

  void _onClearRentalState(ClearRentalState event, Emitter<RentalState> emit) {
    ++_sessionGeneration;
    ++_availabilityGeneration;
    reservationStopwatch.stop();
    reservationStopwatch.reset();
    emit(const RentalState());
  }

  Future<void> _onClearRentalSession(
    ClearRentalSession event,
    Emitter<RentalState> emit,
  ) async {
    ++_sessionGeneration;
    ++_availabilityGeneration;
    reservationStopwatch.stop();
    reservationStopwatch.reset();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('persistedMaGiuCho');
    emit(state.copyWith(clearReservation: true, clearContract: true));
  }

  void _onToggleConfirmation(
    ToggleConfirmation event,
    Emitter<RentalState> emit,
  ) {
    emit(state.copyWith(isConfirmed: event.isConfirmed));
  }

  void _onInitializeRental(InitializeRental event, Emitter<RentalState> emit) {
    if ((state.maGiuCho != null && state.contractId == null) ||
        state.isCreatingReservation ||
        state.isCreatingContract) {
      return;
    }
    if (state.contractId != null ||
        state.selectedDevice?.id != event.device.id) {
      ++_availabilityGeneration;
      ++_sessionGeneration;
      emit(
        RentalState(
          selectedDevice: event.device,
          pickupDate: null,
          returnDate: null,
          quantity: 1,
          branchId: null,
          isConfirmed: false,
        ),
      );
    } else {
      final invalidBranch =
          state.branchId != null &&
          !event.device.branches.any(
            (branch) => branch.branchId == state.branchId,
          );
      if (invalidBranch) {
        ++_availabilityGeneration;
      }
      emit(
        state.copyWith(
          selectedDevice: event.device,
          clearBranch: invalidBranch,
          clearAvailability: invalidBranch,
          isChecking: invalidBranch ? false : state.isChecking,
        ),
      );
    }
  }

  void _onUpdateRentalPeriod(
    UpdateRentalPeriod event,
    Emitter<RentalState> emit,
  ) {
    if (state.isCreatingReservation || state.isCreatingContract) return;
    ++_availabilityGeneration;
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

    if (state.maGiuCho != null && state.cartItems.isNotEmpty) {
      add(
        UpdateCartHold(
          branchId: state.branchId!,
          pickup: newPickup,
          dropoff: newReturn,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        pickupDate: newPickup,
        returnDate: newReturn,
        isReservationExpired: false,
        clearAvailability: true,
      ),
    );
    add(const FetchAvailabilityAndQuote());
  }

  void _onUpdateRentalBranch(
    UpdateRentalBranch event,
    Emitter<RentalState> emit,
  ) {
    if (state.isCreatingReservation || state.isCreatingContract) return;
    if (state.selectedDevice == null ||
        !state.selectedDevice!.branches.any(
          (branch) => branch.branchId == event.branchId,
        )) {
      return;
    }
    ++_availabilityGeneration;
    if (state.maGiuCho != null && state.cartItems.isNotEmpty) {
      add(
        UpdateCartHold(
          branchId: event.branchId,
          pickup: state.pickupDate!,
          dropoff: state.returnDate!,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        branchId: event.branchId,
        clearAvailability: true,
        isReservationExpired: false,
      ),
    );
    add(const FetchAvailabilityAndQuote());
  }

  void _onUpdateQuantity(UpdateQuantity event, Emitter<RentalState> emit) {
    if (state.isCreatingReservation || state.isCreatingContract) return;
    if (state.maGiuCho != null) {
      emit(
        state.copyWith(
          checkError:
              'Giữ chỗ có số lượng cố định. Hủy lượt cũ trước khi chọn lại.',
        ),
      );
      return;
    }
    ++_availabilityGeneration;
    if (event.quantity < 1) return;
    emit(
      state.copyWith(
        quantity: event.quantity,
        clearAvailability: true,
        isReservationExpired: false,
      ),
    );
    add(const FetchAvailabilityAndQuote());
  }

  Future<void> _onFetchAvailabilityAndQuote(
    FetchAvailabilityAndQuote event,
    Emitter<RentalState> emit,
  ) async {
    final before = state;
    if (before.selectedDevice == null ||
        before.branchId == null ||
        before.pickupDate == null ||
        before.returnDate == null ||
        before.isCreatingReservation ||
        before.isCreatingContract) {
      return;
    }
    if (before.maGiuCho != null) {
      if (_editingHold) return;
      emit(before.copyWith(isChecking: true));
      // Fixed Schema33 selection sets are edited through UpdateCartHold.
      await _reconcileCartHold(before, emit);
      return;
    }
    final session = _sessionGeneration;
    final request = ++_availabilityGeneration;
    bool current() =>
        !isClosed &&
        !emit.isDone &&
        session == _sessionGeneration &&
        request == _availabilityGeneration;
    emit(
      before.copyWith(
        isChecking: true,
        clearAvailability: true,
        showInsufficientDeviceDialog: false,
        showBranchNotFoundDialog: false,
      ),
    );
    try {
      final available = await _repository.checkAvailability(
        before.branchId!,
        before.selectedDevice!.id,
        before.pickupDate!,
        before.returnDate!,
      );
      if (!current()) return;
      final quote = await _repository.getPriceQuote(
        before.branchId!,
        before.selectedDevice!.id,
        before.quantity,
        before.pickupDate!,
        before.returnDate!,
      );
      if (!current()) return;
      emit(
        state.copyWith(
          isChecking: false,
          availableQuantity: available,
          priceQuote: quote,
        ),
      );
    } catch (error) {
      if (!current()) return;
      emit(state.copyWith(isChecking: false, checkError: error.toString()));
    }
  }

  Future<void> _onCreateReservation(
    CreateReservation event,
    Emitter<RentalState> emit,
  ) async {
    if (!state.isValidToRent ||
        state.isCreatingReservation ||
        state.isCreatingContract ||
        state.maGiuCho != null) {
      return;
    }
    final before = state;
    final session = _sessionGeneration;
    final key = before.idempotencyKey ?? const Uuid().v4();
    emit(state.copyWith(isCreatingReservation: true, idempotencyKey: key));
    try {
      final result = await _repository.createReservation(
        maCuaHang: before.branchId!,
        maDongMay: before.selectedDevice!.id,
        soLuong: before.quantity,
        ngayBatDau: before.pickupDate!,
        ngayKetThuc: before.returnDate!,
        idempotencyKey: key,
      );
      if (isClosed || session != _sessionGeneration) return;
      final id = result['maGiuCho'] as String;
      final prefs = await SharedPreferences.getInstance();
      if (isClosed || session != _sessionGeneration) return;
      await prefs.setString('persistedMaGiuCho', id);
      final actual = await _repository.getReservationStatus(id);
      if (isClosed || session != _sessionGeneration) return;
      if (actual['maGiuCho'] != id) {
        throw const FormatException('Sai lượt giữ chỗ.');
      }
      if (actual['trangThai'] == 'DA_CHUYEN_HOP_DONG') {
        final contractId = await _repository.getContractIdByHold(id);
        if (isClosed || session != _sessionGeneration) return;
        if (contractId == null) {
          throw const FormatException('Chưa tải được hợp đồng.');
        }
        await prefs.remove('persistedMaGiuCho');
        emit(
          state.copyWith(isCreatingReservation: false, contractId: contractId),
        );
        return;
      }
      final items =
          (actual['cartItems'] as List)
              .map(
                (row) => DioCartRepository.fromJson(
                  Map<String, dynamic>.from(row as Map),
                ),
              )
              .toList();
      final snapshot = _cartSnapshot(actual, items, before.selectedDevice!);
      reservationStopwatch
        ..reset()
        ..start();
      emit(
        snapshot.copyWith(
          idempotencyKey: key,
          customerProfile: state.customerProfile,
        ),
      );
    } catch (error) {
      if (isClosed || session != _sessionGeneration) return;
      emit(
        state.copyWith(
          isCreatingReservation: false,
          reservationError: error.toString(),
        ),
      );
    }
  }

  Future<void> _onCancelReservation(
    CancelReservation event,
    Emitter<RentalState> emit,
  ) async {
    if (state.maGiuCho == null ||
        _editingHold ||
        state.isChecking ||
        state.isCreatingContract ||
        state.isCreatingReservation) {
      return;
    }
    final before = state;
    final session = _sessionGeneration;
    emit(state.copyWith(isChecking: true));
    try {
      await _repository.cancelReservation(before.maGiuCho!);
    } catch (error) {
      if (isClosed || session != _sessionGeneration) return;
      try {
        final actual = await _repository.getReservationStatus(before.maGiuCho!);
        if (isClosed || session != _sessionGeneration) return;
        if (!['DA_HUY', 'HET_HAN'].contains(actual['trangThai'])) {
          emit(
            before.copyWith(
              isChecking: false,
              reservationError:
                  'Chưa xác nhận hủy giữ chỗ. Hãy kiểm tra lại trước khi tiếp tục.',
            ),
          );
          return;
        }
      } catch (_) {
        if (isClosed || session != _sessionGeneration) return;
        emit(
          before.copyWith(
            isChecking: false,
            reservationError: error.toString(),
          ),
        );
        return;
      }
    }
    if (isClosed || session != _sessionGeneration) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('persistedMaGiuCho');
    if (isClosed || session != _sessionGeneration) return;
    reservationStopwatch
      ..stop()
      ..reset();
    emit(
      state.copyWith(
        isChecking: false,
        clearReservation: true,
        checkError: 'Hãy kiểm tra lại khả dụng trước khi giữ chỗ mới.',
      ),
    );
  }

  Future<void> _onCheckReservationStatus(
    CheckReservationStatus event,
    Emitter<RentalState> emit,
  ) async {
    if (state.maGiuCho == null || _editingHold) return;
    final session = _sessionGeneration;
    final holdRevision = _holdGeneration;
    final holdId = state.maGiuCho!;
    try {
      final status = await _repository.getReservationStatus(holdId);
      if (isClosed ||
          session != _sessionGeneration ||
          holdRevision != _holdGeneration ||
          state.maGiuCho != holdId) {
        return;
      }
      if (status['trangThai'] == 'HET_HAN' || status['trangThai'] == 'DA_HUY') {
        final prefs = await SharedPreferences.getInstance();
        if (isClosed || session != _sessionGeneration) return;
        await prefs.remove('persistedMaGiuCho');
        if (isClosed || session != _sessionGeneration) return;
        emit(
          state.copyWith(clearReservation: true, isReservationExpired: true),
        );
      } else if (status['trangThai'] == 'DA_CHUYEN_HOP_DONG') {
        final recoveredId = await _repository.getContractIdByHold(holdId);
        if (isClosed || session != _sessionGeneration) return;
        if (recoveredId != null) {
          final prefs = await SharedPreferences.getInstance();
          if (isClosed || session != _sessionGeneration) return;
          await prefs.remove('persistedMaGiuCho');
          if (isClosed || session != _sessionGeneration) return;
          emit(state.copyWith(contractId: recoveredId));
        }
      } else if (status['trangThai'] == 'DANG_GIU') {
        emit(
          state.copyWith(
            initialTimeRemaining: _syncReservationClock(status),
            reservationServerTime: DateTime.parse(
              status['thoiGianServer'] as String,
            ),
          ),
        );
      }
    } catch (_) {
      // Ignore network errors, do not treat as expired.
    }
  }

  Future<void> _onFetchActiveReservation(
    FetchActiveReservation event,
    Emitter<RentalState> emit,
  ) async {
    if (_editingHold) return;
    final session = _sessionGeneration;
    final revision = _holdGeneration;
    final activeId = state.maGiuCho;
    emit(state.copyWith(isSyncingReservation: true));

    if (state.maGiuCho != null) {
      try {
        final status = await _repository.getReservationStatus(state.maGiuCho!);
        if (isClosed || session != _sessionGeneration) return;
        if (revision != _holdGeneration || state.maGiuCho != activeId) {
          emit(state.copyWith(isSyncingReservation: false));
          return;
        }
        if (status['trangThai'] == 'HET_HAN' ||
            status['trangThai'] == 'DA_HUY') {
          emit(
            state.copyWith(
              clearReservation: true,
              isReservationExpired: true,
              isSyncingReservation: false,
            ),
          );
          return;
        } else if (status['trangThai'] == 'DA_CHUYEN_HOP_DONG') {
          final recoveredId = await _repository.getContractIdByHold(
            state.maGiuCho!,
          );
          if (isClosed || session != _sessionGeneration) return;
          if (recoveredId != null) {
            emit(
              state.copyWith(
                contractId: recoveredId,
                isSyncingReservation: false,
              ),
            );
            return;
          }
        }
        if (status['trangThai'] == 'DANG_GIU') {
          emit(
            state.copyWith(
              initialTimeRemaining: _syncReservationClock(status),
              reservationServerTime: DateTime.parse(
                status['thoiGianServer'] as String,
              ),
            ),
          );
        }
      } catch (_) {
        if (isClosed || session != _sessionGeneration) return;
        emit(state.copyWith(isSyncingReservation: false));
        return;
      }
    } else {
      // COLD START:
      final prefs = await SharedPreferences.getInstance();
      if (isClosed || session != _sessionGeneration) return;
      final persistedMaGiuCho = prefs.getString('persistedMaGiuCho');

      if (persistedMaGiuCho != null) {
        try {
          final status = await _repository.getReservationStatus(
            persistedMaGiuCho,
          );
          if (isClosed || session != _sessionGeneration) return;
          if (status['trangThai'] == 'DANG_GIU') {
            if (status['cartItems'] is List) {
              add(
                AdoptCartCheckout(
                  status,
                  (status['cartItems'] as List)
                      .map(
                        (j) => DioCartRepository.fromJson(
                          Map<String, dynamic>.from(j as Map),
                        ),
                      )
                      .toList(),
                ),
              );
              return;
            }
            emit(
              state.copyWith(
                isSyncingReservation: false,
                reservationError:
                    'Không thể khôi phục lựa chọn. Hãy kiểm tra lại giữ chỗ; chưa hủy lượt trên server.',
              ),
            );
            return;
          } else if (status['trangThai'] == 'HET_HAN' ||
              status['trangThai'] == 'DA_HUY') {
            await prefs.remove('persistedMaGiuCho');
          } else if (status['trangThai'] == 'DA_CHUYEN_HOP_DONG') {
            final recoveredId = await _repository.getContractIdByHold(
              persistedMaGiuCho,
            );
            if (isClosed || session != _sessionGeneration) return;
            if (recoveredId != null) {
              await prefs.remove('persistedMaGiuCho');
              if (isClosed || session != _sessionGeneration) return;
              emit(
                state.copyWith(
                  contractId: recoveredId,
                  isSyncingReservation: false,
                ),
              );
              return;
            }
          }
        } catch (_) {
          // ignore
        }
      }
    }

    if (isClosed || session != _sessionGeneration) return;
    emit(state.copyWith(isSyncingReservation: false));
  }

  Future<void> _onCreateContract(
    CreateContract event,
    Emitter<RentalState> emit,
  ) async {
    if (_editingHold ||
        state.maGiuCho == null ||
        state.contractId != null ||
        !state.isConfirmed ||
        !state.isValidToRent ||
        !state.isCriteriaMatchingReservation ||
        state.isCreatingContract ||
        state.isCreatingReservation ||
        state.isChecking ||
        state.cartEditNeedsReconciliation ||
        state.isReservationExpired) {
      return;
    }
    final session = _sessionGeneration;
    final holdId = state.maGiuCho!;
    emit(state.copyWith(isCreatingContract: true, createContractError: null));

    try {
      final result = await _repository.createContract(holdId);
      if (isClosed || session != _sessionGeneration) return;
      final contractId = result['maHopDong'] as String;

      final prefs = await SharedPreferences.getInstance();
      if (isClosed || session != _sessionGeneration) return;
      await prefs.remove('persistedMaGiuCho');
      if (isClosed || session != _sessionGeneration) return;
      emit(state.copyWith(isCreatingContract: false, contractId: contractId));
    } on ContractAlreadyCreatedException catch (e) {
      if (isClosed || session != _sessionGeneration) return;
      final prefs = await SharedPreferences.getInstance();
      if (isClosed || session != _sessionGeneration) return;
      await prefs.remove('persistedMaGiuCho');
      if (isClosed || session != _sessionGeneration) return;
      emit(state.copyWith(isCreatingContract: false, contractId: e.maHopDong));
    } catch (e) {
      if (isClosed || session != _sessionGeneration) return;
      String errorMessage = e.toString();
      if (errorMessage.startsWith('Exception: ')) {
        errorMessage = errorMessage.substring('Exception: '.length);
      }

      // If there's a timeout or network error, verify with backend
      try {
        final actualHold = await _repository.getReservationStatus(holdId);
        if (isClosed || session != _sessionGeneration) return;
        if (actualHold['trangThai'] == 'DA_CHUYEN_HOP_DONG') {
          // Attempt to fetch the contract ID
          final recoveredId = await _repository.getContractIdByHold(holdId);
          if (isClosed || session != _sessionGeneration) return;
          if (recoveredId != null) {
            final prefs = await SharedPreferences.getInstance();
            if (isClosed || session != _sessionGeneration) return;
            await prefs.remove('persistedMaGiuCho');
            if (isClosed || session != _sessionGeneration) return;
            emit(
              state.copyWith(
                isCreatingContract: false,
                contractId: recoveredId,
              ),
            );
            return;
          }
          errorMessage =
              'Hợp đồng đã được tạo thành công nhưng kết nối bị gián đoạn. Vui lòng thử lại để tải dữ liệu.';
        }
      } catch (_) {}
      if (isClosed || session != _sessionGeneration) return;
      emit(
        state.copyWith(
          isCreatingContract: false,
          createContractError: errorMessage,
          cartEditNeedsReconciliation:
              e is RentalRequestFailure && e.code == 'CART_VERSION_CONFLICT'
                  ? true
                  : state.cartEditNeedsReconciliation,
        ),
      );
    }
  }
}
