import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'extensions.dart';
import '../models/record_model.dart';
import '../models/record_participant_model.dart';
import 'repository_providers.dart';

final recordsProvider =
FutureProvider.autoDispose.family<List<RecordModel>, String>((ref, listId) async {
  ref.cacheFor(const Duration(minutes: 5));
  final repo = ref.watch(recordRepositoryProvider);
  return repo.getByListId(listId);
});

final participantsProvider =
FutureProvider.autoDispose.family<List<RecordParticipantModel>, String>(
        (ref, recordId) async {
      ref.cacheFor(const Duration(minutes: 2));
      final repo = ref.watch(recordRepositoryProvider);
      return repo.getParticipants(recordId);
    });

final allParticipantsProvider =
FutureProvider.autoDispose.family<List<RecordParticipantModel>, String>(
        (ref, listId) async {
      ref.cacheFor(const Duration(minutes: 5));
      final repo = ref.watch(recordRepositoryProvider);
      return repo.getAllParticipantsByListId(listId);
    });

// ... (باقي الكود)
// ─── RecordNotifier State ─────────────────────────────────────────────────────

class RecordState {
  final bool isLoading;
  final String? error;

  const RecordState({
    this.isLoading = false,
    this.error,
  });

  RecordState copyWith({
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return RecordState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ─── RecordNotifier ───────────────────────────────────────────────────────────

class RecordNotifier extends StateNotifier<RecordState> {
  RecordNotifier(this._ref) : super(const RecordState());

  final Ref _ref;

  /// إنشاء سجل جديد مع المشاركين
  Future<bool> createRecord(
      RecordModel record,
      List<RecordParticipantModel> participants,
      ) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repo = _ref.read(recordRepositoryProvider);
      await repo.createRecordWithParticipants(record, participants);
      _invalidateRecords(record.listId);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// تحديث سجل موجود
  Future<bool> updateRecord(
      RecordModel record,
      List<RecordParticipantModel> participants,
      ) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repo = _ref.read(recordRepositoryProvider);
      await repo.updateRecordWithParticipants(record, participants);
      _invalidateRecords(record.listId);
      _invalidateParticipants(record.id);
      _ref.invalidate(allParticipantsProvider(record.listId));
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// حذف سجل
  Future<bool> deleteRecord(String recordId, String listId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repo = _ref.read(recordRepositoryProvider);
      await repo.delete(recordId);
      _invalidateRecords(listId);
      _invalidateParticipants(recordId);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> restoreRecord(
    RecordModel record,
    List<RecordParticipantModel> participants,
  ) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repo = _ref.read(recordRepositoryProvider);
      await repo.createRecordWithParticipants(record, participants);
      _invalidateRecords(record.listId);
      _invalidateParticipants(record.id);
      _ref.invalidate(allParticipantsProvider(record.listId));
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  // ─── Private Helpers ────────────────────────────────────────────────────────

  void _invalidateRecords(String listId) {
    _ref.invalidate(recordsProvider(listId));
  }

  void _invalidateParticipants(String recordId) {
    _ref.invalidate(participantsProvider(recordId));
  }
}

// ─── RecordNotifier Provider ──────────────────────────────────────────────────

final recordNotifierProvider =
StateNotifierProvider<RecordNotifier, RecordState>(
      (ref) => RecordNotifier(ref),
);
