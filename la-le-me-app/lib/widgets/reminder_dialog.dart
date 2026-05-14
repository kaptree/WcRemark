import 'package:flutter/material.dart';
import '../services/reminder_service.dart';

class ReminderDialog {
  static Future<void> show(
      BuildContext context, ReminderCheckResult result) async {
    final items = <Widget>[];

    if (result.showSmallReminder) {
      items.add(_buildReminderItem(
        icon: '💧',
        title: '小号提醒',
        message: '已经 ${result.hoursSinceSmall} 小时没有小号了，记得多喝水哦～',
        color: const Color(0xFF42A5F5),
      ));
    }

    if (result.showBigReminder) {
      items.add(const SizedBox(height: 16));
      items.add(_buildReminderItem(
        icon: '💩',
        title: '大号提醒',
        message: '已经 ${result.daysSinceBig} 天没有大号了，建议多吃膳食纤维～',
        color: const Color(0xFF795548),
      ));
    }

    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF5E6D3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text('⏰', style: TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              '健康提醒',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('知道了',
                style: TextStyle(fontSize: 15, color: Color(0xFF999999))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, '/record/detail');
            },
            child: const Text('去记录',
                style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFF795548),
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  static Widget _buildReminderItem({
    required String icon,
    required String title,
    required String message,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                      fontSize: 14, color: Color(0xFF666666), height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
