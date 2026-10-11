import 'package:equatable/equatable.dart';
import '../../../services/contract_pdf_service.dart';
import '../models/contract_tracking_status.dart';
import '../models/contract_tracking_view_data.dart';

class ContractTrackingState extends Equatable {
  final ContractModel contract;
  final ContractTrackingStatus status;
  final ContractTrackingViewData viewData;

  ContractTrackingState({
    required this.contract,
    ContractTrackingStatus? status,
  }) : status = status ?? _parseStatus(contract.status, contract.returnDate),
       viewData = ContractTrackingViewData.fromContract(
           contract,
           status ?? _parseStatus(contract.status, contract.returnDate),
       );

  static ContractTrackingStatus _parseStatus(String? apiStatus, DateTime returnDate) {
    if (apiStatus == 'HOAN_THANH' || apiStatus == 'DA_HUY') {
      return ContractTrackingStatus.completed;
    }
    if (apiStatus == 'DANG_THUE') {
      final now = DateTime.now();
      final isReturnDay = now.year == returnDate.year &&
                          now.month == returnDate.month &&
                          now.day == returnDate.day;
      if (isReturnDay || now.isAfter(returnDate)) {
        return ContractTrackingStatus.awaitingReturn;
      }
      return ContractTrackingStatus.renting;
    }
    return ContractTrackingStatus.awaitingHandover;
  }

  ContractTrackingState copyWith({
    ContractModel? contract,
    ContractTrackingStatus? status,
  }) {
    return ContractTrackingState(
      contract: contract ?? this.contract,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props => [contract, status, viewData];
}
