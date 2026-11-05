import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/meal_type_model.dart';
import 'repository_providers.dart';

// ─── Read ─────────────────────────────────────────────────────────────────────

final mealTypesProvider =
    FutureProvider.family<List<MealTypeModel>, String>((ref, listId) async {
  final repo = ref.watch(mealTypeRepositoryProvider);
  return repo.getByListId(listId);
});

// ─── Write ────────────────────────────────────────────────────────────────────

class MealTypeState {
  final bool isLoading;
  final String? error;
  const MealTypeState({this.isLoading = false, this.error});

  MealTypeState copyWith(
          {bool? isLoading, String? error, bool clearError = false}) =>
      MealTypeState(
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

class MealTypeNotifier extends StateNotifier<MealTypeState> {
  MealTypeNotifier(this._ref) : super(const MealTypeState());

  final Ref _ref;

  Future<bool> addMealType({
    required String listId,
    required String name,
    required double defaultPrice,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repo = _ref.read(mealTypeRepositoryProvider);
      final cleanName = name.trim();
      if (cleanName.isEmpty) {
        state = state.copyWith(isLoading: false, error: 'أدخل اسم الوجبة');
        return false;
      }
      if (defaultPrice < 0) {
        state = state.copyWith(
            isLoading: false, error: 'السعر لا يمكن أن يكون سالبًا');
        return false;
      }
      final meals = await repo.getByListId(listId);
      if (_hasDuplicateName(meals.map((m) => m.name), cleanName)) {
        state =
            state.copyWith(isLoading: false, error: 'يوجد نوع وجبة بنفس الاسم');
        return false;
      }
      final now = DateTime.now().toIso8601String();
      await repo.insert(MealTypeModel(
        id: const Uuid().v4(),
        listId: listId,
        name: cleanName,
        defaultPrice: defaultPrice,
        createdAt: now,
        updatedAt: now,
      ));
      _ref.invalidate(mealTypesProvider(listId));
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> updateMealType(MealTypeModel meal) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repo = _ref.read(mealTypeRepositoryProvider);
      final cleanName = meal.name.trim();
      if (cleanName.isEmpty) {
        state = state.copyWith(isLoading: false, error: 'أدخل اسم الوجبة');
        return false;
      }
      if (meal.defaultPrice < 0) {
        state = state.copyWith(
            isLoading: false, error: 'السعر لا يمكن أن يكون سالبًا');
        return false;
      }
      final meals = await repo.getByListId(meal.listId);
      if (_hasDuplicateName(
        meals.where((item) => item.id != meal.id).map((item) => item.name),
        cleanName,
      )) {
        state =
            state.copyWith(isLoading: false, error: 'يوجد نوع وجبة بنفس الاسم');
        return false;
      }
      await repo.update(meal.copyWith(
        name: cleanName,
        updatedAt: DateTime.now().toIso8601String(),
      ));
      _ref.invalidate(mealTypesProvider(meal.listId));
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> deleteMealType({
    required String id,
    required String listId,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repo = _ref.read(mealTypeRepositoryProvider);
      await repo.delete(id);
      _ref.invalidate(mealTypesProvider(listId));
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  bool _hasDuplicateName(Iterable<String> names, String name) {
    final normalized = _normalizeName(name);
    return names.any((item) => _normalizeName(item) == normalized);
  }

  String _normalizeName(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}

final mealTypeNotifierProvider =
    StateNotifierProvider<MealTypeNotifier, MealTypeState>(
  (ref) => MealTypeNotifier(ref),
);
