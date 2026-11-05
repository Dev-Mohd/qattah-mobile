import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'extensions.dart';
import '../models/member_model.dart';
import '../models/payment_model.dart';
import 'repository_providers.dart';

final paymentsProvider =
    FutureProvider.autoDispose.family<List<PaymentModel>, String>((ref, listId) async {
  ref.cacheFor(const Duration(minutes: 5));
  final repo = ref.watch(paymentRepositoryProvider);
  return repo.getByListId(listId);
});

class PaymentState {
  final bool isLoading;
  final String? error;

  const PaymentState({this.isLoading = false, this.error});

  PaymentState copyWith({bool? isLoading, String? error, bool clearError = false}) {
    return PaymentState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class PaymentNotifier extends StateNotifier<PaymentState> {
  PaymentNotifier(this._ref) : super(const PaymentState());

  final Ref _ref;

  Future<bool> addPayment({
    required MemberModel member,
    required double amount,
    String note = '',
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      if (amount <= 0) {
        state = state.copyWith(isLoading: false, error: 'مبلغ السداد يجب أن يكون أكبر من صفر');
        return false;
      }
      final now = DateTime.now().toIso8601String();
      final repo = _ref.read(paymentRepositoryProvider);
      await repo.insert(PaymentModel(
        id: const Uuid().v4(),
        listId: member.listId,
        memberId: member.id,
        memberName: member.name,
        amount: amount,
        note: note.trim(),
        createdAt: now,
        updatedAt: now,
      ));
      _ref.invalidate(paymentsProvider(member.listId));
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> deletePayment(String id, String listId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repo = _ref.read(paymentRepositoryProvider);
      await repo.delete(id);
      _ref.invalidate(paymentsProvider(listId));
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> updatePayment(PaymentModel payment) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      if (payment.amount <= 0) {
        state = state.copyWith(isLoading: false, error: 'مبلغ السداد يجب أن يكون أكبر من صفر');
        return false;
      }
      final repo = _ref.read(paymentRepositoryProvider);
      await repo.update(
        payment.copyWith(updatedAt: DateTime.now().toIso8601String()),
      );
      _ref.invalidate(paymentsProvider(payment.listId));
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> restorePayment(PaymentModel payment) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repo = _ref.read(paymentRepositoryProvider);
      await repo.insert(payment);
      _ref.invalidate(paymentsProvider(payment.listId));
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}

final paymentNotifierProvider =
    StateNotifierProvider<PaymentNotifier, PaymentState>((ref) => PaymentNotifier(ref));
