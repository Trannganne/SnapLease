import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/branch.dart';
import '../../../domain/entities/geo_coordinates.dart';
import '../domain/branch_repository.dart';
import '../data/branch_location_service.dart';

class BranchState {
  final List<Branch> branches;
  final String? selectedId;
  final GeoCoordinates? location;
  final bool loading, locating, focusLocation;
  final String? error, locationError;
  const BranchState({
    this.branches = const [],
    this.selectedId,
    this.location,
    this.loading = false,
    this.locating = false,
    this.focusLocation = false,
    this.error,
    this.locationError,
  });

  Branch? get selected {
    for (final branch in branches) {
      if (branch.id == selectedId) return branch;
    }
    return null;
  }

  List<Branch> get ordered {
    final result = List<Branch>.of(branches);
    if (location != null) {
      result.sort((a, b) {
        final da =
            a.coordinates == null
                ? double.infinity
                : location!.distanceKmTo(a.coordinates!);
        final db =
            b.coordinates == null
                ? double.infinity
                : location!.distanceKmTo(b.coordinates!);
        final order = da.compareTo(db);
        return order == 0 ? a.name.compareTo(b.name) : order;
      });
    }
    return result;
  }
}

class BranchCubit extends Cubit<BranchState> {
  final BranchRepository repository;
  final BranchLocationService locationService;
  int _loadGeneration = 0, _locationGeneration = 0;
  BranchCubit({
    required this.repository,
    required this.locationService,
    String? selectedId,
  }) : super(BranchState(selectedId: selectedId));

  Future<void> load() async {
    final generation = ++_loadGeneration;
    emit(
      BranchState(
        branches: state.branches,
        selectedId: state.selectedId,
        location: state.location,
        loading: true,
      ),
    );
    try {
      final branches = await repository.getBranches();
      if (isClosed || generation != _loadGeneration) return;
      emit(
        BranchState(
          branches: List.unmodifiable(branches),
          selectedId: state.selectedId,
          location: state.location,
        ),
      );
    } catch (_) {
      if (!isClosed && generation == _loadGeneration) {
        emit(
          BranchState(
            branches: state.branches,
            selectedId: state.selectedId,
            location: state.location,
            error: 'Không tải được chi nhánh. Vui lòng thử lại.',
          ),
        );
      }
    }
  }

  void select(String id) {
    if (!state.branches.any((branch) => branch.id == id)) return;
    emit(
      BranchState(
        branches: state.branches,
        selectedId: id,
        location: state.location,
      ),
    );
  }

  // Called only by explicit location/nearest buttons, never by load/build.
  Future<void> locate({required bool nearest}) async {
    if (state.locating || state.loading) return;
    final generation = ++_locationGeneration;
    emit(
      BranchState(
        branches: state.branches,
        selectedId: state.selectedId,
        location: state.location,
        locating: true,
      ),
    );
    try {
      final position = await locationService.current();
      if (isClosed || generation != _locationGeneration) return;
      String? selectedId = state.selectedId;
      String? error;
      if (nearest) {
        final valid =
            state.branches.where((b) => b.coordinates != null).toList()..sort(
              (a, b) => position
                  .distanceKmTo(a.coordinates!)
                  .compareTo(position.distanceKmTo(b.coordinates!)),
            );
        if (valid.isEmpty) {
          error = 'Các chi nhánh chưa có tọa độ để tìm gần nhất.';
        } else {
          selectedId = valid.first.id;
        }
      }
      emit(
        BranchState(
          branches: state.branches,
          selectedId: selectedId,
          location: position,
          focusLocation: !nearest,
          locationError: error,
        ),
      );
    } catch (error) {
      if (!isClosed && generation == _locationGeneration) {
        emit(
          BranchState(
            branches: state.branches,
            selectedId: state.selectedId,
            location: state.location,
            locationError:
                error is LocationFailure
                    ? error.message
                    : 'Không lấy được vị trí. Bạn vẫn xem được chi nhánh.',
          ),
        );
      }
    }
  }

  @override
  Future<void> close() {
    _loadGeneration++;
    _locationGeneration++;
    return super.close();
  }
}
