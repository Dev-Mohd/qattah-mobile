import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/repositories.dart';

final listRepositoryProvider = Provider<ListRepository>((ref) => ListRepository());
final memberRepositoryProvider = Provider<MemberRepository>((ref) => MemberRepository());
final mealTypeRepositoryProvider = Provider<MealTypeRepository>((ref) => MealTypeRepository());
final paymentRepositoryProvider = Provider<PaymentRepository>((ref) => PaymentRepository());
final recordRepositoryProvider = Provider<RecordRepository>((ref) => RecordRepository());
