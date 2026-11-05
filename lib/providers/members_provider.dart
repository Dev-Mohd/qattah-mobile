import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'extensions.dart';
import '../models/member_model.dart';
import 'repository_providers.dart';

final membersProvider = FutureProvider.autoDispose
    .family<List<MemberModel>, String>((ref, listId) async {
  ref.cacheFor(const Duration(minutes: 5));
  final repo = ref.watch(memberRepositoryProvider);
  return repo.getByListId(listId);
});

// ... (باقي الكود)

// ─── Write ────────────────────────────────────────────────────────────────────

class MemberState {
  final bool isLoading;
  final String? error;
  const MemberState({this.isLoading = false, this.error});

  MemberState copyWith(
          {bool? isLoading, String? error, bool clearError = false}) =>
      MemberState(
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

class MemberNotifier extends StateNotifier<MemberState> {
  MemberNotifier(this._ref) : super(const MemberState());

  final Ref _ref;

  Future<bool> addMember({
    required String listId,
    required String name,
    required double openingBalance,
    bool isDefaultAttendee = true,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repo = _ref.read(memberRepositoryProvider);
      final cleanName = name.trim();
      if (cleanName.isEmpty) {
        state = state.copyWith(isLoading: false, error: 'أدخل اسم العضو');
        return false;
      }
      if (openingBalance < 0) {
        state = state.copyWith(
            isLoading: false, error: 'الرصيد السابق لا يمكن أن يكون سالبًا');
        return false;
      }
      final members = await repo.getByListId(listId);
      if (_hasDuplicateName(members.map((m) => m.name), cleanName)) {
        state = state.copyWith(isLoading: false, error: 'يوجد عضو بنفس الاسم');
        return false;
      }
      final now = DateTime.now().toIso8601String();
      await repo.insert(MemberModel(
        id: const Uuid().v4(),
        listId: listId,
        name: cleanName,
        openingBalance: openingBalance,
        isDefaultAttendee: isDefaultAttendee,
        createdAt: now,
        updatedAt: now,
      ));
      _ref.invalidate(membersProvider(listId));
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> updateMember(MemberModel member) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repo = _ref.read(memberRepositoryProvider);
      final cleanName = member.name.trim();
      if (cleanName.isEmpty) {
        state = state.copyWith(isLoading: false, error: 'أدخل اسم العضو');
        return false;
      }
      if (member.openingBalance < 0) {
        state = state.copyWith(
            isLoading: false, error: 'الرصيد السابق لا يمكن أن يكون سالبًا');
        return false;
      }
      final members = await repo.getByListId(member.listId);
      if (_hasDuplicateName(
        members.where((item) => item.id != member.id).map((item) => item.name),
        cleanName,
      )) {
        state = state.copyWith(isLoading: false, error: 'يوجد عضو بنفس الاسم');
        return false;
      }
      await repo.update(member.copyWith(
        name: cleanName,
        updatedAt: DateTime.now().toIso8601String(),
      ));
      _ref.invalidate(membersProvider(member.listId));
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> deleteMember({
    required String id,
    required String listId,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repo = _ref.read(memberRepositoryProvider);
      await repo.delete(id);
      _ref.invalidate(membersProvider(listId));
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

final memberNotifierProvider =
    StateNotifierProvider<MemberNotifier, MemberState>(
  (ref) => MemberNotifier(ref),
);
