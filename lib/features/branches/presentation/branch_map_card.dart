import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;
import '../../../core/constants/app_sizes.dart';
import '../../../core/widgets/app_text.dart';
import '../../../core/widgets/snap_loading_view.dart';
import '../../../domain/entities/branch.dart';
import '../../../domain/entities/geo_coordinates.dart';
import '../../catalog/data/catalog_repository.dart';
import '../domain/branch_repository.dart';
import '../data/branch_location_service.dart';
import '../data/branch_directions.dart';
import 'branch_cubit.dart';
import 'branch_choice_tile.dart';

class BranchMapCard extends StatelessWidget {
  final String? branchId;
  final BranchRepository? repository;
  final BranchLocationService? locationService;
  final BranchDirections? directions;
  final bool enabled;
  final String token;
  const BranchMapCard({
    super.key,
    this.branchId,
    this.repository,
    this.locationService,
    this.directions,
    this.enabled = const bool.fromEnvironment('MAPBOX_ENABLED'),
    this.token = const String.fromEnvironment('MAPBOX_ACCESS_TOKEN'),
  });
  static bool validToken(String token) =>
      token.startsWith('pk.') &&
      token.length > 20 &&
      !RegExp(r'\s').hasMatch(token);
  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return const _MapFallback(
        message:
            'Bản đồ chưa được bật. Địa chỉ chi nhánh được hiển thị bên dưới.',
      );
    }
    return BlocProvider(
      create:
          (_) => BranchCubit(
            repository: repository ?? CatalogRepository(),
            locationService: locationService ?? DeviceBranchLocationService(),
            selectedId: branchId,
          )..load(),
      child: _BranchMapPanel(
        token: token,
        directions: directions ?? BranchDirections(),
      ),
    );
  }
}

class _BranchMapPanel extends StatelessWidget {
  final String token;
  final BranchDirections directions;
  const _BranchMapPanel({required this.token, required this.directions});
  Future<void> _list(
    BuildContext context,
    BranchCubit cubit,
  ) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder:
        (sheet) => BlocProvider.value(
          value: cubit,
          child: BlocBuilder<BranchCubit, BranchState>(
            builder:
                (context, state) => SizedBox(
                  height: MediaQuery.sizeOf(context).height * .65,
                  child: Column(
                    children: [
                      ListTile(
                        title: const AppText(
                          'Các chi nhánh',
                          fontWeight: FontWeight.bold,
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(sheet).pop(),
                        ),
                      ),
                      if (state.location != null)
                        const Padding(
                          padding: EdgeInsets.all(AppSizes.spacingS),
                          child: AppText(
                            'Khoảng cách đường thẳng ước tính, không phải quãng đường hay thời gian di chuyển.',
                            fontSize: 12,
                          ),
                        ),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.all(AppSizes.pageMargin),
                          children: [
                            for (final branch in state.ordered)
                              BranchChoiceTile(
                                name: branch.name,
                                address: branch.address ?? '',
                                selected: branch.id == state.selectedId,
                                subtitle:
                                    branch.coordinates == null
                                        ? 'Chưa có tọa độ'
                                        : state.location == null
                                        ? null
                                        : '${state.location!.distanceKmTo(branch.coordinates!).toStringAsFixed(1)} km đường thẳng ước tính',
                                onTap: () {
                                  cubit.select(branch.id);
                                  Navigator.of(sheet).pop();
                                },
                              ),
                            if (state.branches.isEmpty)
                              const AppText('Chưa có dữ liệu chi nhánh.'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
          ),
        ),
  );
  @override
  Widget build(BuildContext context) => BlocBuilder<BranchCubit, BranchState>(
    builder: (context, state) {
      final cubit = context.read<BranchCubit>();
      final valid = state.branches.where((b) => b.coordinates != null).toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppText('Bản đồ các chi nhánh', fontWeight: FontWeight.w600),
          const AppText(
            'Chọn để xem vị trí; không thay đổi chi nhánh của hợp đồng.',
            fontSize: 12,
          ),
          if (!state.loading &&
              state.selectedId != null &&
              state.selected == null)
            const AppText(
              'Chi nhánh của hợp đồng chưa có trong danh sách vị trí hiện hành. Xem địa chỉ nhận/trả bên dưới.',
              fontSize: 12,
            ),
          const SizedBox(height: AppSizes.spacingS),
          if (state.loading)
            const SizedBox(
              height: 100,
              child: Center(child: SnapButtonLoader()),
            )
          else if (state.error != null)
            _MapFallback(message: state.error!, retry: cubit.load)
          else if (!BranchMapCard.validToken(token))
            const _MapFallback(
              message:
                  'Chưa có cấu hình bản đồ hợp lệ. Bạn vẫn có thể xem danh sách chi nhánh.',
            )
          else if (valid.isEmpty)
            const _MapFallback(
              message:
                  'Các chi nhánh chưa có tọa độ đã xác minh. Bạn vẫn xem được tên và địa chỉ.',
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSizes.borderRadius),
              child: SizedBox(
                height: 240,
                child: _NativeBranchMap(
                  branches: valid,
                  selectedId: state.selectedId,
                  location: state.location,
                  focusLocation: state.focusLocation,
                  token: token,
                  onSelect: cubit.select,
                ),
              ),
            ),
          if (!state.loading && state.error == null) ...[
            if (state.selected case final Branch selected)
              Padding(
                padding: const EdgeInsets.only(top: AppSizes.spacingS),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(selected.name, fontWeight: FontWeight.w600),
                    AppText(selected.address ?? '', fontSize: 12),
                    if (selected.coordinates == null)
                      const AppText(
                        'Chi nhánh này chưa có tọa độ.',
                        fontSize: 12,
                      ),
                    if (state.location != null && selected.coordinates != null)
                      AppText(
                        '${state.location!.distanceKmTo(selected.coordinates!).toStringAsFixed(1)} km đường thẳng ước tính',
                        fontSize: 12,
                      ),
                    if (selected.coordinates != null)
                      TextButton.icon(
                        icon: const Icon(Icons.directions_outlined),
                        label: const Text('Mở ứng dụng chỉ đường'),
                        onPressed: () async {
                          final opened = await directions.open(
                            selected.coordinates!,
                          );
                          if (!opened && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Không mở được ứng dụng chỉ đường.',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                  ],
                ),
              ),
            Wrap(
              spacing: AppSizes.spacingS,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.storefront_outlined),
                  label: const Text('Các chi nhánh'),
                  onPressed: () => _list(context, cubit),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.my_location),
                  label: const Text('Vị trí của tôi'),
                  onPressed:
                      state.locating
                          ? null
                          : () => cubit.locate(nearest: false),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.near_me_outlined),
                  label: const Text('Tìm chi nhánh gần nhất'),
                  onPressed:
                      state.locating ? null : () => cubit.locate(nearest: true),
                ),
              ],
            ),
            if (state.locating)
              const Align(
                alignment: Alignment.centerLeft,
                child: SnapButtonLoader(),
              ),
            if (state.locationError != null)
              AppText(state.locationError!, fontSize: 12),
            if (state.location != null)
              const AppText(
                'Vị trí chỉ dùng trong màn này. Khoảng cách theo đường thẳng là ước tính.',
                fontSize: 12,
              ),
          ],
        ],
      );
    },
  );
}

class _MapFallback extends StatelessWidget {
  final String message;
  final VoidCallback? retry;
  const _MapFallback({required this.message, this.retry});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSizes.pageMargin),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppSizes.borderRadius),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.map_outlined),
        const SizedBox(height: AppSizes.spacingS),
        AppText(message, fontSize: 12),
        if (retry != null)
          TextButton(onPressed: retry, child: const Text('Thử lại')),
      ],
    ),
  );
}

class _NativeBranchMap extends StatefulWidget {
  final List<Branch> branches;
  final String? selectedId;
  final GeoCoordinates? location;
  final bool focusLocation;
  final String token;
  final void Function(String) onSelect;
  const _NativeBranchMap({
    required this.branches,
    required this.selectedId,
    required this.location,
    required this.focusLocation,
    required this.token,
    required this.onSelect,
  });
  @override
  State<_NativeBranchMap> createState() => _NativeBranchMapState();
}

class _NativeBranchMapState extends State<_NativeBranchMap> {
  mb.MapboxMap? _map;
  mb.CircleAnnotationManager? _markers;
  void Function()? _cancelTaps;
  final _ids = <String, String>{};
  Timer? _timeout;
  String? _error;
  bool _ready = false;
  int _epoch = 0;
  Future<void> _queue = Future.value();
  @override
  void initState() {
    super.initState();
    mb.MapboxOptions.setAccessToken(widget.token);
    _startTimer();
  }

  void _startTimer() {
    final epoch = _epoch;
    _timeout?.cancel();
    _timeout = Timer(const Duration(seconds: 20), () {
      if (mounted && epoch == _epoch && !_ready) _fail();
    });
  }

  void _fail() {
    if (!mounted || _error != null) return;
    _timeout?.cancel();
    _cancelTaps?.call();
    _cancelTaps = null;
    _epoch++;
    _map = null;
    _markers = null;
    setState(
      () =>
          _error =
              'Không tải được bản đồ. Kiểm tra mạng hoặc thử lại; địa chỉ chi nhánh vẫn xem được.',
    );
  }

  mb.Point _point(GeoCoordinates c) =>
      mb.Point(coordinates: mb.Position(c.longitude, c.latitude));
  GeoCoordinates get _center {
    if (widget.focusLocation && widget.location != null) {
      return widget.location!;
    }
    return widget.branches
        .firstWhere(
          (b) => b.id == widget.selectedId,
          orElse: () => widget.branches.first,
        )
        .coordinates!;
  }

  void _sync() {
    final epoch = _epoch;
    _queue = _queue.then((_) async {
      if (!mounted || epoch != _epoch || _map == null) return;
      try {
        final map = _map!;
        if (_markers == null) {
          final manager = await map.annotations.createCircleAnnotationManager();
          if (!mounted || epoch != _epoch) return;
          _markers = manager;
          _cancelTaps =
              manager
                  .tapEvents(
                    onTap: (annotation) {
                      final id = _ids[annotation.id];
                      if (mounted && epoch == _epoch && id != null) {
                        widget.onSelect(id);
                      }
                    },
                  )
                  .cancel;
        }
        final manager = _markers!;
        await manager.deleteAll();
        if (!mounted || epoch != _epoch) return;
        _ids.clear();
        final colors = Theme.of(context).colorScheme;
        for (final branch in widget.branches) {
          final annotation = await manager.create(
            mb.CircleAnnotationOptions(
              geometry: _point(branch.coordinates!),
              circleColor:
                  (branch.id == widget.selectedId
                          ? colors.secondary
                          : colors.primary)
                      .toARGB32(),
              circleRadius: branch.id == widget.selectedId ? 10 : 7,
              circleStrokeColor: colors.surface.toARGB32(),
              circleStrokeWidth: 2,
            ),
          );
          if (!mounted || epoch != _epoch) return;
          _ids[annotation.id] = branch.id;
        }
        if (widget.location != null) {
          await manager.create(
            mb.CircleAnnotationOptions(
              geometry: _point(widget.location!),
              circleColor: colors.tertiary.toARGB32(),
              circleRadius: 7,
              circleStrokeWidth: 3,
              circleStrokeColor: colors.surface.toARGB32(),
            ),
          );
          if (!mounted || epoch != _epoch) return;
        }
        await map.setCamera(
          mb.CameraOptions(center: _point(_center), zoom: 12),
        );
        // SDK logo/attribution remain visible at their default positions; no overlay covers them.
      } catch (_) {
        if (mounted && epoch == _epoch) _fail();
      }
    });
  }

  @override
  void didUpdateWidget(covariant _NativeBranchMap old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _epoch++;
    _timeout?.cancel();
    _cancelTaps?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _MapFallback(
        message: _error!,
        retry: () {
          _epoch++;
          _queue = Future.value();
          _ids.clear();
          setState(() {
            _error = null;
            _ready = false;
          });
          _startTimer();
        },
      );
    }
    final epoch = _epoch;
    return Stack(
      children: [
        Positioned.fill(
          child: mb.MapWidget(
            key: ValueKey(epoch),
            styleUri: mb.MapboxStyles.MAPBOX_STREETS,
            viewport: mb.CameraViewportState(center: _point(_center), zoom: 12),
            onMapCreated: (map) {
              if (mounted && epoch == _epoch) {
                _map = map;
                _sync();
              }
            },
            onStyleLoadedListener: (_) {
              if (mounted && epoch == _epoch) _sync();
            },
            onMapLoadedListener: (_) {
              if (mounted && epoch == _epoch) {
                _timeout?.cancel();
                setState(() => _ready = true);
              }
            },
            onMapLoadErrorListener: (_) {
              if (mounted && epoch == _epoch) _fail();
            },
          ),
        ),
        if (!_ready)
          const Center(child: IgnorePointer(child: SnapButtonLoader())),
      ],
    );
  }
}
