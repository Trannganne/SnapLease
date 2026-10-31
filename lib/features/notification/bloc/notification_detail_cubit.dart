import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import '../../../core/storage/token_storage.dart';
import '../data/repositories/notification_repository.dart';
import '../domain/models/notification_item_model.dart';
import '../../contract/data/contract_detail_data.dart';
import '../../contract/data/repositories/contract_repository.dart';
import '../../contract/services/contract_pdf_service.dart';
import 'notification_detail_state.dart';
import '../data/push_service.dart';

class NotificationDetailCubit extends Cubit<NotificationDetailState> {
  final NotificationRepository? _notificationRepository;
  final ContractRepository? _contractRepository;
  StreamSubscription<void>? _session;
  StreamSubscription<void>? _push;
  int _contractRead = 0;
  int _generation = 0;
  @override
  Future<void> close() {
    ++_generation;
    ++_contractRead;
    _session?.cancel();
    _push?.cancel();
    return super.close();
  }

  NotificationDetailCubit({
    required String notificationId,
    NotificationItemModel? initialItem,
    NotificationRepository? notificationRepository,
    ContractRepository? contractRepository,
    bool isDemo = false,
    ContractModel? demoContract,
    String? demoVariant,
    Map<String, dynamic>? demoMetadata,
  }) : _notificationRepository = notificationRepository,
       _contractRepository = contractRepository,
       super(
         NotificationDetailState(
           notificationId: notificationId,
           item: initialItem,
           isLoading: !isDemo && initialItem == null,
           isRead: initialItem?.isRead ?? false,
           contract: demoContract,
           contractLoading: demoMetadata?['contractLoading'] == true,
           contractError: demoMetadata?['contractError']?.toString(),
           isDemo: isDemo,
           demoVariant: demoVariant,
           demoMetadata: demoMetadata,
         ),
       ) {
    if (!isDemo) {
      _push = PushService.instance.updates.stream.listen(
        (_) => retryContractLoad(),
      );
      _session = TokenStorage.changes.listen((_) {
        ++_generation;
        ++_contractRead;
        if (!isClosed) {
          emit(
            NotificationDetailState(
              notificationId: notificationId,
              error: 'Phiên đăng nhập đã thay đổi.',
            ),
          );
        }
      });
    }
    _init();
  }

  Future<void> _init() async {
    final generation = _generation;
    var currentItem = state.item;
    if (currentItem == null &&
        !state.isDemo &&
        _notificationRepository != null) {
      try {
        currentItem = await _notificationRepository.getNotification(
          state.notificationId,
        );
        if (isClosed || generation != _generation) return;
        emit(
          state.copyWith(
            item: currentItem,
            isRead: currentItem.isRead,
            isLoading: false,
          ),
        );
      } catch (_) {
        if (!isClosed && generation == _generation) {
          emit(
            state.copyWith(
              isLoading: false,
              error: 'Không thể tải thông báo hoặc bạn không có quyền xem.',
            ),
          );
        }
        return;
      }
    }

    if (currentItem == null) {
      emit(
        state.copyWith(
          isLoading: false,
          error:
              'Không thể tải chi tiết thông báo. Dữ liệu thông báo không tồn tại.',
        ),
      );
      return;
    }

    // 1. Mark as read if not yet read and not in demo mode
    if (!state.isDemo && !currentItem.isRead) {
      try {
        await _notificationRepository?.markAsRead(currentItem.id);
        if (isClosed || generation != _generation) return;
        emit(
          state.copyWith(
            isRead: true,
            item: currentItem.copyWith(isRead: true),
          ),
        );
      } catch (_) {
        // Failing to mark as read should NOT block user from viewing content
        if (isClosed || generation != _generation) return;
        emit(state.copyWith(markAsReadFailed: true));
      }
    }

    // 2. Load contract data if structured target exists
    if (state.isDemo) {
      // In demo mode, contract and states are configured via fixture/metadata; do NOT call any real API
      return;
    }

    if (currentItem.targetType == NotificationTargetType.contract &&
        currentItem.targetId != null &&
        currentItem.targetId!.trim().isNotEmpty) {
      await _loadContract(currentItem.targetId!.trim());
    }
  }

  Future<void> retryContractLoad() async {
    if (state.isDemo) {
      emit(state.copyWith(contractLoading: true, clearContractError: true));
      await Future.delayed(const Duration(milliseconds: 400));
      emit(
        state.copyWith(
          contractLoading: false,
          contract:
              state.demoMetadata?['retryContract'] as ContractModel? ??
              state.contract,
          contractError:
              state.demoMetadata?['retryContract'] == null
                  ? 'Vẫn không thể kết nối đến máy chủ SNAPLEASE (Mã lỗi: TIMEOUT_504)'
                  : null,
        ),
      );
      return;
    }

    final targetId = state.item?.targetId;
    if (targetId != null && targetId.trim().isNotEmpty && !state.isDemo) {
      await _loadContract(targetId.trim());
    }
  }

  Future<void> _loadContract(String contractId) async {
    if (_contractRepository == null) return;
    final generation = _generation;
    final request = ++_contractRead;

    emit(state.copyWith(contractLoading: true, clearContractError: true));

    try {
      final json = await _contractRepository.getContractById(contractId);
      if (isClosed || generation != _generation || request != _contractRead) {
        return;
      }
      final detailData = ContractDetailData.fromJson(json, contractId);
      emit(
        state.copyWith(contract: detailData.contract, contractLoading: false),
      );
    } catch (e) {
      if (isClosed || generation != _generation || request != _contractRead) {
        return;
      }
      emit(
        state.copyWith(
          contractLoading: false,
          contractError:
              'Không thể tải thông tin hợp đồng liên quan: ${e.toString().replaceFirst(RegExp(r'^(Exception|FormatException): '), '')}',
        ),
      );
    }
  }
}
