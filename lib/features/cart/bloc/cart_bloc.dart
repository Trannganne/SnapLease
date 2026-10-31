import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import '../../../core/storage/token_storage.dart';
import '../data/repositories/mock_cart_repository.dart';
import '../domain/repositories/cart_repository.dart';
import 'cart_event.dart';
import 'cart_state.dart';

class CartBloc extends Bloc<CartEvent, CartState> {
  final CartRepository repository;
  StreamSubscription<void>? _session;
  int _generation = 0;
  int _loadRequest = 0;
  @override
  Future<void> close() {
    ++_generation;
    _session?.cancel();
    return super.close();
  }

  CartBloc({required this.repository, CartState? initialState})
    : super(initialState ?? const CartState()) {
    on<CartStarted>(_onStarted);
    on<CartItemPeriodOrBranchChanged>((event, emit) async {
      if (state.checkingOut ||
          state.isRefreshing ||
          state.updatingItemIds.contains(event.itemId)) {
        return;
      }
      if (!state.items.any((i) => i.id == event.itemId)) return;
      final generation = _generation;
      final item = state.items.singleWhere((i) => i.id == event.itemId);
      emit(
        state.copyWith(
          updatingItemIds: {...state.updatingItemIds, event.itemId},
        ),
      );
      try {
        final updated = await repository.updateItem(
          item,
          start: event.start,
          end: event.end,
          branchId: event.branchId,
        );
        if (isClosed || generation != _generation) return;
        emit(
          state.copyWith(
            items:
                state.items.map((i) => i.id == item.id ? updated : i).toList(),
            updatingItemIds: {...state.updatingItemIds}..remove(item.id),
          ),
        );
      } catch (e) {
        if (isClosed || generation != _generation) return;
        emit(
          state.copyWith(
            updatingItemIds: {...state.updatingItemIds}..remove(item.id),
            errorMessage: e.toString(),
          ),
        );
      }
    });
    on<CartItemQuantityChanged>(_onQuantityChanged);
    on<CartItemSelectionToggled>(_onSelectionToggled);
    on<CartItemRemoveRequested>(_onRemoveRequested);
    on<CartEditModeToggled>(_onEditModeToggled);
    on<CartResetRequested>(_onResetRequested);
    on<CartItemAdded>((event, emit) async {
      final generation = _generation;
      try {
        await repository.addItem(
          modelId: event.modelId,
          branchId: event.branchId,
          quantity: event.quantity,
          start: event.start,
          end: event.end,
        );
        if (!isClosed && generation == _generation) {
          add(const CartStarted(isRefresh: true));
        }
      } catch (e) {
        if (!isClosed && generation == _generation) {
          emit(state.copyWith(errorMessage: e.toString()));
        }
      }
    });
    _session = TokenStorage.changes.listen((_) {
      ++_generation;
      repository.invalidateSession();
      add(const CartSessionChanged());
    });
    on<CartSessionChanged>((event, emit) {
      emit(const CartState());
      add(const CartStarted());
    });
    on<CartCheckoutRequested>((event, emit) async {
      if (state.checkingOut ||
          state.isRefreshing ||
          state.updatingItemIds.isNotEmpty) {
        return;
      }
      final generation = _generation;
      final selected =
          state.items.where((i) => i.isSelected && i.isAvailable).toList();
      emit(state.copyWith(checkingOut: true));
      try {
        final checkout = await repository.checkout(selected);
        if (!isClosed && generation == _generation) {
          emit(state.copyWith(checkingOut: false, checkout: checkout));
        }
      } catch (e) {
        if (!isClosed && generation == _generation) {
          emit(state.copyWith(checkingOut: false, errorMessage: e.toString()));
        }
      }
    });
  }

  Future<void> _onStarted(CartStarted event, Emitter<CartState> emit) async {
    if (state.checkingOut || state.updatingItemIds.isNotEmpty) return;
    final generation = _generation;
    final request = ++_loadRequest;
    if (event.isRefresh) {
      emit(state.copyWith(isRefreshing: true));
    } else if (state.status != CartStatus.loaded) {
      emit(state.copyWith(status: CartStatus.loading));
    }

    try {
      final items = await repository.getCartItems(
        forceRefresh: event.isRefresh,
      );
      if (isClosed || generation != _generation || request != _loadRequest) {
        return;
      }
      emit(
        state.copyWith(
          status: CartStatus.loaded,
          items: items,
          isRefreshing: false,
          errorMessage: null,
        ),
      );
    } catch (e) {
      if (isClosed || generation != _generation || request != _loadRequest) {
        return;
      }
      if (event.isRefresh) {
        emit(state.copyWith(isRefreshing: false, errorMessage: e.toString()));
      } else {
        emit(
          state.copyWith(
            status: CartStatus.failure,
            errorMessage: 'Không thể tải giỏ hàng. Vui lòng thử lại.',
            isRefreshing: false,
          ),
        );
      }
    }
  }

  Future<void> _onQuantityChanged(
    CartItemQuantityChanged event,
    Emitter<CartState> emit,
  ) async {
    if (state.checkingOut ||
        state.isRefreshing ||
        state.updatingItemIds.contains(event.cartItemId)) {
      return;
    }
    final generation = _generation;

    final updatedIds = Set<String>.from(state.updatingItemIds)
      ..add(event.cartItemId);
    emit(state.copyWith(updatingItemIds: updatedIds));

    try {
      final updatedItem = await repository.updateQuantity(
        cartItemId: event.cartItemId,
        quantity: event.quantity,
      );
      if (isClosed || generation != _generation) return;

      final newItems =
          state.items.map((i) {
            return i.id == event.cartItemId ? updatedItem : i;
          }).toList();

      final remainingIds = Set<String>.from(state.updatingItemIds)
        ..remove(event.cartItemId);

      emit(state.copyWith(items: newItems, updatingItemIds: remainingIds));
    } catch (e) {
      if (isClosed || generation != _generation) return;
      final remainingIds = Set<String>.from(state.updatingItemIds)
        ..remove(event.cartItemId);
      emit(
        state.copyWith(
          updatingItemIds: remainingIds,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onSelectionToggled(
    CartItemSelectionToggled event,
    Emitter<CartState> emit,
  ) async {
    if (state.checkingOut) return;
    final generation = _generation;
    try {
      final updatedItem = await repository.toggleItemSelection(
        cartItemId: event.cartItemId,
        isSelected: event.isSelected,
      );
      if (isClosed || generation != _generation) return;

      final newItems =
          state.items.map((i) {
            return i.id == event.cartItemId ? updatedItem : i;
          }).toList();

      emit(state.copyWith(items: newItems));
    } catch (e) {
      if (isClosed || generation != _generation) return;
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onRemoveRequested(
    CartItemRemoveRequested event,
    Emitter<CartState> emit,
  ) async {
    if (state.checkingOut ||
        state.isRefreshing ||
        state.updatingItemIds.contains(event.cartItemId)) {
      return;
    }
    final generation = _generation;

    final updatedIds = Set<String>.from(state.updatingItemIds)
      ..add(event.cartItemId);
    emit(state.copyWith(updatingItemIds: updatedIds));

    try {
      await repository.removeItem(cartItemId: event.cartItemId);
      if (isClosed || generation != _generation) return;

      final newItems =
          state.items.where((i) => i.id != event.cartItemId).toList();
      final remainingIds = Set<String>.from(state.updatingItemIds)
        ..remove(event.cartItemId);

      emit(
        state.copyWith(
          items: newItems,
          updatingItemIds: remainingIds,
          isEditMode: newItems.isEmpty ? false : state.isEditMode,
        ),
      );
    } catch (e) {
      if (isClosed || generation != _generation) return;
      final remainingIds = Set<String>.from(state.updatingItemIds)
        ..remove(event.cartItemId);
      emit(
        state.copyWith(
          updatingItemIds: remainingIds,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  void _onEditModeToggled(CartEditModeToggled event, Emitter<CartState> emit) {
    emit(state.copyWith(isEditMode: !state.isEditMode));
  }

  Future<void> _onResetRequested(
    CartResetRequested event,
    Emitter<CartState> emit,
  ) async {
    if (repository is MockCartRepository) {
      (repository as MockCartRepository).resetToDefault();
    }
    emit(const CartState(status: CartStatus.loading));
    add(const CartStarted());
  }
}
