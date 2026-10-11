import 'package:equatable/equatable.dart';

abstract class ExploreEvent extends Equatable {
  const ExploreEvent();

  @override
  List<Object?> get props => [];
}

class ExploreCriteriaChanged extends ExploreEvent {
  final String? keyword;
  final String? categoryId;
  final String? brandId;
  final String? branchId;

  const ExploreCriteriaChanged({
    this.keyword,
    this.categoryId,
    this.brandId,
    this.branchId,
  });

  @override
  List<Object?> get props => [keyword, categoryId, brandId, branchId];
}

class ExploreLoadMore extends ExploreEvent {}

class ExploreRetry extends ExploreEvent {}
