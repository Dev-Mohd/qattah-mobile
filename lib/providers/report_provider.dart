import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'extensions.dart';
import '../models/record_participant_model.dart';
import 'payments_provider.dart';
import 'records_provider.dart';

// ════════════════════════════════════════════════════════════════════
//  REPORT DATA MODELS
// ════════════════════════════════════════════════════════════════════

class MemberStat {
  final String key;
  final String name;
  int days;
  double total;
  double paid;

  MemberStat({
    required this.key,
    required this.name,
    this.days = 0,
    this.total = 0.0,
    this.paid = 0.0,
  });

  double get remaining => total - paid;
}

class ReportData {
  final List<MemberStat> stats;
  final double grandTotal;
  final double expenseTotal;
  final double paymentTotal;
  final int recordCount;
  final int paymentCount;
  final int maxDays;
  final List<MapEntry<String, double>> dailyTotals;
  final List<MapEntry<String, double>> dailyPaymentTotals;

  const ReportData({
    required this.stats,
    required this.grandTotal,
    required this.expenseTotal,
    required this.paymentTotal,
    required this.recordCount,
    required this.paymentCount,
    required this.maxDays,
    required this.dailyTotals,
    required this.dailyPaymentTotals,
  });

  static const empty = ReportData(
    stats: [],
    grandTotal: 0,
    expenseTotal: 0,
    paymentTotal: 0,
    recordCount: 0,
    paymentCount: 0,
    maxDays: 1,
    dailyTotals: [],
    dailyPaymentTotals: [],
  );
}

// ════════════════════════════════════════════════════════════════════
//  REPORT PARAMS
// ════════════════════════════════════════════════════════════════════

class ReportParams {
  final String listId;
  final String monthKey; // e.g. "2026-05"

  const ReportParams({required this.listId, required this.monthKey});

  @override
  bool operator ==(Object other) =>
      other is ReportParams &&
      other.listId == listId &&
      other.monthKey == monthKey;

  @override
  int get hashCode => Object.hash(listId, monthKey);
}

// ════════════════════════════════════════════════════════════════════
//  REPORT PROVIDER
// ════════════════════════════════════════════════════════════════════

final reportDataProvider = FutureProvider.autoDispose
    .family<ReportData, ReportParams>((ref, params) async {
  ref.cacheFor(const Duration(minutes: 3));

  final records = await ref.watch(recordsProvider(params.listId).future);
  final participants =
      await ref.watch(allParticipantsProvider(params.listId).future);
  final payments = await ref.watch(paymentsProvider(params.listId).future);

  // فلترة السجلات حسب الشهر
  final filtered =
      records.where((r) => r.date.startsWith(params.monthKey)).toList();
  final filteredPayments =
      payments.where((p) => p.createdAt.startsWith(params.monthKey)).toList();

  if (filtered.isEmpty && filteredPayments.isEmpty) return ReportData.empty;

  // بناء map سريع: recordId → participants
  final partMap = <String, List<RecordParticipantModel>>{};
  for (final p in participants) {
    partMap.putIfAbsent(p.recordId, () => []).add(p);
  }

  final memberMap = <String, MemberStat>{};
  final dailyMap = <String, double>{};
  final dailyPaymentMap = <String, double>{};

  for (final r in filtered) {
    dailyMap[r.date] = (dailyMap[r.date] ?? 0) + r.totalAmount;

    for (final p in partMap[r.id] ?? <RecordParticipantModel>[]) {
      final key = _memberStatKey(memberMap, p.memberId, p.memberName);
      memberMap.putIfAbsent(
        key,
        () => MemberStat(key: key, name: p.memberName),
      );
      memberMap[key]!.days++;
      memberMap[key]!.total += p.share;
    }
  }

  for (final p in filteredPayments) {
    final day =
        p.createdAt.length >= 10 ? p.createdAt.substring(0, 10) : p.createdAt;
    dailyPaymentMap[day] = (dailyPaymentMap[day] ?? 0) + p.amount;
    final key = _memberStatKey(memberMap, p.memberId, p.memberName);
    memberMap.putIfAbsent(
      key,
      () => MemberStat(key: key, name: p.memberName),
    );
    memberMap[key]!.paid += p.amount;
  }

  final stats = memberMap.values.toList()
    ..sort((a, b) => b.remaining.compareTo(a.remaining));

  final sortedDays = dailyMap.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  final sortedPaymentDays = dailyPaymentMap.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));

  final expenseTotal = stats.fold<double>(0, (s, m) => s + m.total);
  final paymentTotal = stats.fold<double>(0, (s, m) => s + m.paid);

  return ReportData(
    stats: stats,
    grandTotal: expenseTotal - paymentTotal,
    expenseTotal: expenseTotal,
    paymentTotal: paymentTotal,
    recordCount: filtered.length,
    paymentCount: filteredPayments.length,
    maxDays: stats.isEmpty
        ? 1
        : stats.map((s) => s.days).reduce((a, b) => a > b ? a : b),
    dailyTotals: sortedDays,
    dailyPaymentTotals: sortedPaymentDays,
  );
});

String _memberStatKey(
  Map<String, MemberStat> current,
  String? memberId,
  String memberName,
) {
  if (memberId == null || memberId.isEmpty) return memberName;
  if (current.containsKey(memberId)) return memberId;
  if (current.containsKey(memberName)) return memberName;
  return memberId;
}
