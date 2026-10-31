import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentcam/domain/entities/branch.dart';
import 'package:rentcam/domain/entities/geo_coordinates.dart';
import 'package:rentcam/features/branches/domain/branch_repository.dart';
import 'package:rentcam/features/branches/data/branch_directions.dart';
import 'package:rentcam/features/branches/data/branch_location_service.dart';
import 'package:rentcam/features/branches/presentation/branch_cubit.dart';
import 'package:rentcam/features/branches/presentation/branch_map_card.dart';
import 'package:rentcam/features/chat/presentation/chat_availability_cubit.dart';
import 'chatbot_feature_test.dart' show FakeChat;

class FakeBranches implements BranchRepository {
  int calls = 0;
  Completer<List<Branch>>? pending;
  final List<Branch> rows = [
    const Branch(
      id: 'SYNTHETIC-FAR',
      name: 'Far',
      address: 'Synthetic address',
      coordinates: GeoCoordinates(12, 107),
    ),
    const Branch(
      id: 'SYNTHETIC-NO-COORDS',
      name: 'No coordinates',
      address: 'Synthetic address',
    ),
    const Branch(
      id: 'SYNTHETIC-NEAR',
      name: 'Near',
      address: 'Synthetic address',
      coordinates: GeoCoordinates(10, 106),
    ),
  ];
  @override
  Future<List<Branch>> getBranches() async {
    calls++;
    return pending == null ? rows : pending!.future;
  }
}

class FakeLocation implements BranchLocationService {
  int calls = 0;
  bool denied = false;
  Completer<GeoCoordinates>? pending;
  @override
  Future<GeoCoordinates> current() async {
    calls++;
    if (denied) throw const LocationFailure('Từ chối quyền vị trí');
    return pending == null
        ? const GeoCoordinates(10.01, 106.01)
        : pending!.future;
  }
}

void main() {
  test(
    'coordinate pairs must be numeric, finite and in range; zero is valid',
    () {
      for (final pair in [
        [null, 1],
        [1, null],
        ['10', 106],
        [91, 106],
        [10, -181],
        [double.nan, 106],
        [10, double.infinity],
      ]) {
        expect(GeoCoordinates.parse(pair[0], pair[1]), isNull);
      }
      expect(GeoCoordinates.parse(0, 0), isNotNull);
      expect(GeoCoordinates.parse(-90, 180), isNotNull);
      expect(
        Branch.fromJson({
          'maCuaHang': 'SYNTHETIC',
          'tenCuaHang': 'Test',
          'viDo': 1,
        }).coordinates,
        isNull,
      );
      expect(
        const GeoCoordinates(0, 0).distanceKmTo(const GeoCoordinates(0, 1)),
        closeTo(111.195, 0.01),
      );
    },
  );
  test(
    'load never requests location; nearest excludes branches without coordinates',
    () async {
      final repo = FakeBranches();
      final location = FakeLocation();
      final cubit = BranchCubit(repository: repo, locationService: location);
      await cubit.load();
      expect(location.calls, 0);
      expect(cubit.state.branches.length, 3);
      await cubit.locate(nearest: true);
      expect(location.calls, 1);
      expect(cubit.state.selectedId, 'SYNTHETIC-NEAR');
      expect(cubit.state.ordered.last.id, 'SYNTHETIC-NO-COORDS');
      await cubit.close();
    },
  );
  test(
    'permission denied preserves branch list/selection and closed cubit ignores location',
    () async {
      final location = FakeLocation()..denied = true;
      final cubit = BranchCubit(
        repository: FakeBranches(),
        locationService: location,
        selectedId: 'SYNTHETIC-FAR',
      );
      await cubit.load();
      await cubit.locate(nearest: true);
      expect(cubit.state.branches.length, 3);
      expect(cubit.state.selectedId, 'SYNTHETIC-FAR');
      expect(cubit.state.locationError, contains('Từ chối'));
      location.denied = false;
      location.pending = Completer<GeoCoordinates>();
      final pending = cubit.locate(nearest: true);
      await Future<void>.delayed(Duration.zero);
      await cubit.close();
      location.pending!.complete(const GeoCoordinates(10, 106));
      await pending;
    },
  );
  test(
    'late branch fetch ignored after dispose; forged selection ignored',
    () async {
      final repo = FakeBranches()..pending = Completer<List<Branch>>();
      final cubit = BranchCubit(
        repository: repo,
        locationService: FakeLocation(),
      );
      final load = cubit.load();
      cubit.select('forged');
      expect(cubit.state.selectedId, isNull);
      await cubit.close();
      repo.pending!.complete(repo.rows);
      await load;
    },
  );
  test(
    'directions passes public destination only and preserves coordinate order',
    () async {
      Uri? sent;
      final directions = BranchDirections(
        launch: (uri) async {
          sent = uri;
          return true;
        },
      );
      expect(await directions.open(const GeoCoordinates(10, 106)), isTrue);
      expect(sent!.queryParameters, {'api': '1', 'destination': '10.0,106.0'});
      expect(sent.toString(), isNot(contains('token')));
      expect(await directions.open(const GeoCoordinates(91, 106)), isFalse);
      expect(
        await BranchDirections(
          launch: (_) async => false,
        ).open(const GeoCoordinates(10, 106)),
        isFalse,
      );
    },
  );
  test('secret/missing map tokens rejected before native widget', () {
    expect(BranchMapCard.validToken('sk.synthetic-secret'), isFalse);
    expect(BranchMapCard.validToken(''), isFalse);
    expect(BranchMapCard.validToken('pk.synthetic-test-token-12345'), isTrue);
  });
  test(
    'availability requires selection, clears old result when branch changes',
    () async {
      final cubit = ChatAvailabilityCubit(
        branches: FakeBranches(),
        repository: FakeChat(),
        productId: 'SYNTHETIC-MODEL',
      );
      await cubit.load();
      await cubit.check(DateTime(2026, 11, 1), DateTime(2026, 11, 2));
      expect(cubit.state.count, isNull);
      cubit.select('SYNTHETIC-NEAR');
      await cubit.check(DateTime(2026, 11, 2), DateTime(2026, 11, 1));
      expect(cubit.state.count, isNull);
      await cubit.check(DateTime(2026, 11, 1), DateTime(2026, 11, 2));
      expect(cubit.state.count, 1);
      cubit.select('SYNTHETIC-FAR');
      expect(cubit.state.count, isNull);
      await cubit.close();
    },
  );
  testWidgets('disabled map never fetches or requests location', (
    tester,
  ) async {
    final repo = FakeBranches(), location = FakeLocation();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BranchMapCard(
            enabled: false,
            repository: repo,
            locationService: location,
          ),
        ),
      ),
    );
    expect(repo.calls, 0);
    expect(location.calls, 0);
    expect(find.textContaining('chưa được bật'), findsOneWidget);
  });
  testWidgets(
    'missing token still shows all branches; location denied keeps list',
    (tester) async {
      final location = FakeLocation()..denied = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BranchMapCard(
                enabled: true,
                token: '',
                repository: FakeBranches(),
                locationService: location,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(location.calls, 0);
      expect(find.textContaining('cấu hình bản đồ'), findsOneWidget);
      await tester.tap(find.text('Vị trí của tôi'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Từ chối quyền vị trí'), findsOneWidget);
      await tester.tap(find.text('Các chi nhánh'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('No coordinates'), findsOneWidget);
      expect(find.text('Chưa có tọa độ'), findsOneWidget);
      expect(find.text('Near'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
