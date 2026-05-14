import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SoundEffect { none, waterDrop, flush, fart }

class AppSettings {
  final ThemeMode themeMode;
  final bool useOledDark;
  final SoundEffect soundEffect;
  final double soundVolume;
  final bool morningReminderEnabled;
  final String morningReminderTime;
  final bool sedentaryReminderEnabled;
  final int sedentaryReminderMinutes;
  final bool irregularReminderEnabled;
  final bool smallReminderEnabled;
  final int smallReminderHours;
  final bool bigReminderEnabled;
  final int bigReminderDays;
  final bool appLockEnabled;
  final bool privacyModeEnabled;
  final bool anonymousRanking;
  final bool autoDetectWorkHours;
  final bool quickRecordDefault;
  final bool showBristolReminder;
  final String emojiStyle;

  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.useOledDark = false,
    this.soundEffect = SoundEffect.waterDrop,
    this.soundVolume = 0.7,
    this.morningReminderEnabled = true,
    this.morningReminderTime = '07:30',
    this.sedentaryReminderEnabled = true,
    this.sedentaryReminderMinutes = 120,
    this.irregularReminderEnabled = true,
    this.smallReminderEnabled = true,
    this.smallReminderHours = 4,
    this.bigReminderEnabled = true,
    this.bigReminderDays = 2,
    this.appLockEnabled = false,
    this.privacyModeEnabled = false,
    this.anonymousRanking = false,
    this.autoDetectWorkHours = true,
    this.quickRecordDefault = false,
    this.showBristolReminder = true,
    this.emojiStyle = 'cute',
  });

  factory AppSettings.defaults() => const AppSettings();

  AppSettings copyWith({
    ThemeMode? themeMode,
    bool? useOledDark,
    SoundEffect? soundEffect,
    double? soundVolume,
    bool? morningReminderEnabled,
    String? morningReminderTime,
    bool? sedentaryReminderEnabled,
    int? sedentaryReminderMinutes,
    bool? irregularReminderEnabled,
    bool? smallReminderEnabled,
    int? smallReminderHours,
    bool? bigReminderEnabled,
    int? bigReminderDays,
    bool? appLockEnabled,
    bool? privacyModeEnabled,
    bool? anonymousRanking,
    bool? autoDetectWorkHours,
    bool? quickRecordDefault,
    bool? showBristolReminder,
    String? emojiStyle,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      useOledDark: useOledDark ?? this.useOledDark,
      soundEffect: soundEffect ?? this.soundEffect,
      soundVolume: soundVolume ?? this.soundVolume,
      morningReminderEnabled:
          morningReminderEnabled ?? this.morningReminderEnabled,
      morningReminderTime: morningReminderTime ?? this.morningReminderTime,
      sedentaryReminderEnabled:
          sedentaryReminderEnabled ?? this.sedentaryReminderEnabled,
      sedentaryReminderMinutes:
          sedentaryReminderMinutes ?? this.sedentaryReminderMinutes,
      irregularReminderEnabled:
          irregularReminderEnabled ?? this.irregularReminderEnabled,
      smallReminderEnabled: smallReminderEnabled ?? this.smallReminderEnabled,
      smallReminderHours: smallReminderHours ?? this.smallReminderHours,
      bigReminderEnabled: bigReminderEnabled ?? this.bigReminderEnabled,
      bigReminderDays: bigReminderDays ?? this.bigReminderDays,
      appLockEnabled: appLockEnabled ?? this.appLockEnabled,
      privacyModeEnabled: privacyModeEnabled ?? this.privacyModeEnabled,
      anonymousRanking: anonymousRanking ?? this.anonymousRanking,
      autoDetectWorkHours: autoDetectWorkHours ?? this.autoDetectWorkHours,
      quickRecordDefault: quickRecordDefault ?? this.quickRecordDefault,
      showBristolReminder: showBristolReminder ?? this.showBristolReminder,
      emojiStyle: emojiStyle ?? this.emojiStyle,
    );
  }

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      themeMode: _parseThemeMode(prefs.getString('theme_mode') ?? 'system'),
      useOledDark: prefs.getBool('use_oled_dark') ?? false,
      soundEffect:
          _parseSoundEffect(prefs.getString('sound_effect') ?? 'water_drop'),
      soundVolume: prefs.getDouble('sound_volume') ?? 0.7,
      morningReminderEnabled: prefs.getBool('morning_reminder_enabled') ?? true,
      morningReminderTime: prefs.getString('morning_reminder_time') ?? '07:30',
      sedentaryReminderEnabled:
          prefs.getBool('sedentary_reminder_enabled') ?? true,
      sedentaryReminderMinutes:
          prefs.getInt('sedentary_reminder_minutes') ?? 120,
      irregularReminderEnabled:
          prefs.getBool('irregular_reminder_enabled') ?? true,
      smallReminderEnabled: prefs.getBool('small_reminder_enabled') ?? true,
      smallReminderHours: prefs.getInt('small_reminder_hours') ?? 4,
      bigReminderEnabled: prefs.getBool('big_reminder_enabled') ?? true,
      bigReminderDays: prefs.getInt('big_reminder_days') ?? 2,
      appLockEnabled: prefs.getBool('app_lock_enabled') ?? false,
      privacyModeEnabled: prefs.getBool('privacy_mode_enabled') ?? false,
      anonymousRanking: prefs.getBool('anonymous_ranking') ?? false,
      autoDetectWorkHours: prefs.getBool('auto_detect_work_hours') ?? true,
      quickRecordDefault: prefs.getBool('quick_record_default') ?? false,
      showBristolReminder: prefs.getBool('show_bristol_reminder') ?? true,
      emojiStyle: prefs.getString('emoji_style') ?? 'cute',
    );
  }

  static ThemeMode _parseThemeMode(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static SoundEffect _parseSoundEffect(String value) {
    switch (value) {
      case 'none':
        return SoundEffect.none;
      case 'flush':
        return SoundEffect.flush;
      case 'fart':
        return SoundEffect.fart;
      default:
        return SoundEffect.waterDrop;
    }
  }

  static Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', _themeModeToString(settings.themeMode));
    await prefs.setBool('use_oled_dark', settings.useOledDark);
    await prefs.setString(
        'sound_effect', _soundEffectToString(settings.soundEffect));
    await prefs.setDouble('sound_volume', settings.soundVolume);
    await prefs.setBool(
        'morning_reminder_enabled', settings.morningReminderEnabled);
    await prefs.setString(
        'morning_reminder_time', settings.morningReminderTime);
    await prefs.setBool(
        'sedentary_reminder_enabled', settings.sedentaryReminderEnabled);
    await prefs.setInt(
        'sedentary_reminder_minutes', settings.sedentaryReminderMinutes);
    await prefs.setBool(
        'irregular_reminder_enabled', settings.irregularReminderEnabled);
    await prefs.setBool(
        'small_reminder_enabled', settings.smallReminderEnabled);
    await prefs.setInt('small_reminder_hours', settings.smallReminderHours);
    await prefs.setBool('big_reminder_enabled', settings.bigReminderEnabled);
    await prefs.setInt('big_reminder_days', settings.bigReminderDays);
    await prefs.setBool('app_lock_enabled', settings.appLockEnabled);
    await prefs.setBool('privacy_mode_enabled', settings.privacyModeEnabled);
    await prefs.setBool('anonymous_ranking', settings.anonymousRanking);
    await prefs.setBool('auto_detect_work_hours', settings.autoDetectWorkHours);
    await prefs.setBool('quick_record_default', settings.quickRecordDefault);
    await prefs.setBool('show_bristol_reminder', settings.showBristolReminder);
    await prefs.setString('emoji_style', settings.emojiStyle);
  }

  static String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      default:
        return 'system';
    }
  }

  static String _soundEffectToString(SoundEffect effect) {
    switch (effect) {
      case SoundEffect.none:
        return 'none';
      case SoundEffect.flush:
        return 'flush';
      case SoundEffect.fart:
        return 'fart';
      default:
        return 'water_drop';
    }
  }
}
