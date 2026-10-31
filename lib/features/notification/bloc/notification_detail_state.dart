import 'package:rentcam/features/notification/domain/models/notification_item_model.dart';
import 'package:rentcam/features/contract/services/contract_pdf_service.dart';

class NotificationDetailState {
  final String notificationId;
  final NotificationItemModel? item;
  final bool isLoading;
  final String? error;
  final bool isRead;
  final bool markAsReadFailed;
  final ContractModel? contract;
  final bool contractLoading;
  final String? contractError;
  final bool isDemo;
  final String? demoVariant;
  final Map<String, dynamic>? demoMetadata;

  const NotificationDetailState({
    required this.notificationId,
    this.item,
    this.isLoading = false,
    this.error,
    this.isRead = false,
    this.markAsReadFailed = false,
    this.contract,
    this.contractLoading = false,
    this.contractError,
    this.isDemo = false,
    this.demoVariant,
    this.demoMetadata,
  });

  NotificationDetailState copyWith({
    String? notificationId,
    NotificationItemModel? item,
    bool? isLoading,
    String? error,
    bool? isRead,
    bool? markAsReadFailed,
    ContractModel? contract,
    bool? contractLoading,
    String? contractError,
    bool? isDemo,
    String? demoVariant,
    Map<String, dynamic>? demoMetadata,
    bool clearContractError = false,
  }) {
    return NotificationDetailState(
      notificationId: notificationId ?? this.notificationId,
      item: item ?? this.item,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      isRead: isRead ?? this.isRead,
      markAsReadFailed: markAsReadFailed ?? this.markAsReadFailed,
      contract: contract ?? this.contract,
      contractLoading: contractLoading ?? this.contractLoading,
      contractError: clearContractError ? null : (contractError ?? this.contractError),
      isDemo: isDemo ?? this.isDemo,
      demoVariant: demoVariant ?? this.demoVariant,
      demoMetadata: demoMetadata ?? this.demoMetadata,
    );
  }
}
