import 'dart:typed_data';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/contract_document_repository.dart';
import '../../services/contract_pdf_service.dart';

class ContractDocumentState {
  final bool loading;
  final String? error;
  const ContractDocumentState({this.loading = false, this.error});
}

/// Shared by document preview and download; contains no signing/payment writes.
class ContractDocumentCubit extends Cubit<ContractDocumentState> {
  final ContractDocumentRepository repository;
  Future<Uint8List>? _inFlight;
  ContractModel? _loadingContract;
  ContractDocumentCubit(this.repository) : super(const ContractDocumentState());

  Future<Uint8List> load(ContractModel contract) {
    if (identical(_loadingContract, contract) && _inFlight != null) {
      return _inFlight!;
    }
    if (!isClosed) emit(const ContractDocumentState(loading: true));
    _loadingContract = contract;
    final future = repository.load(contract);
    _inFlight = future;
    future.then(
      (_) {
        if (!identical(_inFlight, future)) return;
        _inFlight = null;
        if (!isClosed) emit(const ContractDocumentState());
      },
      onError: (Object error, StackTrace stack) {
        if (!identical(_inFlight, future)) return;
        _inFlight = null;
        if (!isClosed) {
          emit(
            ContractDocumentState(
              error: error.toString().replaceFirst('Exception: ', ''),
            ),
          );
        }
      },
    );
    return future;
  }
}
