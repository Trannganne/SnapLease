import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../../domain/entities/customer_profile.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../identity_verification/data/identity_verification_repository.dart';

class AccountState {
  final bool loading;
  final String? error;
  final String username;
  final String role;
  final CustomerProfile? profile;
  final String? documentStatus;
  const AccountState({
    this.loading = false,
    this.error,
    this.username = '',
    this.role = '',
    this.profile,
    this.documentStatus,
  });

  String get avatarLetter =>
      username.trim().isEmpty
          ? '?'
          : username.trim().characters.first.toUpperCase();
  bool get isCustomer => role == 'KHACH_HANG';
  String get identityLabel => switch (documentStatus) {
    'HOP_LE' => 'Giấy tờ đã được xác minh',
    'CHO_XAC_MINH' =>
      profile?.daXacNhanThongTin == true
          ? 'Đã cập nhật giấy tờ · Chờ xác minh'
          : 'Giấy tờ đang chờ duyệt',
    'TU_CHOI' => 'Giấy tờ bị từ chối',
    null => 'Chưa gửi giấy tờ',
    _ => 'Chưa xác định trạng thái giấy tờ',
  };
}

class AccountCubit extends Cubit<AccountState> {
  final AuthRepository _auth;
  final IdentityVerificationRepository _identity;
  late final StreamSubscription<void> _willChange;
  late final StreamSubscription<void> _changes;
  int _request = 0;
  AccountCubit({AuthRepository? auth, IdentityVerificationRepository? identity})
    : _auth = auth ?? AuthRepository(),
      _identity = identity ?? IdentityVerificationRepository(),
      super(const AccountState()) {
    _willChange = TokenStorage.willChange.listen((_) {
      _request++;
      if (!isClosed) emit(const AccountState());
    });
    _changes = TokenStorage.changes.listen((_) => scheduleMicrotask(load));
  }

  Future<void> load() async {
    if (isClosed || TokenStorage.isChanging) return;
    final request = ++_request;
    final generation = TokenStorage.generation;
    bool current() =>
        !isClosed &&
        request == _request &&
        generation == TokenStorage.generation &&
        !TokenStorage.isChanging;
    emit(const AccountState(loading: true));
    try {
      final token = await TokenStorage.getToken();
      if (!current()) return;
      if (token == null || token.isEmpty) {
        emit(const AccountState(error: 'Vui lòng đăng nhập để xem hồ sơ.'));
        return;
      }
      final me = await _auth.getMe(sessionToken: token);
      if (!current()) return;
      final accountId = me['maTaiKhoan'] as String?;
      if (accountId == null || accountId.isEmpty) throw const FormatException();
      if (!await TokenStorage.bindAccount(token, accountId, generation)) {
        return;
      }
      final role = me['vaiTro'] as String? ?? '';
      CustomerProfile? profile;
      String? status;
      if (role == 'KHACH_HANG') {
        if (me['maKhachThue'] == null) throw const FormatException();
        profile = await _identity.getCustomerProfile(sessionToken: token);
        if (!current()) return;
        status = await _identity.getLatestDocumentStatus(sessionToken: token);
      }
      if (!current()) return;
      emit(
        AccountState(
          username: me['tenDangNhap'] as String? ?? '',
          role: role,
          profile: profile,
          documentStatus: status,
        ),
      );
    } catch (_) {
      if (current()) {
        emit(
          const AccountState(error: 'Không thể tải hồ sơ. Vui lòng thử lại.'),
        );
      }
    }
  }

  @override
  Future<void> close() async {
    _request++;
    await _willChange.cancel();
    await _changes.cancel();
    await super.close();
  }
}
