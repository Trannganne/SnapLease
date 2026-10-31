import 'dart:typed_data';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/contract_repository.dart';

class HandoverImageState {
  final Uint8List? bytes;
  final bool failed;
  const HandoverImageState({this.bytes, this.failed = false});
}

class HandoverImageCubit extends Cubit<HandoverImageState> {
  HandoverImageCubit() : super(const HandoverImageState());
  Future<void> load(String url, ContractRepository repository) async {
    try {
      final bytes = await repository.getHandoverImage(url);
      if (!isClosed) emit(HandoverImageState(bytes: Uint8List.fromList(bytes)));
    } catch (_) {
      if (!isClosed) emit(const HandoverImageState(failed: true));
    }
  }
}
