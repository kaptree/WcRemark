import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class AppUtils {
  static const _uuid = Uuid();

  static String generateId() {
    return _uuid.v4();
  }

  static String generateSyncUuid() {
    return _uuid.v4();
  }

  static String hashLocation(double lat, double lng) {
    String raw = '$lat,$lng';
    return sha256.convert(utf8.encode(raw)).toString().substring(0, 12);
  }

  static String formatDuration(int seconds) {
    if (seconds < 60) return '$seconds秒';
    int minutes = seconds ~/ 60;
    int remainSeconds = seconds % 60;
    if (minutes < 60) {
      return remainSeconds > 0 ? '$minutes分$remainSeconds秒' : '$minutes分钟';
    }
    int hours = minutes ~/ 60;
    int remainMinutes = minutes % 60;
    return '$hours小时$remainMinutes分';
  }

  static String getGreeting() {
    int hour = DateTime.now().hour;
    if (hour >= 5 && hour < 9) return '早安';
    if (hour >= 9 && hour < 12) return '上午好';
    if (hour >= 12 && hour < 14) return '午安';
    if (hour >= 14 && hour < 18) return '下午好';
    if (hour >= 18 && hour < 21) return '晚上好';
    return '夜深了';
  }

  static String formatScore(double score) {
    if (score >= 10000) return '${(score / 10000).toStringAsFixed(1)}万';
    if (score >= 1000) return '${(score / 1000).toStringAsFixed(1)}k';
    return score.toStringAsFixed(1);
  }

  static String getBristolLabel(int? type) {
    switch (type) {
      case 1:
        return '1型-硬球状';
      case 2:
        return '2型-腊肠块';
      case 3:
        return '3型-裂纹状';
      case 4:
        return '4型-光滑软便';
      case 5:
        return '5型-软团块';
      case 6:
        return '6型-糊状';
      case 7:
        return '7型-水样';
      default:
        return '未选择';
    }
  }

  static String getBristolEmoji(int? type) {
    switch (type) {
      case 1:
        return '🔴';
      case 2:
        return '🟠';
      case 3:
        return '🟡';
      case 4:
        return '🟢';
      case 5:
        return '🔵';
      case 6:
        return '🟣';
      case 7:
        return '⚫';
      default:
        return '⚪';
    }
  }

  static bool isWorkHours({int? startHour, int? endHour, int? weekday}) {
    DateTime now = DateTime.now();
    int wd = weekday ?? now.weekday;
    int start = startHour ?? 9;
    int end = endHour ?? 18;
    return wd <= 5 && now.hour >= start && now.hour < end;
  }

  static bool isWorkHoursForTime(DateTime dt, int startHour, int endHour) {
    return dt.weekday <= 5 && dt.hour >= startHour && dt.hour < endHour;
  }

  static String getRelativeDay(DateTime dt) {
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime target = DateTime(dt.year, dt.month, dt.day);
    int diff = today.difference(target).inDays;
    if (diff == 0) return '今天';
    if (diff == 1) return '昨天';
    if (diff == 2) return '前天';
    if (diff < 7) return '$diff天前';
    if (diff < 30) return '${diff ~/ 7}周前';
    return '${dt.month}月${dt.day}日';
  }
}
