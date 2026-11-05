import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/enums.dart';

// ═══════════════════════════════════════════
//  ACCENT COLOR PROVIDER
// ═══════════════════════════════════════════

final accentColorProvider = AsyncNotifierProvider<AccentColorNotifier, Color>(
  AccentColorNotifier.new,
);

class AccentColorNotifier extends AsyncNotifier<Color> {
  static const _defaultColor = Color(0xFF2563EB);
  static const _key = 'q6h.accent';

  @override
  Future<Color> build() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getInt(_key);
    return val != null ? Color(val) : _defaultColor;
  }

  Future<void> setColor(Color color) async {
    state = const AsyncLoading();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_key, color.toARGB32());
      state = AsyncData(color);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

// ═══════════════════════════════════════════
//  DENSITY PROVIDER
// ═══════════════════════════════════════════

final densityProvider = AsyncNotifierProvider<DensityNotifier, AppDensity>(
  DensityNotifier.new,
);

class DensityNotifier extends AsyncNotifier<AppDensity> {
  static const _key = 'q6h.density';

  @override
  Future<AppDensity> build() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString(_key);
    return val == 'compact' ? AppDensity.compact : AppDensity.comfortable;
  }

  Future<void> setDensity(AppDensity d) async {
    state = const AsyncLoading();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _key, d == AppDensity.compact ? 'compact' : 'comfortable');
      state = AsyncData(d);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

// ═══════════════════════════════════════════
//  CARD STYLE PROVIDER
// ═══════════════════════════════════════════

final cardStyleProvider =
    AsyncNotifierProvider<CardStyleNotifier, AppCardStyle>(
  CardStyleNotifier.new,
);

class CardStyleNotifier extends AsyncNotifier<AppCardStyle> {
  static const _key = 'q6h.cardStyle';

  @override
  Future<AppCardStyle> build() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString(_key);
    return switch (val) {
      'flat' => AppCardStyle.flat,
      'shadow' => AppCardStyle.shadow,
      _ => AppCardStyle.bordered,
    };
  }

  Future<void> setStyle(AppCardStyle s) async {
    state = const AsyncLoading();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, s.name);
      state = AsyncData(s);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

// ═══════════════════════════════════════════
//  CREATOR NAME PROVIDER
// ═══════════════════════════════════════════

final creatorNameProvider = AsyncNotifierProvider<CreatorNameNotifier, String>(
  CreatorNameNotifier.new,
);

class CreatorNameNotifier extends AsyncNotifier<String> {
  static const _key = 'creator_name';
  static const _default = 'محمد';

  @override
  Future<String> build() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    return (saved != null && saved.isNotEmpty) ? saved : _default;
  }

  Future<void> setName(String name) async {
    if (name.trim().isEmpty) return;
    state = const AsyncLoading();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, name.trim());
      state = AsyncData(name.trim());
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

// ═══════════════════════════════════════════
//  VALUE PROVIDERS — للـ UI (بدون AsyncValue)
// ═══════════════════════════════════════════

final accentColorValueProvider = Provider<Color>((ref) {
  return ref.watch(accentColorProvider).valueOrNull ?? const Color(0xFF2563EB);
});

final densityValueProvider = Provider<AppDensity>((ref) {
  return ref.watch(densityProvider).valueOrNull ?? AppDensity.comfortable;
});

final cardStyleValueProvider = Provider<AppCardStyle>((ref) {
  return ref.watch(cardStyleProvider).valueOrNull ?? AppCardStyle.bordered;
});

final creatorNameValueProvider = Provider<String>((ref) {
  return ref.watch(creatorNameProvider).valueOrNull ?? 'محمد';
});
