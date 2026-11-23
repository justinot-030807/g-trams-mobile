import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppTextScaleOption {
  normal(1.0, 'Normal'),
  large(1.14, 'Large'),
  extraLarge(1.26, 'Extra Large');

  const AppTextScaleOption(this.factor, this.label);
  final double factor;
  final String label;

  static AppTextScaleOption fromString(String? raw) {
    return AppTextScaleOption.values.firstWhere(
      (o) => o.name == raw,
      orElse: () => AppTextScaleOption.normal,
    );
  }
}

class AppPreferencesState {
  const AppPreferencesState({
    this.themeMode = ThemeMode.system,
    this.language = 'en',
    this.textScale = AppTextScaleOption.normal,
    this.hasSeenOnboarding = false,
    this.biometricEnabled = false,
  });

  final ThemeMode themeMode;
  final String language;
  final AppTextScaleOption textScale;
  final bool hasSeenOnboarding;
  final bool biometricEnabled;

  AppPreferencesState copyWith({
    ThemeMode? themeMode,
    String? language,
    AppTextScaleOption? textScale,
    bool? hasSeenOnboarding,
    bool? biometricEnabled,
  }) {
    return AppPreferencesState(
      themeMode: themeMode ?? this.themeMode,
      language: language ?? this.language,
      textScale: textScale ?? this.textScale,
      hasSeenOnboarding: hasSeenOnboarding ?? this.hasSeenOnboarding,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
    );
  }
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden');
});

class AppPreferencesNotifier extends StateNotifier<AppPreferencesState> {
  AppPreferencesNotifier(this._prefs) : super(_loadInitial(_prefs));

  final SharedPreferences _prefs;

  static const _kThemeMode = 'gtrams_theme_mode';
  static const _kLanguage = 'gtrams_lang';
  static const _kTextScale = 'gtrams_text_scale';
  static const _kOnboarding = 'gtrams_seen_onboarding';
  static const _kBiometric = 'gtrams_biometric_enabled';

  static AppPreferencesState _loadInitial(SharedPreferences prefs) {
    final rawTheme = prefs.getString(_kThemeMode);
    final themeMode = switch (rawTheme) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    return AppPreferencesState(
      themeMode: themeMode,
      language: prefs.getString(_kLanguage) ?? 'en',
      textScale: AppTextScaleOption.fromString(prefs.getString(_kTextScale)),
      hasSeenOnboarding: prefs.getBool(_kOnboarding) ?? false,
      biometricEnabled: prefs.getBool(_kBiometric) ?? false,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _prefs.setString(_kThemeMode, mode.name);
  }

  Future<void> setLanguage(String lang) async {
    final normalized = lang == 'fil' ? 'fil' : 'en';
    state = state.copyWith(language: normalized);
    await _prefs.setString(_kLanguage, normalized);
  }

  Future<void> toggleLanguage() async {
    await setLanguage(state.language == 'fil' ? 'en' : 'fil');
  }

  Future<void> setTextScale(AppTextScaleOption option) async {
    state = state.copyWith(textScale: option);
    await _prefs.setString(_kTextScale, option.name);
  }

  Future<void> markOnboardingComplete() async {
    state = state.copyWith(hasSeenOnboarding: true);
    await _prefs.setBool(_kOnboarding, true);
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    state = state.copyWith(biometricEnabled: enabled);
    await _prefs.setBool(_kBiometric, enabled);
  }
}

final appPreferencesProvider =
    StateNotifierProvider<AppPreferencesNotifier, AppPreferencesState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AppPreferencesNotifier(prefs);
});
