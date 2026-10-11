abstract class HomeEvent {}

class LoadHomeData extends HomeEvent {}

class ApplyFilters extends HomeEvent {
  final String category;
  final String branch;

  ApplyFilters({required this.category, required this.branch});
}
