import 'dart:io';
import 'package:flutter/foundation.dart';

class NotificationService {
  static bool _initialized = false;

  static bool get isInitialized => _initialized;

  static Future<void> initialize() async {
    if (_initialized) return;

    if (Platform.isAndroid || Platform.isIOS) {
      _initialized = true;
    }
  }

  static Future<void> requestPermission() async {
    if (Platform.isAndroid) {
    } else if (Platform.isIOS) {}
  }

  static Future<void> show({
    required String title,
    required String body,
    String? payload,
    int? id,
  }) async {
    if (!_initialized) await initialize();

    final notificationId = id ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;

    debugPrint(
        '[Notification#$notificationId] $title: $body (payload: $payload)');
  }

  static Future<void> scheduleDaily({
    required int hour,
    required int minute,
    required String title,
    required String body,
    int? id,
  }) async {
    if (!_initialized) await initialize();

    debugPrint(
        '[ScheduledNotification#$id] Daily $hour:$minute - $title: $body');
  }

  static Future<void> scheduleDelayed({
    required Duration delay,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized) await initialize();

    final scheduledTime = DateTime.now().add(delay);
    debugPrint(
        '[DelayedNotification] At ${scheduledTime.toIso8601String()} - $title: $body');
  }

  static Future<void> cancelAll() async {
    debugPrint('[NotificationService] All scheduled notifications cancelled');
  }

  static Future<void> cancel(int id) async {
    debugPrint('[NotificationService] Notification#$id cancelled');
  }
}

class NotificationType {
  static const String morningReminder = 'reminder:morning';
  static const String sedentaryReminder = 'reminder:sedentary';
  static const String constipationAlert = 'anomaly:constipation';
  static const String diarrheaAlert = 'anomaly:diarrhea';
  static const String bloodAlert = 'anomaly:blood';
  static const String smallReminder = 'reminder:small';
  static const String bigReminder = 'reminder:big';
  static const String rankUpdate = 'rank:update';
  static const String achievementUnlock = 'achievement:unlock';
  static const String seasonChange = 'season:change';

  static String getLocalizedTitle(String type) {
    switch (type) {
      case morningReminder:
        return '🚽 早安！该出库了';
      case sedentaryReminder:
        return '🚶 该动动了';
      case constipationAlert:
        return '⚠️ 肠道预警';
      case diarrheaAlert:
        return '⚠️ 腹泻预警';
      case bloodAlert:
        return '🚨 重要健康提醒';
      case smallReminder:
        return '💧 小号提醒';
      case bigReminder:
        return '💩 大号提醒';
      case rankUpdate:
        return '🎉 排名变化';
      case achievementUnlock:
        return '🏆 成就解锁';
      case seasonChange:
        return '🎉 新赛季开始';
      default:
        return '拉了么';
    }
  }

  static String getLocalizedBody(String type, {Map<String, dynamic>? data}) {
    switch (type) {
      case morningReminder:
        return '新的一天，肠道也该开始工作了～';
      case sedentaryReminder:
        return '坐太久了，起来活动一下吧！';
      case constipationAlert:
        final days = data?['days'] ?? 5;
        return '已经 $days 天没有大号了，建议多吃膳食纤维，必要时就医。';
      case diarrheaAlert:
        return '检测到持续腹泻症状，请注意补水，如超过3天请立即就医。';
      case bloodAlert:
        return '检测到异常便便颜色记录，建议尽快就医检查。';
      case smallReminder:
        final hours = data?['hours'] ?? 4;
        return '已经 $hours 小时没有小号了，记得多喝水哦～';
      case bigReminder:
        final days = data?['days'] ?? 2;
        return '已经 $days 天没有大号了，建议多吃膳食纤维～';
      case rankUpdate:
        final change = data?['rank_change'] ?? 0;
        return change > 0 ? '排名上升了 $change 位！' : '排名下降了 ${change.abs()} 位';
      case achievementUnlock:
        final name = data?['name'] ?? '新成就';
        return '恭喜解锁成就：$name！';
      case seasonChange:
        final season = data?['season'] ?? '新赛季';
        return '$season 已开始，积分已重置，重新出发吧！';
      default:
        return '您有一条新消息';
    }
  }
}
