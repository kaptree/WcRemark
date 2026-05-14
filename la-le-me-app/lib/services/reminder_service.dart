
import '../models/toilet_record.dart';
import 'database_service.dart';
import 'settings_service.dart';

class ReminderCheckResult {
  final bool showSmallReminder;
  final bool showBigReminder;
  final int hoursSinceSmall;
  final int daysSinceBig;
  final DateTime? lastSmallTime;
  final DateTime? lastBigTime;

  const ReminderCheckResult({
    required this.showSmallReminder,
    required this.showBigReminder,
    required this.hoursSinceSmall,
    required this.daysSinceBig,
    this.lastSmallTime,
    this.lastBigTime,
  });

  bool get hasAnyReminder => showSmallReminder || showBigReminder;
}

class ReminderService {
  static Future<DateTime?> _getLastRecordTime(RecordType type) async {
    final records = await DatabaseService.getRecords(limit: 1, type: type);
    if (records.isEmpty) return null;
    return DateTime.fromMillisecondsSinceEpoch(records.first.timestamp);
  }

  static Future<ReminderCheckResult> checkReminders() async {
    final settings = await AppSettings.load();

    final lastSmall = await _getLastRecordTime(RecordType.small);
    final lastBig = await _getLastRecordTime(RecordType.big);

    final now = DateTime.now();

    int hoursSinceSmall = 0;
    bool showSmallReminder = false;

    if (settings.smallReminderEnabled) {
      if (lastSmall != null) {
        hoursSinceSmall = now.difference(lastSmall).inHours;
        showSmallReminder = hoursSinceSmall >= settings.smallReminderHours;
      }
    }

    int daysSinceBig = 0;
    bool showBigReminder = false;

    if (settings.bigReminderEnabled) {
      if (lastBig != null) {
        daysSinceBig = now.difference(lastBig).inDays;
        showBigReminder = daysSinceBig >= settings.bigReminderDays;
      }
    }

    return ReminderCheckResult(
      showSmallReminder: showSmallReminder,
      showBigReminder: showBigReminder,
      hoursSinceSmall: hoursSinceSmall,
      daysSinceBig: daysSinceBig,
      lastSmallTime: lastSmall,
      lastBigTime: lastBig,
    );
  }
}
