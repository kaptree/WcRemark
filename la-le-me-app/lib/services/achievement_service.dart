import 'dart:math';
import 'package:sqflite/sqflite.dart';
import '../models/toilet_record.dart';
import '../models/achievement.dart';
import 'database_service.dart';
import 'regularity_calculator.dart';

class AchievementService {
  static Future<List<String>> checkAndUnlock(
    ToiletRecord newRecord,
    List<ToiletRecord> history,
  ) async {
    final allRecords = await DatabaseService.getRecords();
    final alreadyUnlocked = await getUnlockedIds();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final unlocked = <String>[];

    final bigRecords =
        allRecords.where((r) => r.type == RecordType.big).toList();
    final totalBig = bigRecords.length;

    if (!alreadyUnlocked.contains('first_big') && totalBig >= 1) {
      unlocked.add('first_big');
    }
    if (!alreadyUnlocked.contains('first_10') && totalBig >= 10) {
      unlocked.add('first_10');
    }
    if (!alreadyUnlocked.contains('first_50') && totalBig >= 50) {
      unlocked.add('first_50');
    }
    if (!alreadyUnlocked.contains('first_100') && totalBig >= 100) {
      unlocked.add('first_100');
    }
    if (!alreadyUnlocked.contains('first_365') && totalBig >= 365) {
      unlocked.add('first_365');
    }
    if (!alreadyUnlocked.contains('first_500') && totalBig >= 500) {
      unlocked.add('first_500');
    }
    if (!alreadyUnlocked.contains('first_1000') && totalBig >= 1000) {
      unlocked.add('first_1000');
    }

    if (!alreadyUnlocked.contains('first_bristol')) {
      if (bigRecords.any((r) => r.bristolType != null)) {
        unlocked.add('first_bristol');
      }
    }
    if (!alreadyUnlocked.contains('first_paid')) {
      if (allRecords.any((r) => r.isPaidPoop)) {
        unlocked.add('first_paid');
      }
    }
    if (!alreadyUnlocked.contains('first_morning')) {
      if (bigRecords.any((r) {
        final h = DateTime.fromMillisecondsSinceEpoch(r.timestamp).hour;
        return h >= 6 && h <= 9;
      })) {
        unlocked.add('first_morning');
      }
    }
    if (!alreadyUnlocked.contains('first_weekend')) {
      if (allRecords.any((r) {
        final wd = DateTime.fromMillisecondsSinceEpoch(r.timestamp).weekday;
        return wd == DateTime.saturday || wd == DateTime.sunday;
      })) {
        unlocked.add('first_weekend');
      }
    }

    if (!alreadyUnlocked.contains('morning_7')) {
      if (_morningStreak(bigRecords) >= 7) {
        unlocked.add('morning_7');
      }
    }
    if (!alreadyUnlocked.contains('morning_21')) {
      if (_countMorningDays(bigRecords) >= 21) {
        unlocked.add('morning_21');
      }
    }
    if (!alreadyUnlocked.contains('morning_streak_30')) {
      if (_morningStreak(bigRecords) >= 30) {
        unlocked.add('morning_streak_30');
      }
    }
    if (!alreadyUnlocked.contains('lunch_7')) {
      if (_timeSlotStreak(bigRecords, 12, 14) >= 7) {
        unlocked.add('lunch_7');
      }
    }
    if (!alreadyUnlocked.contains('evening_7')) {
      if (_timeSlotStreak(bigRecords, 18, 21) >= 7) {
        unlocked.add('evening_7');
      }
    }
    if (!alreadyUnlocked.contains('same_time_7')) {
      if (_checkSameTime7(bigRecords)) {
        unlocked.add('same_time_7');
      }
    }
    if (!alreadyUnlocked.contains('weekend_regular')) {
      if (_checkWeekendRegular(bigRecords)) {
        unlocked.add('weekend_regular');
      }
    }
    if (!alreadyUnlocked.contains('midnight_3')) {
      if (_checkMidnight3(bigRecords)) {
        unlocked.add('midnight_3');
      }
    }

    final streak = _calculateStreak(bigRecords);
    if (!alreadyUnlocked.contains('streak_7') && streak >= 7) {
      unlocked.add('streak_7');
    }
    if (!alreadyUnlocked.contains('streak_30') && streak >= 30) {
      unlocked.add('streak_30');
    }
    if (!alreadyUnlocked.contains('streak_100') && streak >= 100) {
      unlocked.add('streak_100');
    }
    if (!alreadyUnlocked.contains('streak_365') && streak >= 365) {
      unlocked.add('streak_365');
    }
    if (!alreadyUnlocked.contains('no_skip_30')) {
      if (_checkNoSkip30(bigRecords)) {
        unlocked.add('no_skip_30');
      }
    }

    if (!alreadyUnlocked.contains('perfect_bristol')) {
      if (_checkBristolGold(bigRecords)) {
        unlocked.add('perfect_bristol');
      }
    }
    if (!alreadyUnlocked.contains('bristol_master')) {
      if (_checkBristolAll(bigRecords)) {
        unlocked.add('bristol_master');
      }
    }
    if (!alreadyUnlocked.contains('fiber_rich')) {
      if (_checkFiberRich(bigRecords)) {
        unlocked.add('fiber_rich');
      }
    }
    if (!alreadyUnlocked.contains('fiber_7')) {
      if (_checkFiberStreak(bigRecords, 7)) {
        unlocked.add('fiber_7');
      }
    }
    if (!alreadyUnlocked.contains('bristol_3_streak')) {
      if (_checkBristolConsecutive(bigRecords, 3, 5)) {
        unlocked.add('bristol_3_streak');
      }
    }
    if (!alreadyUnlocked.contains('bristol_4_streak')) {
      if (_checkBristolConsecutive(bigRecords, 4, 5)) {
        unlocked.add('bristol_4_streak');
      }
    }
    if (!alreadyUnlocked.contains('no_constipation_30')) {
      if (_checkNoBadBristol(bigRecords, [1, 2], 30)) {
        unlocked.add('no_constipation_30');
      }
    }
    if (!alreadyUnlocked.contains('no_diarrhea_30')) {
      if (_checkNoBadBristol(bigRecords, [6, 7], 30)) {
        unlocked.add('no_diarrhea_30');
      }
    }
    if (!alreadyUnlocked.contains('golden_30')) {
      if (_checkGolden30(bigRecords)) {
        unlocked.add('golden_30');
      }
    }
    if (!alreadyUnlocked.contains('balanced')) {
      if (_checkBalanced(bigRecords)) {
        unlocked.add('balanced');
      }
    }
    if (!alreadyUnlocked.contains('comeback')) {
      if (_checkComeback(bigRecords)) {
        unlocked.add('comeback');
      }
    }
    if (!alreadyUnlocked.contains('duration_perfect')) {
      if (_checkDurationPerfect(bigRecords)) {
        unlocked.add('duration_perfect');
      }
    }
    if (!alreadyUnlocked.contains('smoothness_max')) {
      if (bigRecords.where((r) => (r.smoothness ?? 0) >= 5).length >= 10) {
        unlocked.add('smoothness_max');
      }
    }
    if (!alreadyUnlocked.contains('brown_only')) {
      if (_checkBrownOnly(bigRecords)) {
        unlocked.add('brown_only');
      }
    }
    if (!alreadyUnlocked.contains('hydration')) {
      if (_checkHydration(bigRecords)) {
        unlocked.add('hydration');
      }
    }

    if (!alreadyUnlocked.contains('health_a_7')) {
      if (_checkHealthAConsecutive(bigRecords, 7)) {
        unlocked.add('health_a_7');
      }
    }
    if (!alreadyUnlocked.contains('health_a_30')) {
      if (_checkHealthAConsecutive(bigRecords, 30)) {
        unlocked.add('health_a_30');
      }
    }

    if (!alreadyUnlocked.contains('paid_pooper')) {
      final paidCount = allRecords.where((r) => r.isPaidPoop).length;
      if (paidCount >= 10) {
        unlocked.add('paid_pooper');
      }
    }
    if (!alreadyUnlocked.contains('paid_king')) {
      if (_checkPaidKing(allRecords)) {
        unlocked.add('paid_king');
      }
    }
    if (!alreadyUnlocked.contains('paid_100')) {
      final paidCount = allRecords.where((r) => r.isPaidPoop).length;
      if (paidCount >= 100) {
        unlocked.add('paid_100');
      }
    }
    if (!alreadyUnlocked.contains('paid_1h')) {
      if (bigRecords.any((r) => r.isPaidPoop && (r.duration ?? 0) >= 3600)) {
        unlocked.add('paid_1h');
      }
    }
    if (!alreadyUnlocked.contains('speed_king')) {
      if (_checkSpeedKing(bigRecords)) {
        unlocked.add('speed_king');
      }
    }
    if (!alreadyUnlocked.contains('speed_10')) {
      int c = 0;
      for (final r in bigRecords) {
        if (r.duration != null && r.duration! <= 60) c++;
      }
      if (c >= 10) unlocked.add('speed_10');
    }
    if (!alreadyUnlocked.contains('speed_1s')) {
      if (bigRecords.any((r) => r.duration != null && r.duration! <= 10)) {
        unlocked.add('speed_1s');
      }
    }
    if (!alreadyUnlocked.contains('marathon')) {
      if (_checkMarathon(bigRecords)) {
        unlocked.add('marathon');
      }
    }
    if (!alreadyUnlocked.contains('marathon_30')) {
      final marathonCount =
          bigRecords.where((r) => r.duration != null && r.duration! >= 900).length;
      if (marathonCount >= 30) unlocked.add('marathon_30');
    }
    if (!alreadyUnlocked.contains('marathon_1h')) {
      if (bigRecords.any((r) => r.duration != null && r.duration! >= 3600)) {
        unlocked.add('marathon_1h');
      }
    }
    if (!alreadyUnlocked.contains('week_warrior')) {
      if (_checkWeekendWarrior(allRecords)) {
        unlocked.add('week_warrior');
      }
    }
    if (!alreadyUnlocked.contains('mood_recorder')) {
      if (_checkMoodRecorder(allRecords)) {
        unlocked.add('mood_recorder');
      }
    }
    if (!alreadyUnlocked.contains('night_owl')) {
      if (_checkNightOwl(bigRecords)) {
        unlocked.add('night_owl');
      }
    }
    if (!alreadyUnlocked.contains('double_kill')) {
      if (_checkDoubleKill(allRecords)) {
        unlocked.add('double_kill');
      }
    }
    if (!alreadyUnlocked.contains('phone_addict')) {
      if (_checkNoteKeyword(allRecords, ['手机', '刷手机', 'phone', '抖音', '微博', '小红书'], 20)) {
        unlocked.add('phone_addict');
      }
    }
    if (!alreadyUnlocked.contains('reader')) {
      if (_checkNoteKeyword(allRecords, ['看书', '读书', '书籍', '阅读', '小说', '杂志', '书', 'read', 'book'], 10)) {
        unlocked.add('reader');
      }
    }
    if (!alreadyUnlocked.contains('thinker')) {
      if (_checkNoteThought(bigRecords)) {
        unlocked.add('thinker');
      }
    }
    if (!alreadyUnlocked.contains('gamer')) {
      if (_checkNoteKeyword(allRecords, ['游戏', '打游戏', 'game', '王者', '吃鸡', '原神', '开黑', '排位'], 5)) {
        unlocked.add('gamer');
      }
    }
    if (!alreadyUnlocked.contains('holiday_pooper')) {
      if (_checkHolidayStreak(bigRecords)) {
        unlocked.add('holiday_pooper');
      }
    }
    if (!alreadyUnlocked.contains('traveler')) {
      final cities = <String>{};
      for (final r in bigRecords) {
        final city = _extractCity(r.note ?? '', r.locationHash ?? '');
        if (city.isNotEmpty) cities.add(city);
      }
      if (cities.length >= 3) unlocked.add('traveler');
    }
    if (!alreadyUnlocked.contains('home_king')) {
      if (_countLocationType(allRecords, '家') >= 100) {
        unlocked.add('home_king');
      }
    }
    if (!alreadyUnlocked.contains('office_vip')) {
      if (_countLocationType(allRecords, '公司') >= 50) {
        unlocked.add('office_vip');
      }
    }
    if (!alreadyUnlocked.contains('mall_hunter')) {
      if (_countDistinctLocations(allRecords, '商场') >= 5) {
        unlocked.add('mall_hunter');
      }
    }
    if (!alreadyUnlocked.contains('gas_station')) {
      if (allRecords.any((r) => _noteContains(r.note, ['服务区', '加油站', '高速']))) {
        unlocked.add('gas_station');
      }
    }
    if (!alreadyUnlocked.contains('birthday_pooper')) {
      if (_checkDateMatch(bigRecords, _isBirthdayMonthDay)) {
        unlocked.add('birthday_pooper');
      }
    }
    if (!alreadyUnlocked.contains('new_year')) {
      if (bigRecords.any((r) {
        final dt = DateTime.fromMillisecondsSinceEpoch(r.timestamp);
        return dt.month == 1 && dt.day == 1;
      })) {
        unlocked.add('new_year');
      }
    }

    if (!alreadyUnlocked.contains('mood_happy')) {
      if (bigRecords.where((r) => r.mood == '开心').length >= 10) {
        unlocked.add('mood_happy');
      }
    }
    if (!alreadyUnlocked.contains('mood_sad')) {
      if (bigRecords.where((r) => r.mood == '痛苦').length >= 10) {
        unlocked.add('mood_sad');
      }
    }
    if (!alreadyUnlocked.contains('mood_calm')) {
      if (bigRecords.where((r) => r.mood == '平静').length >= 10) {
        unlocked.add('mood_calm');
      }
    }
    if (!alreadyUnlocked.contains('mood_angry')) {
      if (bigRecords.where((r) => r.mood == '烦躁').length >= 10) {
        unlocked.add('mood_angry');
      }
    }
    if (!alreadyUnlocked.contains('all_moods')) {
      final allMoods = bigRecords
          .where((r) => r.mood != null)
          .map((r) => r.mood!)
          .toSet();
      if (allMoods.length >= 8) unlocked.add('all_moods');
    }

    if (!alreadyUnlocked.contains('color_all')) {
      if (_checkColorAll(bigRecords)) {
        unlocked.add('color_all');
      }
    }
    if (!alreadyUnlocked.contains('duration_all')) {
      if (_checkDurationAll(bigRecords)) {
        unlocked.add('duration_all');
      }
    }
    if (!alreadyUnlocked.contains('location_5')) {
      if (_countLocationCategories(bigRecords) >= 5) {
        unlocked.add('location_5');
      }
    }
    if (!alreadyUnlocked.contains('location_10')) {
      final locs = <String>{};
      for (final r in bigRecords) {
        if (r.locationHash != null && r.locationHash!.isNotEmpty) {
          locs.add(r.locationHash!);
        }
      }
      if (locs.length >= 10) unlocked.add('location_10');
    }
    if (!alreadyUnlocked.contains('weekday_all')) {
      final wds = <int>{};
      for (final r in bigRecords) {
        wds.add(DateTime.fromMillisecondsSinceEpoch(r.timestamp).weekday);
      }
      if (wds.length >= 7) unlocked.add('weekday_all');
    }
    if (!alreadyUnlocked.contains('month_all')) {
      final months = <int>{};
      for (final r in bigRecords) {
        months.add(DateTime.fromMillisecondsSinceEpoch(r.timestamp).month);
      }
      if (months.length >= 12) unlocked.add('month_all');
    }
    if (!alreadyUnlocked.contains('hour_all')) {
      final hours = <int>{};
      for (final r in allRecords) {
        hours.add(DateTime.fromMillisecondsSinceEpoch(r.timestamp).hour);
      }
      if (hours.length >= 24) unlocked.add('hour_all');
    }

    if (!alreadyUnlocked.contains('achievement_10')) {
      if (alreadyUnlocked.length >= 9) unlocked.add('achievement_10');
    }
    if (!alreadyUnlocked.contains('achievement_50')) {
      if (alreadyUnlocked.length >= 49) unlocked.add('achievement_50');
    }
    if (!alreadyUnlocked.contains('achievement_all')) {
      final defs = Achievement.definitions;
      if (alreadyUnlocked.length >= defs.length - 1) unlocked.add('achievement_all');
    }

    if (!alreadyUnlocked.contains('rainy_day')) {
      if (_checkNoteKeyword(allRecords, ['下雨', '雨天', '雨', 'rain'], 1)) {
        unlocked.add('rainy_day');
      }
    }
    if (!alreadyUnlocked.contains('sunny_day')) {
      if (_checkNoteKeyword(allRecords, ['晴天', '晴', '阳光', 'sunny'], 1)) {
        unlocked.add('sunny_day');
      }
    }
    if (!alreadyUnlocked.contains('full_moon')) {
      if (bigRecords.any((r) {
        final dt = DateTime.fromMillisecondsSinceEpoch(r.timestamp);
        return _isFullMoonDay(dt);
      })) {
        unlocked.add('full_moon');
      }
    }
    if (!alreadyUnlocked.contains('friday_13')) {
      if (bigRecords.any((r) {
        final dt = DateTime.fromMillisecondsSinceEpoch(r.timestamp);
        return dt.weekday == DateTime.friday && dt.day == 13;
      })) {
        unlocked.add('friday_13');
      }
    }
    if (!alreadyUnlocked.contains('leap_day')) {
      if (bigRecords.any((r) {
        final dt = DateTime.fromMillisecondsSinceEpoch(r.timestamp);
        return dt.month == 2 && dt.day == 29;
      })) {
        unlocked.add('leap_day');
      }
    }

    final seasonScore = await _getCurrentSeasonScore();
    if (!alreadyUnlocked.contains('score_500') && seasonScore >= 500) {
      unlocked.add('score_500');
    }
    if (!alreadyUnlocked.contains('score_2000') && seasonScore >= 2000) {
      unlocked.add('score_2000');
    }
    if (!alreadyUnlocked.contains('score_10000') && seasonScore >= 10000) {
      unlocked.add('score_10000');
    }

    final newUnlocks =
        unlocked.where((id) => !alreadyUnlocked.contains(id)).toList();

    if (newUnlocks.isNotEmpty && !alreadyUnlocked.contains('first_achievement') && !newUnlocks.contains('first_achievement')) {
      newUnlocks.add('first_achievement');
    }

    for (final id in newUnlocks) {
      await _saveUnlock(id, timestamp);
    }
    return newUnlocks;
  }

  static Future<List<String>> getUnlockedIds() async {
    final db = await DatabaseService.database;
    final maps = await db.query('achievements', columns: ['id']);
    return maps.map((m) => m['id'] as String).toList();
  }

  static Future<int> getUnlockedCount() async {
    final ids = await getUnlockedIds();
    return ids.length;
  }

  static Future<int> getTotalCount() async {
    return Achievement.definitions.length;
  }

  static Future<int?> getUnlockTime(String id) async {
    final db = await DatabaseService.database;
    final maps = await db.query('achievements',
        where: 'id = ?', whereArgs: [id], columns: ['unlocked_at']);
    if (maps.isEmpty) return null;
    return maps.first['unlocked_at'] as int;
  }

  static Future<List<Achievement>> getAllWithStatus() async {
    final unlockedIds = await getUnlockedIds();
    final allRecords = await DatabaseService.getRecords();
    final bigRecords =
        allRecords.where((r) => r.type == RecordType.big).toList();
    final smallRecords =
        allRecords.where((r) => r.type == RecordType.small).toList();
    final seasonScore = await _getCurrentSeasonScore();

    final results = <Achievement>[];
    for (final def in Achievement.definitions) {
      final isUnlocked = unlockedIds.contains(def.id);
      int? unlockAt;
      if (isUnlocked) {
        final db = await DatabaseService.database;
        final maps = await db.query('achievements',
            where: 'id = ?', whereArgs: [def.id], columns: ['unlocked_at']);
        if (maps.isNotEmpty) unlockAt = maps.first['unlocked_at'] as int;
      }

      Map<String, dynamic>? progress;
      if (!isUnlocked) {
        progress = _calcProgress(
            def.id, bigRecords, smallRecords, allRecords, seasonScore, unlockedIds);
      }

      results
          .add(Achievement(def: def, unlockedAt: unlockAt, progress: progress));
    }
    return results;
  }

  static Map<String, dynamic> _calcProgress(
    String id,
    List<ToiletRecord> bigRecords,
    List<ToiletRecord> smallRecords,
    List<ToiletRecord> allRecords,
    int seasonScore,
    List<String> unlockedIds,
  ) {
    final totalBig = bigRecords.length;
    final streak = _calculateStreak(bigRecords);

    switch (id) {
      case 'first_big':
        return {'current': totalBig >= 1 ? 1 : 0, 'target': 1};
      case 'first_10':
        return {'current': totalBig, 'target': 10};
      case 'first_50':
        return {'current': totalBig, 'target': 50};
      case 'first_100':
        return {'current': totalBig, 'target': 100};
      case 'first_365':
        return {'current': totalBig, 'target': 365};
      case 'first_500':
        return {'current': totalBig, 'target': 500};
      case 'first_1000':
        return {'current': totalBig, 'target': 1000};
      case 'first_bristol':
        return {'current': bigRecords.any((r) => r.bristolType != null) ? 1 : 0, 'target': 1};
      case 'first_paid':
        return {'current': allRecords.any((r) => r.isPaidPoop) ? 1 : 0, 'target': 1};
      case 'first_morning':
        return {'current': bigRecords.any((r) { final h = DateTime.fromMillisecondsSinceEpoch(r.timestamp).hour; return h >= 6 && h <= 9; }) ? 1 : 0, 'target': 1};
      case 'first_weekend':
        return {'current': allRecords.any((r) { final wd = DateTime.fromMillisecondsSinceEpoch(r.timestamp).weekday; return wd == DateTime.saturday || wd == DateTime.sunday; }) ? 1 : 0, 'target': 1};
      case 'first_achievement':
        return {'current': unlockedIds.length, 'target': 1};
      case 'first_share':
        return {'current': 0, 'target': 1};
      case 'morning_7':
        return {'current': _morningStreak(bigRecords), 'target': 7};
      case 'morning_21':
        return {'current': _countMorningDays(bigRecords), 'target': 21};
      case 'morning_streak_30':
        return {'current': _morningStreak(bigRecords), 'target': 30};
      case 'lunch_7':
        return {'current': _timeSlotStreak(bigRecords, 12, 14), 'target': 7};
      case 'evening_7':
        return {'current': _timeSlotStreak(bigRecords, 18, 21), 'target': 7};
      case 'same_time_7':
        return {'current': _countSameTimeStreak(bigRecords), 'target': 7};
      case 'weekend_regular':
        return {'current': _countWeekendRegular(bigRecords), 'target': 4};
      case 'midnight_3':
        return {'current': _midnightConsecutive(bigRecords), 'target': 3};
      case 'streak_7':
        return {'current': streak, 'target': 7};
      case 'streak_30':
        return {'current': streak, 'target': 30};
      case 'streak_100':
        return {'current': streak, 'target': 100};
      case 'streak_365':
        return {'current': streak, 'target': 365};
      case 'no_skip_30':
        return {'current': _countNoSkipStreak(bigRecords), 'target': 30};
      case 'perfect_bristol':
        {
          final gold = bigRecords
              .where((r) => r.bristolType == 3 || r.bristolType == 4)
              .length;
          return {
            'current': bigRecords.length,
            'target': 10,
            'gold_count': gold
          };
        }
      case 'bristol_master':
        {
          final types =
              bigRecords.map((r) => r.bristolType).whereType<int>().toSet();
          return {'current': types.length, 'target': 7};
        }
      case 'fiber_rich':
        {
          int c = 0;
          Set<String> seen = {};
          for (final r in bigRecords.reversed) {
            final bt = r.bristolType;
            if (bt != 3 && bt != 4) break;
            final dt = DateTime.fromMillisecondsSinceEpoch(r.timestamp);
            final key = '${dt.year}-${dt.month}-${dt.day}';
            if (!seen.contains(key)) {
              seen.add(key);
              c++;
            }
          }
          return {'current': c, 'target': 3};
        }
      case 'fiber_7':
        {
          int c = 0;
          Set<String> seen = {};
          for (final r in bigRecords.reversed) {
            final bt = r.bristolType;
            if (bt != 3 && bt != 4) break;
            final dt = DateTime.fromMillisecondsSinceEpoch(r.timestamp);
            final key = '${dt.year}-${dt.month}-${dt.day}';
            if (!seen.contains(key)) {
              seen.add(key);
              c++;
            }
          }
          return {'current': c, 'target': 7};
        }
      case 'bristol_3_streak':
        return {'current': _countBristolConsecutive(bigRecords, 3), 'target': 5};
      case 'bristol_4_streak':
        return {'current': _countBristolConsecutive(bigRecords, 4), 'target': 5};
      case 'no_constipation_30':
        return {'current': _countNoBadBristolStreak(bigRecords, [1, 2]), 'target': 30};
      case 'no_diarrhea_30':
        return {'current': _countNoBadBristolStreak(bigRecords, [6, 7]), 'target': 30};
      case 'golden_30':
        return {'current': _countGoldenStreak(bigRecords), 'target': 30};
      case 'balanced':
        {
          final type3 = bigRecords.where((r) => r.bristolType == 3).length;
          final type4 = bigRecords.where((r) => r.bristolType == 4).length;
          final minCount = min(type3, type4);
          return {'current': minCount, 'target': 20, 'type3': type3, 'type4': type4};
        }
      case 'comeback':
        return {'current': _checkComeback(bigRecords) ? 1 : 0, 'target': 1};
      case 'duration_perfect':
        {
          int c = 0;
          for (final r in bigRecords.reversed) {
            if (r.duration == null) break;
            final min = r.duration! ~/ 60;
            if (min < 3 || min > 8) break;
            c++;
          }
          return {'current': c, 'target': 7};
        }
      case 'smoothness_max':
        return {'current': bigRecords.where((r) => (r.smoothness ?? 0) >= 5).length, 'target': 10};
      case 'brown_only':
        {
          int c = 0;
          for (final r in bigRecords.reversed) {
            if (r.color == null || r.color != 1) break;
            c++;
          }
          return {'current': c, 'target': 20};
        }
      case 'hydration':
        {
          int c = 0;
          Set<String> seen = {};
          for (final r in bigRecords.reversed) {
            if ((r.smoothness ?? 0) < 4) break;
            final dt = DateTime.fromMillisecondsSinceEpoch(r.timestamp);
            final key = '${dt.year}-${dt.month}-${dt.day}';
            if (!seen.contains(key)) {
              seen.add(key);
              c++;
            }
          }
          return {'current': c, 'target': 7};
        }
      case 'health_a_7':
        return {'current': _countHealthAConsecutive(bigRecords), 'target': 7};
      case 'health_a_30':
        return {'current': _countHealthAConsecutive(bigRecords), 'target': 30};
      case 'paid_pooper':
        {
          final c = allRecords.where((r) => r.isPaidPoop).length;
          return {'current': c, 'target': 10};
        }
      case 'paid_king':
        {
          final c = allRecords.where((r) => r.isPaidPoop).length;
          final totalSec = allRecords
              .where((r) => r.isPaidPoop && r.duration != null)
              .fold<int>(0, (s, r) => s + r.duration!);
          final hours = (totalSec / 3600).toStringAsFixed(1);
          return {'current': c, 'target': 50, 'paid_hours': hours};
        }
      case 'paid_100':
        {
          final c = allRecords.where((r) => r.isPaidPoop).length;
          return {'current': c, 'target': 100};
        }
      case 'paid_1h':
        return {'current': bigRecords.any((r) => r.isPaidPoop && (r.duration ?? 0) >= 3600) ? 1 : 0, 'target': 1};
      case 'speed_king':
        {
          int c = 0;
          for (final r in bigRecords) {
            if (r.duration != null) {
              final min = r.duration! / 60;
              if (min >= 1 && min <= 3) c++;
            }
          }
          return {'current': c, 'target': 5};
        }
      case 'speed_10':
        {
          int c = 0;
          for (final r in bigRecords) {
            if (r.duration != null && r.duration! <= 60) c++;
          }
          return {'current': c, 'target': 10};
        }
      case 'speed_1s':
        return {'current': bigRecords.any((r) => r.duration != null && r.duration! <= 10) ? 1 : 0, 'target': 1};
      case 'marathon':
        return {'current': bigRecords.any((r) => r.duration != null && r.duration! >= 900) ? 1 : 0, 'target': 1};
      case 'marathon_30':
        {
          int c = bigRecords.where((r) => r.duration != null && r.duration! >= 900).length;
          return {'current': c, 'target': 30};
        }
      case 'marathon_1h':
        return {'current': bigRecords.any((r) => r.duration != null && r.duration! >= 3600) ? 1 : 0, 'target': 1};
      case 'week_warrior':
        return {'current': unlockedIds.contains(id) ? 1 : 0, 'target': 1};
      case 'mood_recorder':
        {
          final moods = allRecords
              .where((r) => r.mood != null)
              .map((r) => r.mood!)
              .toSet();
          return {'current': moods.length, 'target': 5};
        }
      case 'night_owl':
        {
          int c = 0;
          for (final r in bigRecords) {
            final h = DateTime.fromMillisecondsSinceEpoch(r.timestamp).hour;
            if (h >= 0 && h < 5) c++;
          }
          return {'current': c, 'target': 3};
        }
      case 'double_kill':
        return {'current': _checkDoubleKill(allRecords) ? 1 : 0, 'target': 1};
      case 'phone_addict':
        return {'current': _countNoteKeyword(allRecords, ['手机', '刷手机', 'phone', '抖音', '微博', '小红书']), 'target': 20};
      case 'reader':
        return {'current': _countNoteKeyword(allRecords, ['看书', '读书', '书籍', '阅读', '小说', '杂志', '书', 'read', 'book']), 'target': 10};
      case 'thinker':
        return {'current': _countThoughtRecords(bigRecords), 'target': 5};
      case 'gamer':
        return {'current': _countNoteKeyword(allRecords, ['游戏', '打游戏', 'game', '王者', '吃鸡', '原神', '开黑', '排位']), 'target': 5};
      case 'holiday_pooper':
        {
          final days = _countHolidayStreak(bigRecords);
          return {'current': days, 'target': 7};
        }
      case 'traveler':
        {
          final cities = <String>{};
          for (final r in bigRecords) {
            final city = _extractCity(r.note ?? '', r.locationHash ?? '');
            if (city.isNotEmpty) cities.add(city);
          }
          return {'current': cities.length, 'target': 3};
        }
      case 'home_king':
        return {'current': _countLocationType(allRecords, '家'), 'target': 100};
      case 'office_vip':
        return {'current': _countLocationType(allRecords, '公司'), 'target': 50};
      case 'mall_hunter':
        return {'current': _countDistinctLocations(allRecords, '商场'), 'target': 5};
      case 'gas_station':
        return {'current': allRecords.any((r) => _noteContains(r.note, ['服务区', '加油站', '高速'])) ? 1 : 0, 'target': 1};
      case 'birthday_pooper':
        return {'current': bigRecords.any((r) => _isBirthdayRecord(r)) ? 1 : 0, 'target': 1};
      case 'new_year':
        return {'current': bigRecords.any((r) { final dt = DateTime.fromMillisecondsSinceEpoch(r.timestamp); return dt.month == 1 && dt.day == 1; }) ? 1 : 0, 'target': 1};
      case 'mood_happy':
        return {'current': bigRecords.where((r) => r.mood == '开心').length, 'target': 10};
      case 'mood_sad':
        return {'current': bigRecords.where((r) => r.mood == '痛苦').length, 'target': 10};
      case 'mood_calm':
        return {'current': bigRecords.where((r) => r.mood == '平静').length, 'target': 10};
      case 'mood_angry':
        return {'current': bigRecords.where((r) => r.mood == '烦躁').length, 'target': 10};
      case 'all_moods':
        {
          final allMoods = bigRecords
              .where((r) => r.mood != null)
              .map((r) => r.mood!)
              .toSet();
          return {'current': allMoods.length, 'target': 8};
        }
      case 'color_all':
        {
          final colors = bigRecords
              .map((r) => r.color)
              .whereType<int>()
              .toSet();
          return {'current': colors.length, 'target': 5};
        }
      case 'duration_all':
        {
          int c = 0;
          final hasShort = bigRecords.any((r) => r.duration != null && r.duration! <= 120);
          final hasNormal = bigRecords.any((r) { if (r.duration == null) return false; final m = r.duration! ~/ 60; return m >= 3 && m <= 8; });
          final hasLong = bigRecords.any((r) => r.duration != null && r.duration! >= 900);
          if (hasShort) c++;
          if (hasNormal) c++;
          if (hasLong) c++;
          return {'current': c, 'target': 3};
        }
      case 'location_5':
        return {'current': _countLocationCategories(bigRecords), 'target': 5};
      case 'location_10':
        {
          final locs = <String>{};
          for (final r in bigRecords) {
            if (r.locationHash != null && r.locationHash!.isNotEmpty) {
              locs.add(r.locationHash!);
            }
          }
          return {'current': locs.length, 'target': 10};
        }
      case 'weekday_all':
        {
          final wds = <int>{};
          for (final r in bigRecords) {
            wds.add(DateTime.fromMillisecondsSinceEpoch(r.timestamp).weekday);
          }
          return {'current': wds.length, 'target': 7};
        }
      case 'month_all':
        {
          final months = <int>{};
          for (final r in bigRecords) {
            months.add(DateTime.fromMillisecondsSinceEpoch(r.timestamp).month);
          }
          return {'current': months.length, 'target': 12};
        }
      case 'hour_all':
        {
          final hours = <int>{};
          for (final r in allRecords) {
            hours.add(DateTime.fromMillisecondsSinceEpoch(r.timestamp).hour);
          }
          return {'current': hours.length, 'target': 24};
        }
      case 'achievement_10':
        return {'current': unlockedIds.length, 'target': 10};
      case 'achievement_50':
        return {'current': unlockedIds.length, 'target': 50};
      case 'achievement_all':
        return {'current': unlockedIds.length, 'target': Achievement.definitions.length};
      case 'rainy_day':
        return {'current': allRecords.any((r) => _noteContains(r.note, ['下雨', '雨天', '雨', 'rain'])) ? 1 : 0, 'target': 1};
      case 'sunny_day':
        return {'current': allRecords.any((r) => _noteContains(r.note, ['晴天', '晴', '阳光', 'sunny'])) ? 1 : 0, 'target': 1};
      case 'full_moon':
        return {'current': bigRecords.any((r) { final dt = DateTime.fromMillisecondsSinceEpoch(r.timestamp); return _isFullMoonDay(dt); }) ? 1 : 0, 'target': 1};
      case 'friday_13':
        return {'current': bigRecords.any((r) { final dt = DateTime.fromMillisecondsSinceEpoch(r.timestamp); return dt.weekday == DateTime.friday && dt.day == 13; }) ? 1 : 0, 'target': 1};
      case 'leap_day':
        return {'current': bigRecords.any((r) { final dt = DateTime.fromMillisecondsSinceEpoch(r.timestamp); return dt.month == 2 && dt.day == 29; }) ? 1 : 0, 'target': 1};
      case 'score_500':
        return {'current': seasonScore, 'target': 500};
      case 'score_2000':
        return {'current': seasonScore, 'target': 2000};
      case 'score_10000':
        return {'current': seasonScore, 'target': 10000};
      default:
        return {'current': 0, 'target': 1};
    }
  }

  static int _morningStreak(List<ToiletRecord> bigRecords) {
    final sorted = List<ToiletRecord>.from(bigRecords)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    int streak = 0;
    DateTime? prevDate;
    for (final r in sorted) {
      final dt = DateTime.fromMillisecondsSinceEpoch(r.timestamp);
      final h = dt.hour;
      if (h < 6 || h > 9) continue;
      final dateKey = DateTime(dt.year, dt.month, dt.day);
      if (prevDate == null || prevDate.difference(dateKey).inDays == 1) {
        streak++;
        prevDate = dateKey;
      } else if (prevDate != dateKey) {
        break;
      }
    }
    return streak;
  }

  static int _countMorningDays(List<ToiletRecord> bigRecords) {
    final days = <String>{};
    for (final r in bigRecords) {
      final dt = DateTime.fromMillisecondsSinceEpoch(r.timestamp);
      if (dt.hour >= 6 && dt.hour <= 9) {
        days.add('${dt.year}-${dt.month}-${dt.day}');
      }
    }
    return days.length;
  }

  static int _timeSlotStreak(List<ToiletRecord> bigRecords, int start, int end) {
    final sorted = List<ToiletRecord>.from(bigRecords)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    int streak = 0;
    DateTime? prevDate;
    for (final r in sorted) {
      final dt = DateTime.fromMillisecondsSinceEpoch(r.timestamp);
      if (dt.hour < start || dt.hour > end) continue;
      final dateKey = DateTime(dt.year, dt.month, dt.day);
      if (prevDate == null || prevDate.difference(dateKey).inDays == 1) {
        streak++;
        prevDate = dateKey;
      } else if (prevDate != dateKey) {
        break;
      }
    }
    return streak;
  }

  static bool _checkSameTime7(List<ToiletRecord> bigRecords) {
    final groups = <int, List<ToiletRecord>>{};
    for (final r in bigRecords) {
      final dt = DateTime.fromMillisecondsSinceEpoch(r.timestamp);
      final slot = dt.hour * 60 + (dt.minute ~/ 30) * 30;
      groups.putIfAbsent(slot, () => []).add(r);
    }
    return groups.values.any((list) => list.length >= 7);
  }

  static int _countSameTimeStreak(List<ToiletRecord> bigRecords) {
    final groups = <int, List<ToiletRecord>>{};
    for (final r in bigRecords) {
      final dt = DateTime.fromMillisecondsSinceEpoch(r.timestamp);
      final slot = dt.hour * 60 + (dt.minute ~/ 30) * 30;
      groups.putIfAbsent(slot, () => []).add(r);
    }
    int maxCount = 0;
    for (final list in groups.values) {
      if (list.length > maxCount) maxCount = list.length;
    }
    return maxCount;
  }

  static bool _checkWeekendRegular(List<ToiletRecord> bigRecords) {
    final weekendDays = <String>{};
    for (final r in bigRecords) {
      final dt = DateTime.fromMillisecondsSinceEpoch(r.timestamp);
      if (dt.weekday == DateTime.saturday || dt.weekday == DateTime.sunday) {
        weekendDays.add('${dt.year}-${dt.month}-${dt.day}');
      }
    }
    return weekendDays.length >= 4;
  }

  static int _countWeekendRegular(List<ToiletRecord> bigRecords) {
    final weekendDays = <String>{};
    for (final r in bigRecords) {
      final dt = DateTime.fromMillisecondsSinceEpoch(r.timestamp);
      if (dt.weekday == DateTime.saturday || dt.weekday == DateTime.sunday) {
        weekendDays.add('${dt.year}-${dt.month}-${dt.day}');
      }
    }
    return weekendDays.length;
  }

  static bool _checkMidnight3(List<ToiletRecord> bigRecords) {
    return _midnightConsecutive(bigRecords) >= 3;
  }

  static int _midnightConsecutive(List<ToiletRecord> bigRecords) {
    final sorted = List<ToiletRecord>.from(bigRecords)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    int streak = 0;
    DateTime? prevDate;
    for (final r in sorted) {
      final dt = DateTime.fromMillisecondsSinceEpoch(r.timestamp);
      if (dt.hour >= 0 && dt.hour < 5) {
        final dateKey = DateTime(dt.year, dt.month, dt.day);
        if (prevDate == null || prevDate.difference(dateKey).inDays == 1) {
          streak++;
          prevDate = dateKey;
        } else if (prevDate != dateKey) {
          break;
        }
      }
    }
    return streak;
  }

  static int _calculateStreak(List<ToiletRecord> bigRecords) {
    if (bigRecords.isEmpty) return 0;
    final days = <String>{};
    for (final r in bigRecords) {
      final dt = DateTime.fromMillisecondsSinceEpoch(r.timestamp);
      days.add('${dt.year}-${dt.month}-${dt.day}');
    }
    final sorted = days
        .map((d) => DateTime.parse(d))
        .toList()
      ..sort();
    int maxStreak = 1;
    int currentStreak = 1;
    for (int i = 1; i < sorted.length; i++) {
      if (sorted[i].difference(sorted[i - 1]).inDays == 1) {
        currentStreak++;
        if (currentStreak > maxStreak) maxStreak = currentStreak;
      } else {
        currentStreak = 1;
      }
    }
    return maxStreak;
  }

  static bool _checkNoSkip30(List<ToiletRecord> bigRecords) {
    final daySet = <String>{};
    for (final r in bigRecords) {
      final dt = DateTime.fromMillisecondsSinceEpoch(r.timestamp);
      daySet.add('${dt.year}-${dt.month}-${dt.day}');
    }
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    for (var d = thirtyDaysAgo; d.isBefore(now); d = d.add(const Duration(days: 1))) {
      final key = '${d.year}-${d.month}-${d.day}';
      if (!daySet.contains(key)) return false;
    }
    return true;
  }

  static int _countNoSkipStreak(List<ToiletRecord> bigRecords) {
    if (bigRecords.isEmpty) return 0;
    final sorted = List<ToiletRecord>.from(bigRecords)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    int streak = 0;
    DateTime? prevDate;
    for (final r in sorted) {
      final dt = DateTime.fromMillisecondsSinceEpoch(r.timestamp);
      final dateKey = DateTime(dt.year, dt.month, dt.day);
      if (prevDate == null || prevDate.difference(dateKey).inDays == 1) {
        streak++;
        prevDate = dateKey;
      } else if (prevDate != dateKey) {
        break;
      }
    }
    return streak;
  }

  static bool _checkBristolGold(List<ToiletRecord> bigRecords) {
    if (bigRecords.length < 10) return false;
    final gold = bigRecords
        .where((r) => r.bristolType == 3 || r.bristolType == 4)
        .length;
    return gold / bigRecords.length >= 0.7;
  }

  static bool _checkBristolAll(List<ToiletRecord> bigRecords) {
    final types = bigRecords.map((r) => r.bristolType).whereType<int>().toSet();
    return types.length >= 7;
  }

  static bool _checkFiberRich(List<ToiletRecord> bigRecords) {
    final sorted = List<ToiletRecord>.from(bigRecords)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    int consecutive = 0;
    String? prevDay;
    for (final r in sorted) {
      final bt = r.bristolType;
      if (bt != 3 && bt != 4) {
        consecutive = 0;
        prevDay = null;
        continue;
      }
      final dt = DateTime.fromMillisecondsSinceEpoch(r.timestamp);
      final dayKey = '${dt.year}-${dt.month}-${dt.day}';
      if (prevDay == null || prevDay != dayKey) {
        consecutive++;
        prevDay = dayKey;
        if (consecutive >= 3) return true;
      }
    }
    return false;
  }

  static bool _checkFiberStreak(List<ToiletRecord> bigRecords, int target) {
    final sorted = List<ToiletRecord>.from(bigRecords)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    int consecutive = 0;
    String? prevDay;
    for (final r in sorted) {
      final bt = r.bristolType;
      if (bt != 3 && bt != 4) {
        consecutive = 0;
        prevDay = null;
        continue;
      }
      final dt = DateTime.fromMillisecondsSinceEpoch(r.timestamp);
      final dayKey = '${dt.year}-${dt.month}-${dt.day}';
      if (prevDay == null || prevDay != dayKey) {
        consecutive++;
        prevDay = dayKey;
        if (consecutive >= target) return true;
      }
    }
    return false;
  }

  static bool _checkBristolConsecutive(List<ToiletRecord> bigRecords, int targetType, int count) {
    return _countBristolConsecutive(bigRecords, targetType) >= count;
  }

  static int _countBristolConsecutive(List<ToiletRecord> bigRecords, int targetType) {
    final sorted = List<ToiletRecord>.from(bigRecords)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    int consecutive = 0;
    String? prevDay;
    for (final r in sorted) {
      if (r.bristolType != targetType) {
        consecutive = 0;
        prevDay = null;
        continue;
      }
      final dt = DateTime.fromMillisecondsSinceEpoch(r.timestamp);
      final dayKey = '${dt.year}-${dt.month}-${dt.day}';
      if (prevDay == null || prevDay != dayKey) {
        consecutive++;
        prevDay = dayKey;
      }
    }
    return consecutive;
  }

  static bool _checkNoBadBristol(List<ToiletRecord> bigRecords, List<int> badTypes, int targetDays) {
    return _countNoBadBristolStreak(bigRecords, badTypes) >= targetDays;
  }

  static int _countNoBadBristolStreak(List<ToiletRecord> bigRecords, List<int> badTypes) {
    final sorted = List<ToiletRecord>.from(bigRecords)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    bool broken = false;
    for (final r in sorted) {
      if (badTypes.contains(r.bristolType)) {
        broken = true;
      }
    }
    if (broken) return 0;
    final days = <String>{};
    for (final r in sorted) {
      final dt = DateTime.fromMillisecondsSinceEpoch(r.timestamp);
      days.add('${dt.year}-${dt.month}-${dt.day}');
    }
    return days.length;
  }

  static bool _checkGolden30(List<ToiletRecord> bigRecords) {
    return _countGoldenStreak(bigRecords) >= 30;
  }

  static int _countGoldenStreak(List<ToiletRecord> bigRecords) {
    final sorted = List<ToiletRecord>.from(bigRecords)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    int consecutive = 0;
    String? prevDay;
    for (final r in sorted) {
      final bt = r.bristolType;
      if (bt == null || bt < 3 || bt > 4) {
        consecutive = 0;
        prevDay = null;
        continue;
      }
      final dt = DateTime.fromMillisecondsSinceEpoch(r.timestamp);
      final dayKey = '${dt.year}-${dt.month}-${dt.day}';
      if (prevDay == null || prevDay != dayKey) {
        consecutive++;
        prevDay = dayKey;
      }
    }
    return consecutive;
  }

  static bool _checkBalanced(List<ToiletRecord> bigRecords) {
    final type3 = bigRecords.where((r) => r.bristolType == 3).length;
    final type4 = bigRecords.where((r) => r.bristolType == 4).length;
    return type3 >= 20 && type4 >= 20;
  }

  static bool _checkComeback(List<ToiletRecord> bigRecords) {
    if (bigRecords.length < 2) return false;
    final sorted = List<ToiletRecord>.from(bigRecords)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    for (int i = 1; i < sorted.length; i++) {
      final prev = DateTime.fromMillisecondsSinceEpoch(sorted[i - 1].timestamp);
      final curr = DateTime.fromMillisecondsSinceEpoch(sorted[i].timestamp);
      if (curr.difference(prev).inDays >= 5) {
        return true;
      }
    }
    return false;
  }

  static bool _checkDurationPerfect(List<ToiletRecord> bigRecords) {
    final sorted = List<ToiletRecord>.from(bigRecords)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    int consecutive = 0;
    for (final r in sorted) {
      if (r.duration == null) {
        consecutive = 0;
        continue;
      }
      final min = r.duration! ~/ 60;
      if (min >= 3 && min <= 8) {
        consecutive++;
        if (consecutive >= 7) return true;
      } else {
        consecutive = 0;
      }
    }
    return false;
  }

  static bool _checkBrownOnly(List<ToiletRecord> bigRecords) {
    final sorted = List<ToiletRecord>.from(bigRecords)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    int consecutive = 0;
    for (final r in sorted.reversed) {
      if (r.color == null || r.color != 1) break;
      consecutive++;
    }
    return consecutive >= 20;
  }

  static bool _checkHydration(List<ToiletRecord> bigRecords) {
    final sorted = List<ToiletRecord>.from(bigRecords)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    int consecutive = 0;
    String? prevDay;
    for (final r in sorted) {
      if ((r.smoothness ?? 0) < 4) {
        consecutive = 0;
        prevDay = null;
        continue;
      }
      final dt = DateTime.fromMillisecondsSinceEpoch(r.timestamp);
      final dayKey = '${dt.year}-${dt.month}-${dt.day}';
      if (prevDay == null || prevDay != dayKey) {
        consecutive++;
        prevDay = dayKey;
        if (consecutive >= 7) return true;
      }
    }
    return false;
  }

  static bool _checkHealthAConsecutive(List<ToiletRecord> bigRecords, int targetDays) {
    return _countHealthAConsecutive(bigRecords) >= targetDays;
  }

  static int _countHealthAConsecutive(List<ToiletRecord> bigRecords) {
    if (bigRecords.isEmpty) return 0;
    final sorted = List<ToiletRecord>.from(bigRecords)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final now = DateTime.now();
    int consecutive = 0;
    for (int offset = 0; offset < 365; offset++) {
      final monthStart = now.subtract(Duration(days: 30 + offset));
      final monthEnd = now.subtract(Duration(days: offset));
      final monthRecords = sorted
          .where((r) {
            final t = DateTime.fromMillisecondsSinceEpoch(r.timestamp);
            return t.isAfter(monthStart) && t.isBefore(monthEnd);
          })
          .toList();
      final grade = HealthGradeCalculator.calculateMonthly(monthRecords);
      if (grade.grade == 'A') {
        consecutive++;
        if (consecutive >= 30) return consecutive;
      } else {
        break;
      }
    }
    return consecutive;
  }

  static bool _checkPaidKing(List<ToiletRecord> allRecords) {
    final paid = allRecords.where((r) => r.isPaidPoop).toList();
    if (paid.length < 50) return false;
    final totalSeconds = paid
        .where((r) => r.duration != null)
        .fold<int>(0, (s, r) => s + r.duration!);
    return totalSeconds >= 18000;
  }

  static bool _checkSpeedKing(List<ToiletRecord> bigRecords) {
    int count = 0;
    for (final r in bigRecords) {
      if (r.duration != null) {
        final min = r.duration! / 60;
        if (min >= 1 && min <= 3) count++;
      }
    }
    return count >= 5;
  }

  static bool _checkMarathon(List<ToiletRecord> bigRecords) {
    return bigRecords.any((r) => r.duration != null && r.duration! >= 900);
  }

  static bool _checkWeekendWarrior(List<ToiletRecord> allRecords) {
    Set<String> weekendBigDays = {};
    Set<String> weekendSmallDays = {};
    for (final r in allRecords) {
      final dt = DateTime.fromMillisecondsSinceEpoch(r.timestamp);
      if (dt.weekday != DateTime.saturday && dt.weekday != DateTime.sunday) continue;
      final key = '${dt.year}-${dt.month}-${dt.day}';
      if (r.type == RecordType.big) weekendBigDays.add(key);
      if (r.type == RecordType.small) weekendSmallDays.add(key);
    }
    final common = weekendBigDays.intersection(weekendSmallDays);
    return common.length >= 4;
  }

  static bool _checkMoodRecorder(List<ToiletRecord> allRecords) {
    final moods = allRecords
        .where((r) => r.mood != null)
        .map((r) => r.mood!)
        .toSet();
    return moods.length >= 5;
  }

  static bool _checkNightOwl(List<ToiletRecord> bigRecords) {
    int count = 0;
    for (final r in bigRecords) {
      final h = DateTime.fromMillisecondsSinceEpoch(r.timestamp).hour;
      if (h >= 0 && h < 5) count++;
    }
    return count >= 3;
  }

  static bool _checkDoubleKill(List<ToiletRecord> allRecords) {
    Map<String, Set<RecordType>> dayTypes = {};
    for (final r in allRecords) {
      final dt = DateTime.fromMillisecondsSinceEpoch(r.timestamp);
      final key = '${dt.year}-${dt.month}-${dt.day}';
      dayTypes.putIfAbsent(key, () => {}).add(r.type);
    }
    return dayTypes.values
        .any((types) => types.contains(RecordType.big) && types.contains(RecordType.small));
  }

  static bool _checkNoteKeyword(List<ToiletRecord> allRecords, List<String> keywords, int target) {
    return _countNoteKeyword(allRecords, keywords) >= target;
  }

  static int _countNoteKeyword(List<ToiletRecord> allRecords, List<String> keywords) {
    int count = 0;
    for (final r in allRecords) {
      final note = r.note ?? '';
      for (final kw in keywords) {
        if (note.contains(kw)) {
          count++;
          break;
        }
      }
    }
    return count;
  }

  static bool _checkNoteThought(List<ToiletRecord> bigRecords) {
    return _countThoughtRecords(bigRecords) >= 5;
  }

  static int _countThoughtRecords(List<ToiletRecord> bigRecords) {
    int count = 0;
    for (final r in bigRecords) {
      final note = r.note ?? '';
      if (note.length > 30) {
        count++;
      }
    }
    return count;
  }

  static bool _checkHolidayStreak(List<ToiletRecord> bigRecords) {
    return _countHolidayStreak(bigRecords) >= 7;
  }

  static int _countHolidayStreak(List<ToiletRecord> bigRecords) {
    const chineseHolidays = {
      '01-01', '05-01', '05-02', '05-03', '10-01', '10-02', '10-03', '10-04', '10-05', '10-06', '10-07',
    };
    final holidayDays = <String>{};
    for (final r in bigRecords) {
      final dt = DateTime.fromMillisecondsSinceEpoch(r.timestamp);
      final mmdd = '${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      if (chineseHolidays.contains(mmdd)) {
        holidayDays.add('${dt.year}-${dt.month}-${dt.day}');
      }
    }
    return holidayDays.length;
  }

  static String _extractCity(String note, String location) {
    const cities = [
      '北京', '上海', '广州', '深圳', '杭州', '成都', '重庆', '武汉', '西安', '南京',
      '苏州', '天津', '长沙', '郑州', '东莞', '青岛', '沈阳', '宁波', '昆明', '大连',
      '厦门', '合肥', '佛山', '福州', '哈尔滨', '济南', '温州', '长春', '石家庄',
      '常州', '泉州', '南宁', '贵阳', '南昌', '太原', '烟台', '嘉兴', '南通',
      '金华', '珠海', '惠州', '徐州', '海口', '乌鲁木齐', '绍兴', '中山', '台州',
      '兰州', '香港', '澳门', '台北',
      'Tokyo', 'New York', 'London', 'Paris', 'Sydney', 'Bangkok', 'Seoul',
    ];
    for (final city in cities) {
      if (note.contains(city) || location.contains(city)) {
        return city;
      }
    }
    return '';
  }

  static int _countLocationType(List<ToiletRecord> allRecords, String keyword) {
    int count = 0;
    for (final r in allRecords) {
      final note = r.note ?? '';
      final loc = r.locationHash ?? '';
      if (note.contains(keyword) || loc.contains(keyword)) {
        count++;
      }
    }
    return count;
  }

  static int _countDistinctLocations(List<ToiletRecord> allRecords, String keyword) {
    final locs = <String>{};
    for (final r in allRecords) {
      final note = r.note ?? '';
      final loc = r.locationHash ?? '';
      if (note.contains(keyword) || loc.contains(keyword)) {
        locs.add(loc.isNotEmpty ? loc : note);
      }
    }
    return locs.length;
  }

  static bool _noteContains(String? note, List<String> keywords) {
    if (note == null) return false;
    for (final kw in keywords) {
      if (note.contains(kw)) return true;
    }
    return false;
  }

  static bool _checkDateMatch(List<ToiletRecord> bigRecords, bool Function(int month, int day) matcher) {
    return bigRecords.any((r) {
      final dt = DateTime.fromMillisecondsSinceEpoch(r.timestamp);
      return matcher(dt.month, dt.day);
    });
  }

  static bool _isBirthdayMonthDay(int month, int day) {
    return false;
  }

  static bool _isBirthdayRecord(ToiletRecord r) {
    final note = r.note ?? '';
    if (note.contains('生日') || note.contains('birthday')) return true;
    return false;
  }

  static bool _checkColorAll(List<ToiletRecord> bigRecords) {
    final colors = bigRecords.map((r) => r.color).whereType<int>().toSet();
    return colors.length >= 5;
  }

  static bool _checkDurationAll(List<ToiletRecord> bigRecords) {
    bool hasShort = false;
    bool hasNormal = false;
    bool hasLong = false;
    for (final r in bigRecords) {
      if (r.duration == null) continue;
      if (r.duration! <= 120) hasShort = true;
      final min = r.duration! ~/ 60;
      if (min >= 3 && min <= 8) hasNormal = true;
      if (r.duration! >= 900) hasLong = true;
    }
    return hasShort && hasNormal && hasLong;
  }

  static int _countLocationCategories(List<ToiletRecord> bigRecords) {
    final locs = <String>{};
    for (final r in bigRecords) {
      if (r.locationHash != null && r.locationHash!.isNotEmpty) {
        locs.add(r.locationHash!);
      }
    }
    return locs.length;
  }

  static bool _isFullMoonDay(DateTime date) {
    final knownFullMoons = [
      DateTime(2024, 1, 25), DateTime(2024, 2, 24), DateTime(2024, 3, 25),
      DateTime(2024, 4, 23), DateTime(2024, 5, 23), DateTime(2024, 6, 22),
      DateTime(2024, 7, 21), DateTime(2024, 8, 20), DateTime(2024, 9, 18),
      DateTime(2024, 10, 17), DateTime(2024, 11, 16), DateTime(2024, 12, 15),
      DateTime(2025, 1, 14), DateTime(2025, 2, 12), DateTime(2025, 3, 14),
      DateTime(2025, 4, 13), DateTime(2025, 5, 12), DateTime(2025, 6, 11),
      DateTime(2025, 7, 10), DateTime(2025, 8, 9), DateTime(2025, 9, 7),
      DateTime(2025, 10, 7), DateTime(2025, 11, 5), DateTime(2025, 12, 4),
    ];
    final dateOnly = DateTime(date.year, date.month, date.day);
    return knownFullMoons.any((fm) =>
        fm.year == dateOnly.year && fm.month == dateOnly.month && fm.day == dateOnly.day);
  }

  static Future<int> _getCurrentSeasonScore() async {
    try {
      final db = await DatabaseService.database;
      final now = DateTime.now();
      final seasonStart = DateTime(now.year, ((now.month - 1) ~/ 3) * 3 + 1, 1);
      final maps = await db.rawQuery(
        'SELECT SUM(score) as total FROM score_log WHERE created_at >= ?',
        [seasonStart.millisecondsSinceEpoch],
      );
      if (maps.isEmpty || maps.first['total'] == null) return 0;
      return (maps.first['total'] as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> _saveUnlock(String id, int timestamp) async {
    try {
      final db = await DatabaseService.database;
      await db.insert(
        'achievements',
        {
          'id': id,
          'unlocked_at': timestamp,
          'synced': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }
}