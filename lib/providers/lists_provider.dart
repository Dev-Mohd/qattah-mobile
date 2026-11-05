import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'extensions.dart';
import '../models/list_model.dart';
import 'repository_providers.dart';

// ─── Read ─────────────────────────────────────────────────────────────────────

/// القوائم — تبقى في الذاكرة 10 دقائق (تتغير نادراً)
final listsProvider = FutureProvider.autoDispose<List<ListModel>>((ref) async {
  ref.cacheFor(const Duration(minutes: 10));
  final repo = ref.watch(listRepositoryProvider);
  return repo.getAll();
});

// ─── Write ────────────────────────────────────────────────────────────────────

class ListState {
  final bool    isLoading;
  final String? error;
  const ListState({this.isLoading = false, this.error});

  ListState copyWith({bool? isLoading, String? error, bool clearError = false}) =>
      ListState(
        isLoading: isLoading ?? this.isLoading,
        error:     clearError ? null : (error ?? this.error),
      );
}

class ListNotifier extends StateNotifier<ListState> {
  ListNotifier(this._ref) : super(const ListState());

  final Ref _ref;

  Future<bool> createList({required String name, required String color}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repo = _ref.read(listRepositoryProvider);
      final cleanName = name.trim();
      if (cleanName.isEmpty) {
        state = state.copyWith(isLoading: false, error: 'أدخل اسم القائمة');
        return false;
      }
      final lists = await repo.getAll();
      if (_hasDuplicateName(lists.map((l) => l.name), cleanName)) {
        state = state.copyWith(isLoading: false, error: 'توجد قائمة بنفس الاسم');
        return false;
      }
      final now = DateTime.now().toIso8601String();
      await repo.insert(ListModel(
        id:        const Uuid().v4(),
        name:      cleanName,
        color:     color,
        createdAt: now,
        updatedAt: now,
      ));

      // Invalidate and refresh the lists provider
      _ref.invalidate(listsProvider);

      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> updateList(ListModel list) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repo = _ref.read(listRepositoryProvider);
      final cleanName = list.name.trim();
      if (cleanName.isEmpty) {
        state = state.copyWith(isLoading: false, error: 'أدخل اسم القائمة');
        return false;
      }
      final lists = await repo.getAll();
      if (_hasDuplicateName(
        lists.where((item) => item.id != list.id).map((item) => item.name),
        cleanName,
      )) {
        state = state.copyWith(isLoading: false, error: 'توجد قائمة بنفس الاسم');
        return false;
      }
      await repo.update(list.copyWith(
        name: cleanName,
        updatedAt: DateTime.now().toIso8601String(),
      ));
      _ref.invalidate(listsProvider);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> deleteList(String id) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repo = _ref.read(listRepositoryProvider);
      await repo.delete(id);
      _ref.invalidate(listsProvider);
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

final listNotifierProvider =
StateNotifierProvider<ListNotifier, ListState>(
      (ref) => ListNotifier(ref),
);
