import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/toilet_record.dart';
import '../services/database_service.dart';
import '../services/score_calculator.dart';
import '../services/anti_cheat_service.dart';
import '../services/achievement_service.dart';
import '../services/season_service.dart';
import '../services/anomaly_detector.dart';
import '../services/reminder_service.dart';
import '../services/sound_service.dart';
import '../services/app_content_loader.dart';
import '../services/regularity_calculator.dart';
import '../screens/settings_page.dart';
import '../models/achievement.dart';
import '../providers/record_provider.dart';
import '../utils/app_utils.dart';
import '../widgets/reminder_dialog.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(refreshTriggerProvider.notifier).state++;
        _initServices();
      }
    });
  }

  Future<void> _initServices() async {
    await SeasonService.checkAndHandleSeasonChange();
    if (mounted) {
      await AnomalyDetector.checkAndAlert();
    }
    _checkAndShowReminders();
  }

  Future<void> _checkAndShowReminders() async {
    try {
      final result = await ReminderService.checkReminders();
      if (result.hasAnyReminder && mounted) {
        ReminderDialog.show(context, result);
      }
    } catch (_) {}
  }

  String _getGreeting() {
    int hour = DateTime.now().hour;
    if (hour >= 5 && hour < 9) return '早安！所长 🌅';
    if (hour >= 9 && hour < 12) return '上午好！所长 ☕️';
    if (hour >= 12 && hour < 14) return '午安！所长 🍱';
    if (hour >= 14 && hour < 18) return '下午好！所长 🌤️';
    if (hour >= 18 && hour < 21) return '晚上好！所长 🌆';
    if (hour >= 21) return '夜深了！所长 🌙';
    return '凌晨好！所长 🌃';
  }

  String _getSubTitle(int bigCount, int smallCount, int? lastBigHours) {
    if (bigCount == 0 && smallCount == 0) {
      return '今天还没出库哦，记得多喝水～';
    } else if (bigCount == 0) {
      return '小号已记录，大号别憋着哦';
    } else if (bigCount == 1 && lastBigHours != null && lastBigHours < 12) {
      return '作息很规律，继续保持～';
    } else if (bigCount >= 3) {
      return '今天出库频繁，注意饮食卫生';
    } else if (lastBigHours != null && lastBigHours > 48) {
      return '已经2天没出库了，建议多吃膳食纤维';
    } else {
      return '保持好心情，肠道更健康～';
    }
  }

  String _getDailyTip(int bigCount, int? lastBigHours, int regularityScore) {
    if (bigCount == 0) return AppContentLoader.getDailyTipText('no_record');
    if (regularityScore >= 80)
      return AppContentLoader.getDailyTipText('regularity_high');
    if (regularityScore >= 60)
      return AppContentLoader.getDailyTipText('regularity_medium');
    if (lastBigHours != null && lastBigHours > 48)
      return AppContentLoader.getDailyTipText('constipation_risk');
    return AppContentLoader.getDailyTipText('default');
  }

  void _showRecordActionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              '选择记录类型',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading:
                  const Icon(Icons.water_drop, color: Colors.blue, size: 28),
              title: const Text('小号', style: TextStyle(fontSize: 16)),
              subtitle: const Text('快速记录'),
              onTap: () {
                Navigator.pop(ctx);
                _quickRecord(RecordType.small);
              },
            ),
            ListTile(
              leading: const Icon(Icons.star, color: Colors.brown, size: 28),
              title: const Text('大号', style: TextStyle(fontSize: 16)),
              subtitle: const Text('详细记录'),
              onTap: () {
                Navigator.pop(ctx);
                _navigateToDetail();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _navigateToDetail() async {
    final result = await Navigator.pushNamed(context, '/record/detail');
    if (result != null && result is Map<String, dynamic>) {
      await _saveRecordFromDetail(result);
    }
    _refreshData();
    _checkAndShowReminders();
  }

  Future<void> _saveRecordFromDetail(Map<String, dynamic> data) async {
    final now = DateTime.now();
    final record = ToiletRecord(
      id: const Uuid().v4(),
      type: data['type'] == 0 ? RecordType.small : RecordType.big,
      timestamp: data['timestamp'] ?? now.millisecondsSinceEpoch,
      duration: data['duration'] as int?,
      bristolType: data['bristol_type'] as int?,
      smoothness: data['smoothness'] as int?,
      isWorkHours: data['is_work_hours'] as bool? ?? false,
      isPaidPoop: data['is_paid_poop'] as bool? ?? false,
      mood: data['mood'] as String?,
      note: data['note'] as String?,
      createdAt: now.millisecondsSinceEpoch,
      updatedAt: now.millisecondsSinceEpoch,
    );

    final history = await DatabaseService.getRecentRecords(days: 30);
    final cheatResult = AntiCheatService.clientPreCheck(record, history);
    if (cheatResult.shouldReject) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(cheatResult.reason ?? '记录异常，已拒绝'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    await DatabaseService.insertRecord(record);

    if (cheatResult.flag == CheatFlag.suspicious) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(cheatResult.reason ?? '记录标记为可疑'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } else {
      final score = ScoreCalculator.calculate(record, history);
      await SeasonService.addScore(score.round());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('大号记录成功 💪 积分+${score.round()}'),
            duration: const Duration(seconds: 2),
          ),
        );
        final settings = ref.read(settingsNotifierProvider);
        SoundService.playWaterDrop(settings);
      }
    }

    try {
      final newHistory = [...history, record];
      final newUnlocks =
          await AchievementService.checkAndUnlock(record, newHistory);
      if (newUnlocks.isNotEmpty && mounted) {
        for (final id in newUnlocks) {
          final def = Achievement.getDefById(id);
          if (def != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('🏆 成就解锁：${def.name}'),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      }
    } catch (_) {}

    _refreshData();
  }

  Future<void> _quickRecord(RecordType type) async {
    final profile = await DatabaseService.getProfile();
    final startHour = profile.workStartHour ?? profile.defaultWorkStartHour;
    final endHour = profile.workEndHour ?? profile.defaultWorkEndHour;
    final now = DateTime.now();
    final isWork = AppUtils.isWorkHoursForTime(now, startHour, endHour);

    final record = ToiletRecord(
      id: const Uuid().v4(),
      type: type,
      timestamp: now.millisecondsSinceEpoch,
      duration: type == RecordType.small ? 30 : 180,
      isWorkHours: isWork,
      isPaidPoop: isWork,
      createdAt: now.millisecondsSinceEpoch,
      updatedAt: now.millisecondsSinceEpoch,
    );

    final history = await DatabaseService.getRecentRecords(days: 30);
    final cheatResult = AntiCheatService.clientPreCheck(record, history);
    if (cheatResult.shouldReject) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(cheatResult.reason ?? '记录异常，已拒绝'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    await DatabaseService.insertRecord(record);

    if (cheatResult.flag != CheatFlag.suspicious) {
      final score = ScoreCalculator.calculate(record, history);
      await SeasonService.addScore(score.round());
    }

    try {
      final newHistory = [...history, record];
      final newUnlocks =
          await AchievementService.checkAndUnlock(record, newHistory);
      if (newUnlocks.isNotEmpty && mounted) {
        for (final id in newUnlocks) {
          final def = Achievement.getDefById(id);
          if (def != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('🏆 成就解锁：${def.name}'),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      }
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(type == RecordType.big ? '大号记录成功 💪' : '小号记录成功 💧'),
          duration: const Duration(seconds: 2),
        ),
      );
      final settings = ref.read(settingsNotifierProvider);
      SoundService.playWaterDrop(settings);
      _refreshData();
      _checkAndShowReminders();
    }
  }

  void _refreshData() {
    ref.read(refreshTriggerProvider.notifier).state++;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd EEEE', 'zh_CN').format(now);
    final greeting = _getGreeting();
    final recordsAsync = ref.watch(todayRecordsProvider);
    final statsAsync = ref.watch(weeklyStatsProvider);

    return Scaffold(
      body: recordsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('加载失败: $e')),
        data: (records) {
          final bigRecords =
              records.where((r) => r.type == RecordType.big).toList();
          final bigCount = bigRecords.length;
          final smallCount =
              records.where((r) => r.type == RecordType.small).length;

          int? lastBigHours;
          if (bigRecords.isNotEmpty) {
            final lastBig = bigRecords.first;
            final diff =
                DateTime.now().millisecondsSinceEpoch - lastBig.timestamp;
            lastBigHours = (diff / (1000 * 60 * 60)).round();
          }

          final subTitle = _getSubTitle(bigCount, smallCount, lastBigHours);
          final totalCount = bigCount + smallCount;

          final seasonScoreAsync = ref.watch(seasonScoreProvider);
          final totalRecordCountAsync = ref.watch(totalRecordCountProvider);
          final weekRecordsAsync = ref.watch(weekRecordsProvider);

          final weekRecords = weekRecordsAsync.valueOrNull ?? [];
          final healthStatus = HomeHealthStatusCalculator.calculate(
            todayRecords: records,
            weekRecords: weekRecords,
          );

          return RefreshIndicator(
            onRefresh: () async {
              ref.read(refreshTriggerProvider.notifier).state++;
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      Text(dateStr,
                          style: const TextStyle(
                              fontSize: 14, color: Color(0xFF999999))),
                      const SizedBox(height: 4),
                      Text(greeting,
                          style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1A1A))),
                      const SizedBox(height: 20),
                      _buildCoreCard(
                          totalCount, bigCount, smallCount, subTitle),
                      const SizedBox(height: 16),
                      _buildWeekOverview(statsAsync, totalRecordCountAsync,
                          seasonScoreAsync, healthStatus),
                      const SizedBox(height: 16),
                      _buildDailyTip(statsAsync, bigCount, lastBigHours),
                      const SizedBox(height: 16),
                      _buildFiveDayChart(),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: Container(
        width: 200,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          color: const Color(0xFFE3F2FD),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(28),
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: _showRecordActionSheet,
            child: const Center(
              child: Text(
                '🚽 又去啦？',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF1565C0),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildCoreCard(
      int totalCount, int bigCount, int smallCount, String subTitle) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFD4A574), Color(0xFFF5E6D3)],
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white.withValues(alpha: 0.3),
            ),
            child: const Center(
              child: Text('🧻', style: TextStyle(fontSize: 32)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '今日已出库 $totalCount 次 💩',
                  style: const TextStyle(
                    fontSize: 22,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subTitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekOverview(
      AsyncValue<WeeklyStatsData> statsAsync,
      AsyncValue<int> totalRecordCountAsync,
      AsyncValue<SeasonInfo> seasonScoreAsync,
      HomeHealthStatus healthStatus) {
    final seasonScore = seasonScoreAsync.valueOrNull?.score ?? 0;
    final seasonRank = seasonScoreAsync.valueOrNull?.rank;
    final allTimeTotal = totalRecordCountAsync.valueOrNull ?? 0;

    final severityColors = [
      const Color(0xFF4CAF50),
      const Color(0xFFFF9800),
      const Color(0xFFE65100),
      const Color(0xFFF44336),
    ];
    final statusColor = severityColors[healthStatus.severity.clamp(0, 3)];

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 110,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: const Color(0xFFF7F7F7),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Row(children: [
                  Text('⭐', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 4),
                  Text('次数',
                      style: TextStyle(fontSize: 12, color: Color(0xFF999999))),
                ]),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('$allTimeTotal',
                        style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A))),
                    const SizedBox(width: 2),
                    const Text('次',
                        style:
                            TextStyle(fontSize: 14, color: Color(0xFF999999))),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 110,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: const Color(0xFFF7F7F7),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Row(children: [
                  Text('🏆', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 4),
                  Text('积分',
                      style: TextStyle(fontSize: 12, color: Color(0xFF999999))),
                ]),
                const SizedBox(height: 4),
                Text(
                  '$seasonScore',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                if (seasonRank != null)
                  Text(
                    '${seasonRank.icon} ${seasonRank.name}',
                    style:
                        const TextStyle(fontSize: 11, color: Color(0xFF999999)),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 110,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: const Color(0xFFF7F7F7),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(children: [
                  Text(healthStatus.icon, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 4),
                  const Text('状态',
                      style: TextStyle(fontSize: 12, color: Color(0xFF999999))),
                ]),
                const SizedBox(height: 4),
                Text(
                  healthStatus.label,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
                Text(
                  healthStatus.detail,
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF999999)),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDailyTip(
      AsyncValue<WeeklyStatsData> statsAsync, int bigCount, int? lastBigHours) {
    final regularityScore = statsAsync.valueOrNull?.regularityScore ?? 50;
    final tip = _getDailyTip(bigCount, lastBigHours, regularityScore);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFFE8F5E9),
      ),
      child: Row(
        children: [
          const Text('💡', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tip,
              style: const TextStyle(fontSize: 14, color: Color(0xFF1B5E20)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiveDayChart() {
    final statsAsync = ref.watch(fiveDayStatsProvider);

    return statsAsync.when(
      loading: () => const SizedBox(height: 0),
      error: (e, st) => const SizedBox(height: 0),
      data: (stats) {
        final bigCounts = stats.bigCounts;
        final smallCounts = stats.smallCounts;
        final totalCounts = stats.totalCounts;
        final maxY = (totalCounts.reduce((a, b) => a > b ? a : b) + 1)
            .toDouble()
            .clamp(3.0, double.infinity);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: const Color(0xFFF7F7F7),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Text('📈', style: TextStyle(fontSize: 14)),
                  SizedBox(width: 6),
                  Text(
                    '近5天出库趋势',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _legendDot(const Color(0xFFD4A574)),
                  const SizedBox(width: 4),
                  const Text('大号',
                      style: TextStyle(fontSize: 10, color: Color(0xFF999999))),
                  const SizedBox(width: 12),
                  _legendDot(const Color(0xFF66BB6A)),
                  const SizedBox(width: 4),
                  const Text('小号',
                      style: TextStyle(fontSize: 10, color: Color(0xFF999999))),
                  const SizedBox(width: 12),
                  _legendDot(const Color(0xFF90CAF9)),
                  const SizedBox(width: 4),
                  const Text('总计',
                      style: TextStyle(fontSize: 10, color: Color(0xFF999999))),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 180,
                child: LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: 4,
                    minY: 0,
                    maxY: maxY,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 1,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: Colors.grey.withValues(alpha: 0.15),
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx < 0 || idx >= stats.dates.length)
                              return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                stats.dates[idx],
                                style: const TextStyle(
                                    fontSize: 10, color: Color(0xFF999999)),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 24,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            if (value == value.roundToDouble() && value >= 0) {
                              return Text(
                                value.toInt().toString(),
                                style: const TextStyle(
                                    fontSize: 10, color: Color(0xFF999999)),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            final label = spot.barIndex == 0
                                ? '大号'
                                : spot.barIndex == 1
                                    ? '小号'
                                    : '总计';
                            return LineTooltipItem(
                              '$label: ${spot.y.toInt()}次',
                              TextStyle(
                                color: spot.barIndex == 0
                                    ? const Color(0xFFD4A574)
                                    : spot.barIndex == 1
                                        ? const Color(0xFF66BB6A)
                                        : const Color(0xFF90CAF9),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            );
                          }).toList();
                        },
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: List.generate(
                            5,
                            (i) =>
                                FlSpot(i.toDouble(), bigCounts[i].toDouble())),
                        isCurved: true,
                        curveSmoothness: 0.3,
                        color: const Color(0xFFD4A574),
                        barWidth: 2.5,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, xPercentage, bar, index) =>
                              FlDotCirclePainter(
                            radius: 4,
                            color: const Color(0xFFD4A574),
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          ),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          color: const Color(0xFFD4A574).withValues(alpha: 0.1),
                        ),
                      ),
                      LineChartBarData(
                        spots: List.generate(
                            5,
                            (i) => FlSpot(
                                i.toDouble(), smallCounts[i].toDouble())),
                        isCurved: true,
                        curveSmoothness: 0.3,
                        color: const Color(0xFF66BB6A),
                        barWidth: 2.5,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, xPercentage, bar, index) =>
                              FlDotCirclePainter(
                            radius: 4,
                            color: const Color(0xFF66BB6A),
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          ),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          color:
                              const Color(0xFF66BB6A).withValues(alpha: 0.08),
                        ),
                      ),
                      LineChartBarData(
                        spots: List.generate(
                            5,
                            (i) => FlSpot(
                                i.toDouble(), totalCounts[i].toDouble())),
                        isCurved: true,
                        curveSmoothness: 0.3,
                        color: const Color(0xFF90CAF9),
                        barWidth: 2.5,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, xPercentage, bar, index) =>
                              FlDotCirclePainter(
                            radius: 4,
                            color: const Color(0xFF90CAF9),
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          ),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          color:
                              const Color(0xFF90CAF9).withValues(alpha: 0.08),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _legendDot(Color color) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
