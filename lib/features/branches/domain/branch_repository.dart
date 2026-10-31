import '../../../domain/entities/branch.dart';

abstract interface class BranchRepository {
  Future<List<Branch>> getBranches();
}
