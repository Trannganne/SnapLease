import 'package:equatable/equatable.dart';
import '../../../services/contract_pdf_service.dart';
import '../models/contract_tracking_status.dart';
import '../models/contract_tracking_view_data.dart';

class ContractTrackingState extends Equatable {
  final ContractModel contract;
  final ContractTrackingStatus status;
  final ContractTrackingViewData viewData;
  final bool loading;
  final bool verified;
  final String? error;

  ContractTrackingState({
    required this.contract,
    this.loading = false,
    this.error,
    this.verified = false,
  }) : status = parseStatus(contract.status),
       viewData = ContractTrackingViewData.fromContract(
         contract,
         parseStatus(contract.status),
       );

  static ContractTrackingStatus parseStatus(String? status) => switch (status) {
    'CHO_BAN_GIAO' => ContractTrackingStatus.awaitingHandover,
    'DANG_THUE' => ContractTrackingStatus.renting,
    'CHO_HOAN_TRA' => ContractTrackingStatus.awaitingReturn,
    'HOAN_THANH' => ContractTrackingStatus.completed,
    'DA_HUY' => ContractTrackingStatus.cancelled,
    'CHO_KY' => ContractTrackingStatus.awaitingSignature,
    'DA_KY' => ContractTrackingStatus.signed,
    _ => ContractTrackingStatus.unknown,
  };

  @override
  List<Object?> get props => [contract, status, loading, error, verified];
}
