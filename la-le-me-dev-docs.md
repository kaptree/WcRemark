# 「拉了么」全栈开发文档 & 功能设计说明书

**版本**：v1.0.10（已构建 APK）  
**日期**：2026-05-14  
**定位**：隐私优先的生理健康记录与轻社交排名应用  
**文档状态**：与代码同步，可直接用于开发实施

---

## 目录

1. [项目概述与架构总览](#一项目概述与架构总览)
2. [客户端功能模块详细设计](#二客户端功能模块详细设计)
3. [数据统计模块](#三数据统计模块)
4. [智能分析模块](#四智能分析模块)
5. [排名模块](#五排名模块)
6. [设置模块](#六设置模块)
7. [后端服务设计](#七后端服务设计)
8. [数据库设计](#八数据库设计)
9. [API 接口详细定义](#九api-接口详细定义)
10. [安全与合规](#十安全与合规)
11. [部署架构](#十一部署架构)
12. [开发里程碑](#十二开发里程碑)
13. [错误码定义](#十三错误码定义)

---

## 一、项目概述与架构总览

### 1.1 核心理念

- **本地优先**：所有原始敏感记录（时间、地点、时长、颜色、三围）默认仅存储在本地 SQLite，云端仅同步**脱敏后的积分与匿名排名数据**。
- **用户主权**：大模型 API Key 由用户自行配置，客户端直调厂商 API，服务端绝不触碰用户隐私数据。
- **游戏化健康**：通过科学的积分与段位体系，将健康管理转化为可持续的动力。

### 1.2 技术栈选型

| 层级 | 技术选型 | 说明 |
|------|---------|------|
| 客户端 | Flutter 3.38.5 (SDK >=3.3.0) | 跨平台，一套代码覆盖 iOS/Android |
| 客户端数据库 | sqflite 2.4 (SQLite) | 本地主存储，支持加密 |
| 客户端状态管理 | Riverpod 2.6 | 响应式，支持异步状态 |
| 客户端图表 | fl_chart | Flutter 原生图表库 |
| 服务端 | Go 1.23 (工具链 1.24) | 高并发、低延迟、编译型 |
| 服务端框架 | Gin v1.9+ | 轻量高性能 Web 框架 |
| ORM | GORM v2 | 支持 PostgreSQL 特性 |
| 主数据库 | PostgreSQL 15 | 支持 JSONB、窗口函数 |
| 缓存 | Redis 7 | Sorted Sets 做实时排行 |
| 消息队列 | Redis Stream | 轻量异步处理 |
| 对象存储 | MinIO / AWS S3 | 加密备份文件存储 |
| 部署 | Docker + K8s | 容器化，支持水平扩展 |
| 监控 | Prometheus + Grafana | 服务端指标监控 |

### 1.3 系统架构图

```
┌─────────────────────────────────────────────────────────────┐
│                        客户端 (Flutter)                       │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐       │
│  │  首页模块 │ │ 统计模块 │ │ 排名模块 │ │ 设置模块 │       │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘       │
│       └─────────────┴─────────────┴─────────────┘            │
│                         │                                   │
│              ┌──────────┴──────────┐                        │
│              │   本地 SQLite DB    │                        │
│              │  (敏感数据主存储)   │                        │
│              │  AES-256 加密      │                        │
│              └──────────┬──────────┘                        │
│       ┌─────────────────┼─────────────────┐                │
│       │                 │                 │                │
│  ┌────▼────┐      ┌────▼────┐      ┌────▼────┐            │
│  │ 大模型API │      │ 后端REST │      │ 生物识别 │            │
│  │(用户配置) │      │  + WS   │      │FaceID/指纹│           │
│  └─────────┘      └────┬────┘      └─────────┘            │
└─────────────────────────┼───────────────────────────────────┘
                          │
┌─────────────────────────┼───────────────────────────────────┐
│                    服务端 (Go + Gin)                         │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐       │
│  │  API网关 │ │  用户服务 │ │  排名服务 │ │  备份服务 │       │
│  │  (JWT)   │ │          │ │(Redis ZSet)│ │          │       │
│  │  限流    │ │          │ │          │ │          │       │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘       │
│       └─────────────┴─────────────┴─────────────┘            │
│                         │                                   │
│              ┌──────────┴──────────┐                        │
│              │   PostgreSQL (主)   │                        │
│              │   Redis (缓存/排行)  │                        │
│              │   MinIO (对象存储)   │                        │
│              └─────────────────────┘                        │
└─────────────────────────────────────────────────────────────┘
```

---

## 二、客户端功能模块详细设计

### 2.1 页面路由定义

```dart
// Flutter 路由表
final Map<String, WidgetBuilder> routes = {
  '/': (ctx) => const HomePage(),           // 首页（默认Tab）
  '/stats': (ctx) => const StatsPage(),     // 统计Tab
  '/ranking': (ctx) => const RankingPage(), // 排名Tab
  '/settings': (ctx) => const SettingsPage(), // 设置Tab

  // 子页面
  '/record/detail': (ctx) => const RecordDetailPage(), // 记录详情
  '/stats/weekly': (ctx) => const WeeklyStatsPage(),   // 周统计详情
  '/stats/monthly': (ctx) => const MonthlyStatsPage(), // 月统计详情
  '/stats/yearly': (ctx) => const YearlyStatsPage(),    // 年统计详情
  '/ranking/global': (ctx) => const GlobalRankingPage(), // 全球榜
  '/ranking/city': (ctx) => const CityRankingPage(),     // 同城榜
  '/ranking/friends': (ctx) => const FriendsRankingPage(), // 好友榜
  '/settings/profile': (ctx) => const ProfilePage(),     // 个人档案
  '/settings/ai-config': (ctx) => const AIConfigPage(),  // AI配置
  '/settings/security': (ctx) => const SecurityPage(),   // 安全设置
  '/settings/data': (ctx) => const DataManagementPage(), // 数据管理
  '/settings/backup': (ctx) => const BackupPage(),       // 备份恢复
};
```

### 2.2 首页记录模块

#### 2.2.1 布局结构（精确到像素级参考）

| 层级 | 组件 | 样式规格 | 说明 |
|------|------|---------|------|
| L1 | 状态栏 | 系统原生，高度 44pt (iOS) / 24dp (Android) | 透明背景，文字黑色 |
| L2 | 日期问候区 | 上边距 16，左内边距 20 | |
| | - 日期文字 | 14sp，FontWeight.w400，Color(0xFF999999) | 「2026-05-10 星期六」 |
| | - 问候语 | 28sp，FontWeight.w700，Color(0xFF1A1A1A) | 「早安！所长 🚽」 |
| L3 | 核心数据卡片 | 外边距 20，圆角 24，高度 140 | 暖棕色渐变 |
| | - 背景 | LinearGradient: [Color(0xFFD4A574), Color(0xFFF5E6D3)] | 左上到右下 |
| | - 左侧图标 | 56×56，圆角 16，白色背景，透明度 0.3 | 🧻 图标，32sp |
| | - 主文案 | 22sp，白色，FontWeight.w600 | 「今日已出库 2 次 💩」 |
| | - 副文案 | 14sp，白色70%透明度 | 动态健康提示 |
| L3.5 | 出库趋势图 | 外边距 20，高度 220，圆角 16，背景白色 | fl_chart 三线折线图 |
| | - 大号线 | 棕色 Color(0xFF8D6E63)，线宽 2.5，圆点标记 | 每日大号次数趋势 |
| | - 小号线 | 绿色 Color(0xFF66BB6A)，线宽 2.5，圆点标记 | 每日小号次数趋势（v1.0.5 新增） |
| | - 总计线 | 蓝色 Color(0xFF42A5F5)，线宽 2.5，虚线+圆点 | 每日所有类型合计 |
| | - 图例 | 底部横向排列：棕色●大号 / 绿色●小号 / 蓝色●总计 | |
| L4 | 本周概览 | 外边距 20，双卡片横向排列，间距 12 | |
| | - 左卡片（总次数）| Expanded，高度 100，圆角 20，背景 Color(0xFFF7F7F7) | |
| | | 图标 ⭐ 16sp，标题「次叔」12sp灰色 | |
| | | 数字「328」32sp粗体，单位「次」14sp | 统计从开始到现在的历史记录总数 |
| | - 右卡片（状态）| 同左卡片 | |
| | | 图标 动态(🌟/✨/👌/🕐/⏰/🚨/🔄/😰/📋) 16sp | 基于今日+7天记录智能判定 |
| | | 标题「状态」12sp灰色 | |
| | | 状态文字 24sp粗体，严重度颜色 | 如「模范标兵」「肠道畅通」「运转正常」等 | |
| L5 | 肠道日报 | 外边距 20，圆角 16，背景 Color(0xFFE8F5E9) | 浅绿色 |
| | - 标题 | 14sp，Color(0xFF2E7D32)，FontWeight.w600 | 💡 肠道日报 |
| | - 正文 | 14sp，Color(0xFF1B5E20) | 动态提示 |
| L6 | 主操作按钮 | 底部居中，距底 100，宽度 200，高度 56 | |
| | - 样式 | 圆角 28，背景 Color(0xFFE3F2FD)，阴影 Elevation 4 | |
| | - 文案 | 16sp，Color(0xFF1565C0)，FontWeight.w600 | 🚽 又去啦？ |
| L7 | 底部导航 | 高度 80 + 安全区，背景白色 | 四栏 |
| | - Tab项 | 宽度均分，图标 24sp，文字 11sp | |
| | - 选中态 | 图标颜色 Color(0xFF795548)，文字同色 | 棕色主题 |
| | - 未选中 | 图标颜色 Color(0xFFBDBDBD) | |

#### 2.2.2 动态问候语文案表

| 时间段 | 文案模板 | 触发条件 |
|--------|---------|---------|
| 05:00-08:59 | 「早安！{昵称} 🌅」 | 默认 |
| 09:00-11:59 | 「上午好！{昵称} ☕️」 | 默认 |
| 12:00-13:59 | 「午安！{昵称} 🍱」 | 默认 |
| 14:00-17:59 | 「下午好！{昵称} 🌤️」 | 默认 |
| 18:00-20:59 | 「晚上好！{昵称} 🌆」 | 默认 |
| 21:00-23:59 | 「夜深了！{昵称} 🌙」 | 默认 |
| 00:00-04:59 | 「凌晨好！{昵称} 🌃」 | 默认 |
| 任意 | 「{昵称}，该出库了！⏰」 | 距离上次大号 > 24h |
| 任意 | 「运转良好，继续保持！💪」 | 今日已大号 1 次且规律 |
| 任意 | 「今天货量有点大！📦」 | 今日大号 >= 3 次 |

#### 2.2.3 核心数据卡片副文案规则

```dart
String getSubTitle(int bigCount, int smallCount, int lastBigHoursAgo) {
  if (bigCount == 0 && smallCount == 0) {
    return "今天还没出库哦，记得多喝水～";
  } else if (bigCount == 0) {
    return "小号已记录，大号别憋着哦";
  } else if (bigCount == 1 && lastBigHoursAgo < 12) {
    return "作息很规律，继续保持～";
  } else if (bigCount >= 3) {
    return "今天出库频繁，注意饮食卫生";
  } else if (lastBigHoursAgo > 48) {
    return "已经2天没出库了，建议多吃膳食纤维";
  } else {
    return "保持好心情，肠道更健康～";
  }
}
```

#### 2.2.4 记录流程状态机

```
[Idle] --点击"又去啦？"--> [ActionSheet显示]
[ActionSheet显示] --选择"小号"--> [QuickDetail可选]
[ActionSheet显示] --选择"大号"--> [QuickDetail可选]
[ActionSheet显示] --选择"自定义"--> [FullDetail必填]
[ActionSheet显示] --选择"取消"--> [Idle]
[QuickDetail可选] --点击"完成"--> [本地写入]
[QuickDetail可选] --点击"详细记录"--> [FullDetail必填]
[FullDetail必填] --点击"保存"--> [本地写入]
[本地写入] --成功--> [积分计算] --> [异步上报] --> [Idle]
```

#### 2.2.5 快速详情面板（QuickDetail）字段

```dart
class QuickDetailSheet extends StatelessWidget {
  final RecordType type; // small / big

  // 可选字段（默认折叠，点击展开）
  final List<FormField> optionalFields = [
    FormField(
      label: "时长",
      type: FieldType.radio,
      options: ["<1分钟", "1-3分钟", "3-8分钟", "8-15分钟", ">15分钟"],
      defaultValue: "3-8分钟",
    ),
    FormField(
      label: "顺畅度",
      type: FieldType.slider,
      min: 1, max: 5,
      labels: ["很费劲", "略费劲", "正常", "通畅", "一泻千里"],
    ),
    FormField(
      label: "工作时间段",
      type: FieldType.info,
      description: "根据个人档案年龄自动判定，22岁以下08-18点，23岁以上09-18点。时间范围内的大号自动计为带薪，无需手动勾选。",
    ),
  ];
}
```

#### 2.2.6 完整记录模型（本地 SQLite）

```sql
-- 主记录表
CREATE TABLE toilet_records (
    id TEXT PRIMARY KEY,              -- UUID v4
    type INTEGER NOT NULL,              -- 0:小号(small) 1:大号(big)
    timestamp INTEGER NOT NULL,       -- 毫秒级时间戳
    duration INTEGER,                 -- 时长（秒），null表示未记录
    bristol_type INTEGER,             -- 1-7，仅大号时有效
    color INTEGER,                    -- 0:brown 1:black 2:red 3:other
    smoothness INTEGER,               -- 1-5，顺畅度
    is_work_hours INTEGER DEFAULT 0,  -- 0/1
    is_paid_poop INTEGER DEFAULT 0,   -- 0/1
    location_hash TEXT,               -- 地点哈希（模糊）
    note TEXT,                        -- 备注，最大200字
    mood TEXT,                        -- 心情emoji
    created_at INTEGER DEFAULT (strftime('%s','now')*1000),
    updated_at INTEGER DEFAULT (strftime('%s','now')*1000),
    is_synced INTEGER DEFAULT 0,      -- 是否已上报服务端
    sync_uuid TEXT                    -- 上报时使用的UUID
);

-- 索引
CREATE INDEX idx_records_timestamp ON toilet_records(timestamp);
CREATE INDEX idx_records_type ON toilet_records(type);
CREATE INDEX idx_records_date ON toilet_records(date(timestamp/1000, 'unixepoch'));
CREATE INDEX idx_records_sync ON toilet_records(is_synced);

-- 触发器：自动更新 updated_at
CREATE TRIGGER update_records_timestamp 
AFTER UPDATE ON toilet_records
BEGIN
    UPDATE toilet_records SET updated_at = strftime('%s','now')*1000 WHERE id = NEW.id;
END;
```

---

## 三、数据统计模块

### 3.1 统计维度矩阵

| 维度 | 周统计 | 月统计 | 年统计 |
|------|--------|--------|--------|
| 次数趋势 | 7日柱状图 | 💩日历标记 | 12月折线图 |
| 时段分布 | 7×24热力图 | 月度时段饼图 | 季度时段对比 |
| 类型占比 | 周饼图 | 月饼图 | 年饼图 |
| 布里斯托分布 | 周饼图 | 月饼图 | 年饼图 |
| 平均时长趋势 | 7日折线图 | 月折线图 | 年折线图 |
| 规律指数 | 周评分 | 月评分 | 年评分 |
| 带薪收益 | 周累计 | 月累计 | 年累计 |
| 健康等级 | 周评级 | 月评级 | 年评级 |

### 3.2 周统计页面（WeeklyStatsPage）

#### 3.2.1 页面结构

```dart
class WeeklyStatsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("本周肠道周报")),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. 顶部积分环形图
            WeekScoreRing(),

            // 2. 趋势混合图（柱状+折线）
            WeekTrendChart(),

            // 3. 时段热力图
            WeekHeatMap(),

            // 4. 关键指标横向滑动卡片
            SizedBox(
              height: 120,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  StatCard(title: "总次数", value: "12", unit: "次", delta: "+20%"),
                  StatCard(title: "大号占比", value: "67", unit: "%"),
                  StatCard(title: "平均时长", value: "6.5", unit: "分钟", delta: "-1.2"),
                  StatCard(title: "规律指数", value: "85", unit: "分"),
                  StatCard(title: "带薪收益", value: "3.2", unit: "小时", subValue: "≈¥160"),
                ],
              ),
            ),

            // 5. 布里斯托分布
            BristolDistributionChart(),

            // 6. 健康建议卡片
            HealthAdviceCard(),
          ],
        ),
      ),
    );
  }
}
```

#### 3.2.2 规律指数算法（完整实现）

```dart
/// 计算本周规律指数（0-100）
/// 基于每日第一次大号的时间标准差
class RegularityCalculator {
  static int calculate(List<ToiletRecord> records) {
    // 1. 按天分组，取每天第一次大号的时间（分钟数 0-1440）
    Map<int, int> firstBigPerDay = {};

    for (var record in records) {
      if (record.type == RecordType.big) {
        DateTime dt = DateTime.fromMillisecondsSinceEpoch(record.timestamp);
        int dayKey = dt.year * 10000 + dt.month * 100 + dt.day;
        int minutes = dt.hour * 60 + dt.minute;

        if (!firstBigPerDay.containsKey(dayKey) || 
            minutes < firstBigPerDay[dayKey]!) {
          firstBigPerDay[dayKey] = minutes;
        }
      }
    }

    List<int> times = firstBigPerDay.values.toList();

    // 数据不足保护
    if (times.length < 3) return 50;
    if (times.length < 5) return 60;

    // 2. 处理跨午夜情况（如有人习惯 23:50 和 00:10，实际只差20分钟）
    times = _unwrapCircularTimes(times);

    // 3. 计算标准差
    double mean = times.reduce((a, b) => a + b) / times.length;
    double variance = times.map((t) => pow(t - mean, 2))
                           .reduce((a, b) => a + b) / times.length;
    double std = sqrt(variance);

    // 4. 映射到 0-100 分
    // 标准差 < 30分钟 = 100分（极其规律）
    // 标准差 > 120分钟 = 0分（完全随机）
    if (std <= 30) return 100;
    if (std >= 120) return 0;

    double score = 100 - ((std - 30) / 90) * 100;
    return score.round().clamp(0, 100);
  }

  /// 处理跨午夜的时间点，使其线性化
  static List<int> _unwrapCircularTimes(List<int> times) {
    if (times.isEmpty) return times;

    // 找到最密集的时间簇中心
    int bestOffset = 0;
    double minVariance = double.infinity;

    for (int offset = 0; offset < 1440; offset += 30) {
      List<int> shifted = times.map((t) => (t - offset + 1440) % 1440).toList();
      // 将大于720的视为跨午夜，减去1440
      shifted = shifted.map((t) => t > 720 ? t - 1440 : t).toList();

      double mean = shifted.reduce((a, b) => a + b) / shifted.length;
      double variance = shifted.map((t) => pow(t - mean, 2))
                               .reduce((a, b) => a + b) / shifted.length;

      if (variance < minVariance) {
        minVariance = variance;
        bestOffset = offset;
      }
    }

    // 使用最优偏移重新计算
    List<int> result = times.map((t) => (t - bestOffset + 1440) % 1440).toList();
    return result.map((t) => t > 720 ? t - 1440 : t).toList();
  }
}
```

#### 3.2.3 带薪收益计算

```dart
class PaidPoopCalculator {
  /// 计算带薪拉屎的「收益」
  /// 假设：月薪 10000，月工作 22 天，每天 8 小时
  /// 时薪 = 10000 / 22 / 8 ≈ 56.8 元
  static Map<String, dynamic> calculate(
    List<ToiletRecord> records, 
    {double monthlySalary = 10000}
  ) {
    double hourlyRate = monthlySalary / 22 / 8;

    int totalSeconds = records
        .where((r) => r.isPaidPoop == true)
        .fold(0, (sum, r) => sum + (r.duration ?? 0));

    double totalHours = totalSeconds / 3600;
    double earnings = totalHours * hourlyRate;

    return {
      "total_hours": totalHours.toStringAsFixed(1),
      "earnings": earnings.toStringAsFixed(2),
      "hourly_rate": hourlyRate.toStringAsFixed(2),
      "record_count": records.where((r) => r.isPaidPoop == true).length,
    };
  }
}
```

### 3.3 月统计页面（MonthlyStatsPage）

#### 3.3.1 日历标记组件（💩 Emoji 模式，v1.0.5 更新）

```dart
class MonthlyCalendarView extends StatelessWidget {
  final List<ToiletRecord> records;
  final int year;
  final int month;

  @override
  Widget build(BuildContext context) {
    int daysInMonth = DateTime(year, month + 1, 0).day;

    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1,
      ),
      itemCount: daysInMonth,
      itemBuilder: (context, index) {
        int day = index + 1;
        List<ToiletRecord> dayRecords = records.where((r) {
          DateTime dt = DateTime.fromMillisecondsSinceEpoch(r.timestamp);
          return dt.day == day && dt.month == month && dt.year == year;
        }).toList();

        int count = dayRecords.length;
        if (count > 0) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('💩', style: TextStyle(fontSize: 15)),       // 出库日用 💩 标记
              Text('$day', style: TextStyle(fontSize: 9, color: Color(0xFF795548), fontWeight: FontWeight.w600)),
            ],
          );
        } else {
          return Center(
            child: Text('$day', style: TextStyle(fontSize: 11, color: Color(0xFF999999))),
          );
        }
      },
    );
  }
}
```


#### 3.3.2 健康等级评定

```dart
class HealthGradeCalculator {
  static HealthGrade calculateMonthly(List<ToiletRecord> records) {
    // 1. 频率评分（每日至少1次大号得满分）
    int daysWithBig = _countDaysWithType(records, RecordType.big);
    int totalDays = _daysInMonth(records);
    double frequencyScore = (daysWithBig / totalDays) * 30; // 权重30%

    // 2. 规律评分（基于规律指数）
    double regularityScore = RegularityCalculator.calculate(records) * 0.25; // 权重25%

    // 3. 形态评分（布里斯托3-4型占比）
    List<ToiletRecord> bigRecords = records.where((r) => r.type == RecordType.big).toList();
    int healthyBristol = bigRecords.where((r) => r.bristolType == 3 || r.bristolType == 4).length;
    double bristolScore = bigRecords.isEmpty ? 0 : 
        (healthyBristol / bigRecords.length) * 25; // 权重25%

    // 4. 时长评分（3-8分钟占比）
    int goodDuration = bigRecords.where((r) {
      int min = (r.duration ?? 0) ~/ 60;
      return min >= 3 && min <= 8;
    }).length;
    double durationScore = bigRecords.isEmpty ? 0 :
        (goodDuration / bigRecords.length) * 20; // 权重20%

    double total = frequencyScore + regularityScore + bristolScore + durationScore;

    // 评级
    String grade;
    String title;
    if (total >= 90) { grade = "A"; title = "肠道模范生"; }
    else if (total >= 75) { grade = "B"; title = "运转良好"; }
    else if (total >= 60) { grade = "C"; title = "偶有波动"; }
    else { grade = "D"; title = "需要关注"; }

    return HealthGrade(
      grade: grade,
      title: title,
      score: total.round(),
      breakdown: {
        "frequency": frequencyScore.round(),
        "regularity": regularityScore.round(),
        "bristol": bristolScore.round(),
        "duration": durationScore.round(),
      },
    );
  }
}
```

#### 3.3.3 首页健康状态判定（v1.0.5 新增）

```dart
/// 首页 ❤️ 动态健康状态
/// 基于今日记录 + 最近 7 天记录，通过科学方法综合判定
class HomeHealthStatus {
  final String icon;    // 状态图标（🌟/✨/👌/🕐/⏰/🚨/🔄/😰/📋）
  final String label;   // 状态名称
  final String detail;  // 详细描述
  final int severity;   // 严重程度 0=正常 1=轻微 2=中度 3=严重

  const HomeHealthStatus({
    required this.icon,
    required this.label,
    required this.detail,
    required this.severity,
  });
}

class HomeHealthStatusCalculator {
  static HomeHealthStatus calculate({
    required List<ToiletRecord> todayRecords,
    required List<ToiletRecord> weekRecords,
  }) {
    int todayBigCount = todayRecords.where((r) => r.type == RecordType.big).length;
    
    // 1. 计算最近一次大号距今小时数
    DateTime? lastBigTime;
    for (var r in todayRecords) {
      if (r.type == RecordType.big) {
        DateTime rt = DateTime.fromMillisecondsSinceEpoch(r.timestamp);
        if (lastBigTime == null || rt.isAfter(lastBigTime)) lastBigTime = rt;
      }
    }
    // 若今日无大号，回查最近 7 天
    if (lastBigTime == null) {
      for (var r in weekRecords) {
        if (r.type == RecordType.big) {
          DateTime rt = DateTime.fromMillisecondsSinceEpoch(r.timestamp);
          if (lastBigTime == null || rt.isAfter(lastBigTime)) lastBigTime = rt;
        }
      }
    }
    
    int lastBigHours = lastBigTime != null 
        ? DateTime.now().difference(lastBigTime).inHours 
        : 999;

    // 2. 计算 7 天规律指数
    int regularityScore = RegularityCalculator.calculate(weekRecords);

    // 3. 计算布里斯托质量（3-4 型占比）
    List<ToiletRecord> bigWeekRecords = weekRecords.where((r) => r.type == RecordType.big).toList();
    int healthyBristol = bigWeekRecords.where((r) => r.bristolType == 3 || r.bristolType == 4).length;
    double bristolQuality = bigWeekRecords.isEmpty ? 1.0 : healthyBristol / bigWeekRecords.length;

    // 4. 计算时长质量（3-8 分钟占比）
    int goodDuration = bigWeekRecords.where((r) {
      int min = (r.duration ?? 0) ~/ 60;
      return min >= 3 && min <= 8;
    }).length;
    double durationQuality = bigWeekRecords.isEmpty ? 1.0 : goodDuration / bigWeekRecords.length;

    // 5. 判定状态
    if (weekRecords.isEmpty) {
      return const HomeHealthStatus(icon: '📋', label: '数据收集中', detail: '记录几天后再来看看', severity: 0);
    }
    if (todayBigCount >= 4) {
      return const HomeHealthStatus(icon: '😰', label: '频率异常', detail: '今天已超过4次大号', severity: 3);
    }
    if (todayBigCount >= 3) {
      return const HomeHealthStatus(icon: '🔄', label: '频率偏高', detail: '注意饮食，避免刺激食物', severity: 2);
    }
    if (lastBigHours >= 48) {
      return const HomeHealthStatus(icon: '🚨', label: '便秘警报', detail: '已超48小时未出库', severity: 3);
    }
    if (lastBigHours >= 24) {
      return HomeHealthStatus(icon: '⏰', label: '稍需留意', detail: '已${lastBigHours ~/ 24 + 1}天未出库', severity: 2);
    }
    if (todayBigCount == 0) {
      return const HomeHealthStatus(icon: '🕐', label: '等待出库', detail: '今天还没大号哦', severity: 1);
    }
    if (regularityScore >= 85 && bristolQuality >= 0.7 && durationQuality >= 0.7) {
      return const HomeHealthStatus(icon: '🌟', label: '模范标兵', detail: '规律健康，堪称典范！', severity: 0);
    }
    if (regularityScore >= 65 && bristolQuality >= 0.5) {
      return const HomeHealthStatus(icon: '✨', label: '肠道畅通', detail: '整体状态不错', severity: 0);
    }
    return const HomeHealthStatus(icon: '👌', label: '运转正常', detail: '一切正常', severity: 0);
  }
}
```

**严重度颜色映射**：
| 严重度 | 颜色 | 说明 |
|--------|------|------|
| 0 正常 | `Color(0xFF4CAF50)` 绿色 | 模范标兵 / 肠道畅通 / 运转正常 / 数据收集中 |
| 1 轻微 | `Color(0xFFFF9800)` 橙色 | 等待出库 |
| 2 中度 | `Color(0xFFE65100)` 深橙 | 稍需留意 / 频率偏高 |
| 3 严重 | `Color(0xFFF44336)` 红色 | 便秘警报 / 频率异常 |

### 3.4 年统计页面（YearlyStatsPage）

#### 3.4.1 年度关键词生成算法

```dart
class YearlyKeywordGenerator {
  static List<String> generate(List<ToiletRecord> records) {
    List<String> keywords = [];

    // 1. 晨便达人
    int morningCount = records.where((r) {
      if (r.type != RecordType.big) return false;
      DateTime dt = DateTime.fromMillisecondsSinceEpoch(r.timestamp);
      return dt.hour >= 6 && dt.hour <= 9;
    }).length;
    if (morningCount > records.length * 0.6) keywords.add("晨便守护者");

    // 2. 带薪冠军
    int paidCount = records.where((r) => r.isPaidPoop == true).length;
    if (paidCount > 50) keywords.add("带薪拉屎王");

    // 3. 速战速决
    int fastCount = records.where((r) {
      return r.type == RecordType.big && (r.duration ?? 0) < 180;
    }).length;
    if (fastCount > records.length * 0.5) keywords.add("闪电侠");

    // 4. 周末战士
    int weekendCount = records.where((r) {
      DateTime dt = DateTime.fromMillisecondsSinceEpoch(r.timestamp);
      return dt.weekday == 6 || dt.weekday == 7;
    }).length;
    int weekdayCount = records.length - weekendCount;
    if (weekendCount > weekdayCount * 1.5) keywords.add("周末肠道活跃分子");

    // 5. 规律大师
    int regularMonths = 0;
    for (int m = 1; m <= 12; m++) {
      var monthRecords = records.where((r) {
        DateTime dt = DateTime.fromMillisecondsSinceEpoch(r.timestamp);
        return dt.month == m;
      }).toList();
      if (RegularityCalculator.calculate(monthRecords) > 80) regularMonths++;
    }
    if (regularMonths >= 8) keywords.add("规律大师");

    return keywords.isEmpty ? ["肠道探索者"] : keywords;
  }
}
```

---

## 四、智能分析模块

### 4.1 架构设计

```
┌─────────────────────────────────────────┐
│           客户端 (Flutter)               │
│  ┌─────────────────────────────────────┐│
│  │         AI 分析控制器               ││
│  │  - 数据聚合（本地 SQLite 查询）      ││
│  │  - Prompt 组装（内置模板）           ││
│  │  - 请求管理（Dio HTTP 客户端）       ││
│  │  - 结果缓存（本地存储，7天有效期）    ││
│  └─────────────────────────────────────┘│
│              │                          │
│  ┌───────────▼───────────┐             │
│  │    安全存储模块        │             │
│  │  - Keychain (iOS)     │             │
│  │  - Keystore (Android) │             │
│  │  - 加密：AES-256-GCM  │             │
│  └───────────┬───────────┘             │
│              │ 用户配置的 API Key       │
└──────────────┼──────────────────────────┘
               │ HTTPS 直连
               ▼
┌─────────────────────────────────────────┐
│         第三方大模型厂商 API             │
│  - DeepSeek API                        │
│  - OpenAI API                          │
│  - Anthropic Claude API                │
│  - 通义千问 API                        │
│  - 自定义 Base URL（本地模型）          │
└─────────────────────────────────────────┘
```

### 4.2 用户配置界面详细设计

```dart
class AIConfigPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("AI 肠道顾问")),
      body: ListView(
        children: [
          // 1. 厂商选择
          SectionTitle("服务商"),
          RadioGroup(
            options: [
              AIProvider(name: "DeepSeek", icon: "🐋", baseUrl: "https://api.deepseek.com"),
              AIProvider(name: "OpenAI", icon: "🤖", baseUrl: "https://api.openai.com"),
              AIProvider(name: "Claude", icon: "🧠", baseUrl: "https://api.anthropic.com"),
              AIProvider(name: "通义千问", icon: "🌟", baseUrl: "https://dashscope.aliyuncs.com"),
              AIProvider(name: "自定义", icon: "⚙️", baseUrl: ""),
            ],
            selected: provider,
            onChanged: (p) => setProvider(p),
          ),

          // 2. API Key 输入
          SectionTitle("API Key"),
          TextField(
            controller: apiKeyController,
            obscureText: true,
            decoration: InputDecoration(
              hintText: "sk-xxxxxxxx...",
              helperText: "您的 API Key 仅存储在本地，不会上传到我们的服务器",
              suffixIcon: IconButton(
                icon: Icon(Icons.visibility),
                onPressed: () => toggleVisibility(),
              ),
            ),
          ),

          // 3. 自定义 Base URL（仅自定义厂商显示）
          if (provider == AIProvider.custom)
            TextField(
              controller: baseUrlController,
              decoration: InputDecoration(
                labelText: "Base URL",
                hintText: "https://your-api.com/v1",
              ),
            ),

          // 4. 模型选择
          SectionTitle("模型"),
          DropdownButtonFormField(
            value: selectedModel,
            items: provider.models.map((m) => 
              DropdownMenuItem(value: m, child: Text(m))
            ).toList(),
            onChanged: (m) => setModel(m),
          ),

          // 5. 高级参数
          SectionTitle("高级参数"),
          ListTile(
            title: Text("Temperature"),
            subtitle: Text("${temperature.toStringAsFixed(1)}"),
            trailing: Slider(
              value: temperature,
              min: 0,
              max: 1,
              divisions: 10,
              onChanged: (v) => setTemperature(v),
            ),
          ),

          ListTile(
            title: Text("分析频率"),
            trailing: DropdownButton(
              value: analysisFrequency,
              items: [
                DropdownMenuItem(value: "manual", child: Text("手动触发")),
                DropdownMenuItem(value: "daily", child: Text("每日晚9点")),
                DropdownMenuItem(value: "per_record", child: Text("每次记录后")),
              ],
              onChanged: (f) => setFrequency(f),
            ),
          ),

          // 6. 自定义 Prompt
          ExpansionTile(
            title: Text("自定义 Prompt（高级）"),
            children: [
              TextField(
                controller: promptController,
                maxLines: 10,
                decoration: InputDecoration(
                  hintText: "输入自定义 System Prompt...",
                  border: OutlineInputBorder(),
                ),
              ),
              TextButton(
                onPressed: () => resetPrompt(),
                child: Text("恢复默认"),
              ),
            ],
          ),

          // 7. 测试连接
          ElevatedButton(
            onPressed: () => testConnection(),
            child: Text("测试连接"),
          ),

          // 8. 隐私声明
          Card(
            color: Colors.amber[50],
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                "⚠️ 安全提示：您的 API Key 使用设备级加密存储（iOS Keychain / Android Keystore）。"
                "分析请求直接从您的设备发送至大模型厂商，「拉了么」服务器不会触碰您的数据。",
                style: TextStyle(fontSize: 12, color: Colors.amber[900]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

### 4.3 数据脱敏聚合逻辑

```dart
class AIDataAggregator {
  /// 聚合近7天数据，生成脱敏摘要
  static Map<String, dynamic> aggregateWeekly(List<ToiletRecord> records) {
    DateTime now = DateTime.now();
    DateTime weekAgo = now.subtract(Duration(days: 7));

    var weekRecords = records.where((r) {
      DateTime dt = DateTime.fromMillisecondsSinceEpoch(r.timestamp);
      return dt.isAfter(weekAgo);
    }).toList();

    int totalCount = weekRecords.length;
    int bigCount = weekRecords.where((r) => r.type == RecordType.big).length;
    int smallCount = totalCount - bigCount;

    // 计算每日大号次数分布（不暴露具体时间）
    Map<String, int> dailyBigCount = {};
    for (int i = 0; i < 7; i++) {
      DateTime day = now.subtract(Duration(days: i));
      String dayKey = "${day.month}月${day.day}日";
      int count = weekRecords.where((r) {
        DateTime dt = DateTime.fromMillisecondsSinceEpoch(r.timestamp);
        return dt.day == day.day && dt.month == day.month && r.type == RecordType.big;
      }).length;
      dailyBigCount[dayKey] = count;
    }

    // 布里斯托分布
    Map<int, int> bristolDist = {};
    for (int i = 1; i <= 7; i++) {
      bristolDist[i] = weekRecords.where((r) => r.bristolType == i).length;
    }

    // 时段分布（仅统计早中晚，不精确到小时）
    Map<String, int> periodDist = {
      "早晨(6-9点)": 0,
      "上午(9-12点)": 0,
      "下午(12-18点)": 0,
      "晚上(18-24点)": 0,
      "凌晨(0-6点)": 0,
    };
    for (var r in weekRecords) {
      DateTime dt = DateTime.fromMillisecondsSinceEpoch(r.timestamp);
      int hour = dt.hour;
      if (hour >= 6 && hour < 9) periodDist["早晨(6-9点)"] = periodDist["早晨(6-9点)"]! + 1;
      else if (hour >= 9 && hour < 12) periodDist["上午(9-12点)"] = periodDist["上午(9-12点)"]! + 1;
      else if (hour >= 12 && hour < 18) periodDist["下午(12-18点)"] = periodDist["下午(12-18点)"]! + 1;
      else if (hour >= 18) periodDist["晚上(18-24点)"] = periodDist["晚上(18-24点)"]! + 1;
      else periodDist["凌晨(0-6点)"] = periodDist["凌晨(0-6点)"]! + 1;
    }

    // 平均时长（分类型）
    double avgBigDuration = _avgDuration(
      weekRecords.where((r) => r.type == RecordType.big).toList()
    );

    // 规律指数
    int regularityScore = RegularityCalculator.calculate(weekRecords);

    // 用户档案（仅上传年龄范围和性别，不上传精确三围）
    var profile = await LocalStorage.getProfile();

    return {
      "period": "过去7天",
      "total_count": totalCount,
      "big_count": bigCount,
      "small_count": smallCount,
      "avg_big_per_day": (bigCount / 7).toStringAsFixed(1),
      "avg_big_duration_minutes": avgBigDuration.toStringAsFixed(1),
      "bristol_distribution": bristolDist,
      "period_distribution": periodDist,
      "regularity_score": regularityScore,
      "daily_big_count": dailyBigCount,
      "user_profile": {
        "age_range": profile.ageRange, // "26-35"
        "gender": profile.gender,      // "male"
        "bmi_category": profile.bmiCategory, // "normal"
      },
      // 明确不暴露：精确时间戳、地点、三围原始数值、备注内容
    };
  }
}
```

### 4.4 完整 Prompt 模板（内置默认）

```markdown
# 角色设定
你是一位专业的消化健康顾问，擅长用轻松幽默但专业准确的语言与用户交流。
你的建议基于循证医学，但表达方式要像一位关心朋友健康的老友。

# 用户数据摘要（过去7天）
{aggregated_data}

# 输出格式（严格JSON）
请直接输出JSON，不要包含任何其他文字：

{
  "health_score": <0-100的整数>,
  "status": <状态描述，如"运转良好""略有波动""需要关注">,
  "summary": <一句话幽默总结，20字以内>,
  "observations": [
    <观察点1：基于数据的客观发现>,
    <观察点2：可以提及规律度、时段偏好等>
  ],
  "suggestions": [
    <具体可操作的健康建议1>,
    <具体可操作的健康建议2>,
    <饮食或生活习惯建议3>
  ],
  "warnings": [
    <如有异常必须提醒就医。若数据正常，此项为空数组[]>
  ],
  "humor_note": <一句轻松的调侃，让用户会心一笑>,
  "benchmark": <与同龄人群的对比描述，如"您的规律指数超过78%的同龄用户">,
  "focus_next_week": <下周建议关注的1个重点>
}

# 重要规则
1. 若检测到以下情况，必须在 warnings 中强烈建议就医：
   - 血便（color: red）或黑便（color: black）
   - 连续3天以上腹泻（bristol 5-7型占主导）
   - 连续5天以上无大号
   - 严重便秘伴随腹痛（用户备注提及）

2. 不要透露用户的具体日期、时间、地点。

3. 语气要温暖、不制造焦虑。

4. 建议要具体可操作，不要泛泛而谈"多喝水"。
```

### 4.5 客户端 AI 请求服务

```dart
class AIService {
  final Dio _dio = Dio();

  Future<AIAnalysisResult> analyze() async {
    // 1. 读取配置
    var config = await SecureStorage.getAIConfig();
    if (config.apiKey.isEmpty) throw AIException("请先配置 API Key");

    // 2. 聚合数据
    var records = await LocalDB.getRecentRecords(days: 7);
    var aggregated = AIDataAggregator.aggregateWeekly(records);

    // 3. 组装 Prompt
    String prompt = config.customPrompt.isNotEmpty 
        ? config.customPrompt 
        : defaultPromptTemplate;
    prompt = prompt.replaceAll("{aggregated_data}", jsonEncode(aggregated));

    // 4. 发送请求
    try {
      var response = await _dio.post(
        "${config.baseUrl}/chat/completions",
        options: Options(
          headers: {
            "Authorization": "Bearer ${config.apiKey}",
            "Content-Type": "application/json",
          },
          sendTimeout: Duration(seconds: 30),
          receiveTimeout: Duration(seconds: 60),
        ),
        data: {
          "model": config.model,
          "messages": [
            {"role": "system", "content": "You are a health advisor. Output valid JSON only."},
            {"role": "user", "content": prompt},
          ],
          "temperature": config.temperature,
          "max_tokens": 1500,
          "response_format": {"type": "json_object"}, // OpenAI/DeepSeek 支持
        },
      );

      // 5. 解析结果
      String content = response.data["choices"][0]["message"]["content"];
      Map<String, dynamic> result = jsonDecode(content);

      // 6. 本地缓存
      await LocalDB.saveAIReport(
        reportId: const Uuid().v4(),
        result: result,
        validUntil: DateTime.now().add(Duration(days: 7)),
      );

      return AIAnalysisResult.fromJson(result);

    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw AIException("API Key 无效，请检查配置");
      } else if (e.type == DioExceptionType.connectionTimeout) {
        throw AIException("连接超时，请检查网络或 Base URL");
      }
      throw AIException("分析失败: ${e.message}");
    }
  }
}
```

### 4.6 异常预警自动触发机制

```dart
class AnomalyDetector {
  static Future<void> checkAndAlert() async {
    var records = await LocalDB.getAllRecords();

    // 1. 连续便秘检测（5天无大号）
    int daysSinceLastBig = _daysSinceLastBig(records);
    if (daysSinceLastBig >= 5) {
      await NotificationService.show(
        title: "⚠️ 肠道预警",
        body: "已经 $daysSinceLastBig 天没有大号了，建议多吃膳食纤维，必要时就医。",
        payload: "anomaly:constipation",
      );
    }

    // 2. 持续腹泻检测（连续3天，每天大号>=3次且bristol 5-7）
    if (_hasPersistentDiarrhea(records)) {
      await NotificationService.show(
        title: "⚠️ 腹泻预警",
        body: "检测到持续腹泻症状，请注意补水，如超过3天请立即就医。",
        payload: "anomaly:diarrhea",
      );
    }

    // 3. 血便/黑便检测
    var bloodRecords = records.where((r) => r.color == ColorType.red || r.color == ColorType.black).toList();
    if (bloodRecords.isNotEmpty) {
      await NotificationService.show(
        title: "🚨 重要健康提醒",
        body: "检测到异常便便颜色记录，建议尽快就医检查。",
        payload: "anomaly:blood",
      );
      // 强制建议触发 AI 分析
      await showForceAnalysisDialog();
    }

    // 4. 久坐提醒（与如厕无关，但相关）
    if (await _isSedentaryForHours(2)) {
      await NotificationService.show(
        title: "🚶 该动动了",
        body: "已经坐了2小时了，起来走动有助于肠道蠕动～",
        payload: "reminder:move",
      );
    }
  }
}
```

### 4.7 超时提醒弹窗机制（v1.0.7 新增）

在应用启动后和每次记录保存后，自动检测用户小号/大号的最近记录时间，超出阈值时弹出门内提醒对话框。

```dart
class ReminderCheckResult {
  final bool showSmallReminder;
  final bool showBigReminder;
  final int hoursSinceSmall;
  final int daysSinceBig;
  final DateTime? lastSmallTime;
  final DateTime? lastBigTime;

  bool get hasAnyReminder => showSmallReminder || showBigReminder;
}

class ReminderService {
  /// 查询最近一次指定类型的记录时间
  static Future<DateTime?> _getLastRecordTime(RecordType type) async {
    final records = await DatabaseService.getRecords(limit: 1, type: type);
    if (records.isEmpty) return null;
    return DateTime.fromMillisecondsSinceEpoch(records.first.timestamp);
  }

  /// 检查是否需要弹出提醒
  static Future<ReminderCheckResult> checkReminders() async {
    final settings = await AppSettings.load();
    final lastSmall = await _getLastRecordTime(RecordType.small);
    final lastBig = await _getLastRecordTime(RecordType.big);
    final now = DateTime.now();

    // 小号检测：距上次小号超过配置的小时数
    bool showSmall = settings.smallReminderEnabled &&
        lastSmall != null &&
        now.difference(lastSmall).inHours >= settings.smallReminderHours;

    // 大号检测：距上次大号超过配置的天数
    bool showBig = settings.bigReminderEnabled &&
        lastBig != null &&
        now.difference(lastBig).inDays >= settings.bigReminderDays;

    return ReminderCheckResult(...);
  }
}
```

**触发时机：**
| 时机 | 说明 |
|------|------|
| 应用启动 | `HomePage._initServices()` → `_checkAndShowReminders()` |
| 快速记录后 | `_quickRecord()` 保存完成后调用 |
| 详细记录后 | `_navigateToDetail()` → `_saveRecordFromDetail()` → 刷新完成后调用 |

**弹窗 UI（ReminderDialog）：**

```dart
class ReminderDialog {
  static Future<void> show(BuildContext context, ReminderCheckResult result) {
    // AlertDialog 包含:
    // - ⏰ 标题图标 + '健康提醒' 标题
    // - 💧 小号提醒卡片（蓝色调，显示已过 X 小时）
    // - 💩 大号提醒卡片（棕色调，显示已过 X 天）
    // - [知道了] 按钮 → 关闭弹窗
    // - [去记录] 按钮 → 关闭弹窗 + 跳转记录详情页
  }
}
```

**设置页配置：**

设置页新增两个 SwitchListTile（小号提醒/大号提醒），每个下方可点击配置阈值：
- 小号阈值选项：2 / 3 / 4 / 5 / 6 小时（默认 4 小时）
- 大号阈值选项：1 / 2 / 3 / 4 / 5 天（默认 2 天）

**实现文件：** `reminder_service.dart` + `reminder_dialog.dart` + `settings_page.dart` + `home_page.dart`

---

## 五、排名模块

### 5.1 积分体系完整算法

#### 5.1.1 乘数定义表

| 乘数 | 代码 | 计算逻辑 | 范围 | 说明 |
|------|------|---------|------|------|
| 时间规律系数 | R | 基于当日第一次大号时间与个人历史平均时间的偏差 | 0.8 ~ 1.5 | 越规律越高 |
| 健康系数 | H | 布里斯托分型评分 | 0.5 ~ 1.2 | 鼓励健康便便 |
| 时长系数 | T | 时长合理性评分 | 0.7 ~ 1.1 | 鼓励速战速决 |
| 带薪系数 | P | 是否在工作时间 | 1.0 ~ 1.2 | 趣味加成 |
| 连击系数 | S | 连续规律天数 | 1.0 ~ 2.0 | 鼓励每日规律 |
| 晨便系数 | M | 是否在早晨6-9点 | 1.0 ~ 1.15 | 符合生理节律 |

#### 5.1.2 各乘数详细计算

```dart
class ScoreCalculator {
  /// 主计算函数
  static double calculate(ToiletRecord record, List<ToiletRecord> history) {
    double base = record.type == RecordType.big ? 5.0 : 1.0;

    double r = _calculateRegularity(record, history);
    double h = _calculateHealth(record);
    double t = _calculateTime(record);
    double p = _calculatePaid(record);
    double s = _calculateStreak(record, history);
    double m = _calculateMorning(record);

    double finalScore = base * r * h * t * p * s * m;
    return min(finalScore, 25.0); // 单次封顶25分
  }

  // R: 时间规律系数
  static double _calculateRegularity(ToiletRecord record, List<ToiletRecord> history) {
    if (record.type != RecordType.big) return 1.0;

    // 获取历史30天内第一次大号的时间（分钟数）
    List<int> historicalTimes = [];
    DateTime now = DateTime.now();
    DateTime thirtyDaysAgo = now.subtract(Duration(days: 30));

    var recentHistory = history.where((r) {
      DateTime dt = DateTime.fromMillisecondsSinceEpoch(r.timestamp);
      return r.type == RecordType.big && dt.isAfter(thirtyDaysAgo);
    }).toList();

    // 按天分组的第一次大号时间
    Map<int, int> firstPerDay = {};
    for (var r in recentHistory) {
      DateTime dt = DateTime.fromMillisecondsSinceEpoch(r.timestamp);
      int dayKey = dt.year * 10000 + dt.month * 100 + dt.day;
      int minutes = dt.hour * 60 + dt.minute;
      if (!firstPerDay.containsKey(dayKey) || minutes < firstPerDay[dayKey]!) {
        firstPerDay[dayKey] = minutes;
      }
    }

    historicalTimes = firstPerDay.values.toList();
    if (historicalTimes.length < 3) return 1.0; // 数据不足，不惩罚

    // 计算标准差
    double mean = historicalTimes.reduce((a, b) => a + b) / historicalTimes.length;
    double variance = historicalTimes.map((t) => pow(t - mean, 2))
                                     .reduce((a, b) => a + b) / historicalTimes.length;
    double std = sqrt(variance);

    // 映射到 0.8 ~ 1.5
    // std < 20分钟 = 1.5（极其规律）
    // std > 180分钟 = 0.8（完全随机）
    if (std <= 20) return 1.5;
    if (std >= 180) return 0.8;
    return 1.5 - ((std - 20) / 160) * 0.7;
  }

  // H: 健康系数
  static double _calculateHealth(ToiletRecord record) {
    if (record.type != RecordType.big) return 1.0;

    switch (record.bristolType) {
      case 3: case 4: return 1.2; // 黄金标准
      case 2: case 5: return 1.0; // 正常范围边缘
      case 1: return 0.9;         // 便秘
      case 6: return 0.85;        // 轻度腹泻
      case 7: return 0.8;         // 腹泻
      default: return 1.0;
    }
  }

  // T: 时长系数
  static double _calculateTime(ToiletRecord record) {
    int minutes = (record.duration ?? 0) ~/ 60;

    if (record.type == RecordType.small) {
      // 小号：1分钟内正常
      return minutes <= 2 ? 1.1 : 1.0;
    }

    // 大号
    if (minutes >= 3 && minutes <= 8) return 1.1;   // 黄金区间
    if (minutes >= 1 && minutes < 3) return 1.0;    // 略快
    if (minutes > 8 && minutes <= 15) return 1.0;   // 略久
    if (minutes > 15 && minutes <= 20) return 0.8;   // 过久（警告）
    if (minutes > 20) return 0.7;                    // 过长（痔疮风险）
    if (minutes < 1) return 0.8;                     // 过快（可能未排尽）
    return 1.0;
  }

  // P: 带薪系数
  static double _calculatePaid(ToiletRecord record) {
    if (!record.isPaidPoop) return 1.0;
    return 1.2; // 带薪 +20%
  }

  // S: 连击系数
  static double _calculateStreak(ToiletRecord record, List<ToiletRecord> history) {
    // 计算连续每日至少1次大号的天数
    int streak = 0;
    DateTime checkDay = DateTime.fromMillisecondsSinceEpoch(record.timestamp);

    // 往前检查
    for (int i = 1; i <= 30; i++) {
      DateTime targetDay = checkDay.subtract(Duration(days: i));
      bool hasBig = history.any((r) {
        DateTime dt = DateTime.fromMillisecondsSinceEpoch(r.timestamp);
        return r.type == RecordType.big && 
               dt.year == targetDay.year && 
               dt.month == targetDay.month && 
               dt.day == targetDay.day;
      });
      if (hasBig) {
        streak++;
      } else {
        break;
      }
    }

    // 连击系数：第1-2天=1.0，第3天起每天+0.1，上限2.0
    if (streak < 2) return 1.0;
    return min(1.0 + (streak - 2) * 0.1, 2.0);
  }

  // M: 晨便系数
  static double _calculateMorning(ToiletRecord record) {
    if (record.type != RecordType.big) return 1.0;
    DateTime dt = DateTime.fromMillisecondsSinceEpoch(record.timestamp);
    if (dt.hour >= 6 && dt.hour <= 9) return 1.15;
    return 1.0;
  }
}
```

### 5.2 段位与赛季系统

#### 5.2.1 段位定义

```dart
class RankSystem {
  static final List<Rank> ranks = [
    Rank(name: "便秘青铜", minScore: 0, maxScore: 99, icon: "🥉", color: Color(0xFFCD7F32)),
    Rank(name: "通畅白银", minScore: 100, maxScore: 499, icon: "🥈", color: Color(0xFFC0C0C0)),
    Rank(name: "规律黄金", minScore: 500, maxScore: 1999, icon: "🥇", color: Color(0xFFFFD700)),
    Rank(name: "铂金肠王", minScore: 2000, maxScore: 4999, icon: "💎", color: Color(0xFFE5E4E2)),
    Rank(name: "钻石所长", minScore: 5000, maxScore: 9999, icon: "👑", color: Color(0xFFB9F2FF)),
    Rank(name: "星耀肠道长", minScore: 10000, maxScore: 19999, icon: "🌟", color: Color(0xFF9B59B6)),
    Rank(name: "最强王者", minScore: 20000, maxScore: double.infinity, icon: "🏆", color: Color(0xFFFF6B6B)),
  ];

  static Rank getRankByScore(int score) {
    return ranks.firstWhere((r) => score >= r.minScore && score <= r.maxScore,
        orElse: () => ranks.first);
  }
}
```

#### 5.2.2 赛季管理

```dart
class SeasonManager {
  /// 获取当前赛季标识，格式：YYYY-MM
  static String getCurrentSeason() {
    DateTime now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}";
  }

  /// 赛季切换检查
  static Future<void> checkSeasonRollover() async {
    String currentSeason = getCurrentSeason();
    String lastSeason = await LocalStorage.getLastKnownSeason();

    if (lastSeason != currentSeason) {
      // 赛季切换！
      await _handleSeasonChange(lastSeason, currentSeason);
    }
  }

  static Future<void> _handleSeasonChange(String oldSeason, String newSeason) async {
    // 1. 保存上赛季最终数据到本地历史
    int lastScore = await LocalStorage.getSeasonScore();
    String lastRank = (await LocalStorage.getCurrentRank()).name;

    await LocalDB.saveSeasonHistory(
      season: oldSeason,
      finalScore: lastScore,
      finalRank: lastRank,
    );

    // 2. 重置本赛季积分（本地）
    await LocalStorage.setSeasonScore(0);

    // 3. 通知服务端重置
    await RankingService.resetSeason(newSeason);

    // 4. 发送通知
    await NotificationService.show(
      title: "🎉 新赛季开始！",
      body: "${newSeason}赛季已开启，上赛季您达到了 $lastRank，本赛季继续加油！",
    );

    // 5. 更新已知赛季
    await LocalStorage.setLastKnownSeason(newSeason);
  }
}
```

### 5.3 排行榜页面设计

#### 5.3.1 页面结构

```dart
class RankingPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text("肠道排行榜"),
          bottom: TabBar(
            tabs: [
              Tab(text: "全球", icon: Icon(Icons.public)),
              Tab(text: "同城", icon: Icon(Icons.location_on)),
              Tab(text: "好友", icon: Icon(Icons.people)),
              Tab(text: "趣味", icon: Icon(Icons.emoji_events)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            GlobalRankingTab(),
            CityRankingTab(),
            FriendsRankingTab(),
            FunRankingTab(),
          ],
        ),
      ),
    );
  }
}
```

#### 5.3.2 全球榜组件

```dart
class GlobalRankingTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 顶部三强展示
        TopThreePodium(),

        // 当前用户排名卡片（悬浮）
        MyRankCard(),

        // 榜单列表
        Expanded(
          child: ListView.builder(
            itemCount: rankings.length,
            itemBuilder: (context, index) {
              var item = rankings[index];
              bool isMe = item.userId == currentUserId;

              return ListTile(
                leading: Container(
                  width: 40,
                  alignment: Alignment.center,
                  child: Text(
                    "${item.rank}",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: item.rank <= 3 ? Colors.amber : Colors.grey,
                    ),
                  ),
                ),
                title: Text(
                  item.isAnonymous ? "匿名肠友" : item.nickname,
                  style: TextStyle(
                    fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                subtitle: Text(item.rankTitle),
                trailing: Text(
                  "${item.score.toStringAsFixed(1)} 分",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF795548),
                  ),
                ),
                tileColor: isMe ? Color(0xFFFFF8E1) : null,
              );
            },
          ),
        ),
      ],
    );
  }
}
```

#### 5.3.3 趣味榜分类

```dart
class FunRankingTab extends StatelessWidget {
  final List<FunRankingCategory> categories = [
    FunRankingCategory(
      id: "small_freq",
      name: "🧻 小号频率榜",
      description: "谁是小号之王？",
      scoreFormula: "仅计算小号积分",
    ),
    FunRankingCategory(
      id: "efficiency",
      name: "⚡ 效率榜",
      description: "速战速决，时间就是生命",
      scoreFormula: "平均时长最短且规律指数>70",
    ),
    FunRankingCategory(
      id: "paid_pooper",
      name: "💼 带薪收益榜",
      description: "摸鱼也是生产力",
      scoreFormula: "累计带薪时长换算成白赚工资",
    ),
    FunRankingCategory(
      id: "morning",
      name: "🌅 晨便榜",
      description: "早起的人肠道不堵",
      scoreFormula: "仅统计6-9点大号积分×1.5",
    ),
    FunRankingCategory(
      id: "weekend",
      name: "🛋️ 周末战士",
      description: "休息日也不闲着",
      scoreFormula: "周末积分×2",
    ),
    FunRankingCategory(
      id: "regularity",
      name: "📅 规律大师",
      description: "生物钟精准如瑞士手表",
      scoreFormula: "规律指数直接作为排名依据",
    ),
  ];
}
```

### 5.4 防作弊系统（完整版）

```dart
class AntiCheatSystem {
  /// 客户端预检
  static CheatCheckResult clientPreCheck(ToiletRecord record, List<ToiletRecord> history) {
    // 1. 频率检测
    int todayCount = history.where((r) => isToday(r.timestamp)).length;
    if (todayCount > 10) {
      return CheatCheckResult(
        flag: CheatFlag.suspicious,
        action: CheatAction.holdPoints,
        reason: "今日记录次数异常（$todayCount次）",
      );
    }
    if (todayCount > 15) {
      return CheatCheckResult(
        flag: CheatFlag.cheat,
        action: CheatAction.banSeason,
        reason: "今日记录次数严重异常（$todayCount次），疑似刷分",
      );
    }

    // 2. 时间合理性
    int duration = record.duration ?? 0;
    if (record.type == RecordType.big && duration < 30) {
      return CheatCheckResult(
        flag: CheatFlag.suspicious,
        action: CheatAction.scorePenalty,
        penalty: 0.5,
        reason: "大号时长仅${duration}秒，异常",
      );
    }
    if (duration > 3600) {
      return CheatCheckResult(
        flag: CheatFlag.invalid,
        action: CheatAction.reject,
        reason: "单次时长超过1小时，不符合常理",
      );
    }

    // 3. 时间间隔检测（同一地点短时间内多次）
    var recentRecords = history.where((r) {
      return (record.timestamp - r.timestamp).abs() < 5 * 60 * 1000; // 5分钟内
    }).toList();

    if (recentRecords.length >= 3) {
      return CheatCheckResult(
        flag: CheatFlag.suspicious,
        action: CheatAction.holdPoints,
        reason: "5分钟内连续记录${recentRecords.length}次",
      );
    }

    return CheatCheckResult(flag: CheatFlag.ok);
  }

  /// 服务端二次校验
  static Future<CheatCheckResult> serverVerify(
    ScoreUploadRequest request,
    UserStats userStats
  ) async {
    // 1. 地理位置跳跃（需要用户授权模糊位置）
    if (request.locationHash != null && userStats.lastLocationHash != null) {
      // 服务端只存储城市级哈希，不精确到点
      if (request.locationHash != userStats.lastLocationHash) {
        // 城市变化正常，不拦截
      }
    }

    // 2. 积分增长速率检测
    double hourlyGrowth = await _calculateHourlyGrowth(userStats.userId);
    if (hourlyGrowth > 50) { // 1小时增长超过50分
      return CheatCheckResult(
        flag: CheatFlag.suspicious,
        action: CheatAction.review,
        reason: "积分增长过快（1小时+$hourlyGrowth分）",
      );
    }

    // 3. 乘数合理性校验
    double maxReasonableMultiplier = 1.5 * 1.2 * 1.1 * 1.2 * 2.0 * 1.15; // ≈ 5.45
    double totalMultiplier = request.multipliers.values.reduce((a, b) => a * b);
    if (totalMultiplier > maxReasonableMultiplier * 1.1) {
      return CheatCheckResult(
        flag: CheatFlag.cheat,
        action: CheatAction.banSeason,
        reason: "乘数异常（$totalMultiplier > 理论最大值）",
      );
    }

    // 4. 历史行为模式分析（基于用户历史统计）
    double zScore = await _calculateZScore(userStats.userId, request.finalScore);
    if (zScore > 3) { // 超过3个标准差
      return CheatCheckResult(
        flag: CheatFlag.suspicious,
        action: CheatAction.holdPoints,
        reason: "本次积分偏离历史模式（Z-Score: $zScore）",
      );
    }

    return CheatCheckResult(flag: CheatFlag.ok);
  }
}
```

---

## 六、设置模块

### 6.1 个人档案详细设计

```dart
class ProfileModel {
  String? nickname;           // 昵称，最多16字符
  String? avatarBase64;         // 头像Base64，限制100KB
  Gender? gender;               // 0:未知 1:男 2:女 3:其他
  int? birthYear;             // 出生年份，用于计算年龄范围
  double? heightCm;             // 身高cm
  double? weightKg;             // 体重kg
  double? chestCm;              // 胸围cm（纯本地）
  double? waistCm;              // 腰围cm（本地+AI分析参考）
  double? hipCm;                // 臀围cm（纯本地）
  JobType? jobType;             // 职业类型
  int? workStartHour;         // 上班时间（0-23）v1.0.5+
  int? workEndHour;           // 下班时间（0-23）v1.0.5+

  // 计算属性
  double? get bmi => weightKg != null && heightCm != null 
      ? weightKg! / pow(heightCm! / 100, 2) 
      : null;

  String? get bmiCategory {
    if (bmi == null) return null;
    if (bmi! < 18.5) return "偏瘦";
    if (bmi! < 24) return "正常";
    if (bmi! < 28) return "偏胖";
    return "肥胖";
  }

  String? get waistToHipRatio {
    if (waistCm == null || hipCm == null) return null;
    double ratio = waistCm! / hipCm!;
    return ratio.toStringAsFixed(2);
  }

  String? get ageRange {
    if (birthYear == null) return null;
    int age = DateTime.now().year - birthYear!;
    if (age < 18) return "<18";
    if (age <= 25) return "18-25";
    if (age <= 35) return "26-35";
    if (age <= 45) return "36-45";
    if (age <= 55) return "46-55";
    return "55+";
  }

  int? get age {
    if (birthYear == null) return null;
    return DateTime.now().year - birthYear!;
  }

  /// 22岁以下默认8点上班，23岁以上9点上班
  int get defaultWorkStartHour {
    if (age == null) return 9;
    return age! <= 22 ? 8 : 9;
  }

  int get defaultWorkEndHour => 18;
}

enum Gender { unknown, male, female, other }
enum JobType { sedentary, standing, physical, mixed, other }
```

### 6.2 生物识别应用锁（已实现）

实际实现参见以下文件：

| 文件 | 说明 |
|------|------|
| [security_service.dart](la-le-me-app/lib/services/security_service.dart) | `SecurityService` — 封装 `local_auth` 的静态工具类 |
| [lock_screen.dart](la-le-me-app/lib/screens/lock_screen.dart) | `AppLockWrapper` — 应用锁包装器，监听生命周期自动锁定/解锁 |
| [security_page.dart](la-le-me-app/lib/screens/security_page.dart) | 安全设置页面 UI |

**核心实现架构：**

```
main.dart → AppLockWrapper → 监听 AppLifecycleState
                │
     ┌──────────┴──────────┐
     │  settingsProvider    │ 读取 appLockEnabled
     │  SecurityService     │ 调用 local_auth 指纹识别
     └──────────┬──────────┘
                │
     ┌──────────▼──────────┐
     │  暂停 → 锁定标记     │  LifecycleState.paused
     │  恢复 → 认证解锁     │  LifecycleState.resumed
     │  失败 → 保持锁定     │  可重试
     └─────────────────────┘
```

**SecurityService API：**

```dart
class SecurityService {
  static Future<bool> isBiometricAvailable();    // 设备是否支持生物识别
  static Future<List<BiometricType>> getAvailableBiometrics(); // 可用类型列表
  static String biometricLabel(List<BiometricType> types);     // 中文标签
  static Future<bool> authenticate({required String reason});  // 执行认证
  static Future<void> setPrivacyMode(bool enabled);            // FLAG_SECURE 切换
}
```

**隐私模式实现：**

- Android 通过 `MethodChannel('com.laleime/privacy')` 调用 `MainActivity.kt` 中的 `FLAG_SECURE` 窗口标志
- 开启后最近任务列表和截图中隐藏应用内容
- 设置页开关切换时立即生效，应用启动时自动恢复状态

### 6.3 数据备份与恢复

#### 6.3.1 备份格式定义

```json
{
  "version": "1.0",
  "export_date": "2026-05-10T16:54:00Z",
  "app_version": "1.2.0",
  "checksum": "sha256:abc123...",

  "metadata": {
    "record_count": 1523,
    "first_record_date": "2025-01-01",
    "last_record_date": "2026-05-10",
    "profile_present": true
  },

  "records": [
    {
      "id": "uuid",
      "type": 1,
      "timestamp": 1715328000000,
      "duration": 300,
      "bristol_type": 4,
      "color": 0,
      "smoothness": 4,
      "is_work_hours": 1,
      "is_paid_poop": 1,
      "note": "",
      "mood": "😊"
    }
  ],

  "profile": {
    "nickname": "肠道长老王",
    "gender": 1,
    "birth_year": 1990,
    "height_cm": 175.0,
    "weight_kg": 70.0,
    "chest_cm": 95.0,
    "waist_cm": 82.0,
    "hip_cm": 98.0,
    "job_type": 0
  },

  "settings": {
    "theme": "light",
    "sound_effect": "water_drop",
    "reminder_enabled": true,
    "morning_reminder_time": "07:30",
    "sedentary_reminder_interval": 120
  },

  "achievements": ["morning_7", "paid_pooper", "regular_30"],

  "ai_reports": [
    {
      "report_id": "uuid",
      "generated_at": "2026-05-09T21:00:00Z",
      "result_json": "{...}",
      "valid_until": "2026-05-16T21:00:00Z"
    }
  ],

  "season_history": [
    {
      "season": "2026-04",
      "final_score": 8500,
      "final_rank": "钻石所长"
    }
  ]
}
```

#### 6.3.2 备份加密流程

```dart
class BackupEncryption {
  /// 加密备份文件
  static Future<String> encrypt(String jsonData, String password) async {
    // 1. 生成随机盐值
    final salt = SecureRandom(16).bytes;

    // 2. 使用 PBKDF2 派生密钥
    final params = Pbkdf2Parameters(salt, 100000, 32); // 10万次迭代
    final keyDerivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    keyDerivator.init(params);
    final key = keyDerivator.process(utf8.encode(password));

    // 3. 生成随机IV
    final iv = SecureRandom(12).bytes; // GCM模式推荐12字节

    // 4. AES-256-GCM 加密
    final cipher = GCMBlockCipher(AESEngine());
    final params = AEADParameters(KeyParameter(key), 128, iv, utf8.encode("backup"));
    cipher.init(true, params);

    final encrypted = cipher.process(utf8.encode(jsonData));

    // 5. 组装：salt(16) + iv(12) + ciphertext + tag(16)
    final result = Uint8List(salt.length + iv.length + encrypted.length);
    result.setRange(0, salt.length, salt);
    result.setRange(salt.length, salt.length + iv.length, iv);
    result.setRange(salt.length + iv.length, result.length, encrypted);

    // 6. Base64编码
    return base64Encode(result);
  }

  /// 解密备份文件
  static Future<String> decrypt(String base64Data, String password) async {
    final data = base64Decode(base64Data);

    // 1. 提取 salt, iv, ciphertext
    final salt = data.sublist(0, 16);
    final iv = data.sublist(16, 28);
    final ciphertext = data.sublist(28);

    // 2. 重新派生密钥
    final params = Pbkdf2Parameters(salt, 100000, 32);
    final keyDerivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    keyDerivator.init(params);
    final key = keyDerivator.process(utf8.encode(password));

    // 3. 解密
    final cipher = GCMBlockCipher(AESEngine());
    final params = AEADParameters(KeyParameter(key), 128, iv, utf8.encode("backup"));
    cipher.init(false, params);

    final decrypted = cipher.process(ciphertext);
    return utf8.decode(decrypted);
  }
}
```

#### 6.3.3 数据管理界面

```dart
class DataManagementPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("数据管理")),
      body: ListView(
        children: [
          // 1. 本地备份
          ListTile(
            leading: Icon(Icons.save_alt),
            title: Text("导出本地备份"),
            subtitle: Text("加密 JSON 文件，可存储到手机或云盘"),
            trailing: Icon(Icons.chevron_right),
            onTap: () => _exportLocalBackup(),
          ),

          // 2. 恢复数据
          ListTile(
            leading: Icon(Icons.restore),
            title: Text("从备份恢复"),
            subtitle: Text("选择备份文件并输入密码"),
            trailing: Icon(Icons.chevron_right),
            onTap: () => _restoreFromBackup(),
          ),

          // 3. 云端同步开关
          SwitchListTile(
            secondary: Icon(Icons.cloud_sync),
            title: Text("云端同步（仅积分与排名）"),
            subtitle: Text("原始记录不上传，保护隐私"),
            value: cloudSyncEnabled,
            onChanged: (v) => toggleCloudSync(v),
          ),

          // 4. 导入其他APP
          ListTile(
            leading: Icon(Icons.file_upload),
            title: Text("从其他APP导入"),
            subtitle: Text("支持 CSV 格式（如「便了么」导出）"),
            trailing: Icon(Icons.chevron_right),
            onTap: () => _importFromCSV(),
          ),

          Divider(),

          // 5. 危险操作区
          ListTile(
            leading: Icon(Icons.delete_forever, color: Colors.red),
            title: Text("清空所有数据", style: TextStyle(color: Colors.red)),
            subtitle: Text("此操作不可恢复"),
            onTap: () => _confirmClearAll(),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearAll() async {
    // 三级确认
    bool confirm1 = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("⚠️ 危险操作"),
        content: Text("您确定要清空所有本地数据吗？此操作不可恢复。"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text("取消")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text("确定")),
        ],
      ),
    );

    if (!confirm1) return;

    // 二级：输入确认文字
    String? input = await showTextInputDialog(
      context: context,
      title: "二次确认",
      message: "请输入「确认清空」以继续",
    );

    if (input != "确认清空") return;

    // 三级：生物识别验证
    bool bioAuth = await BiometricAuthService.verifySensitiveAction("清空数据");
    if (!bioAuth) return;

    // 执行清空
    await LocalDB.clearAll();
    await SecureStorage.clear();
    await RankingService.deleteAccount();

    // 重启应用
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("已清空"),
        content: Text("所有数据已清除，应用将重新启动。"),
      ),
    );

    // 重启
    Phoenix.rebirth(context);
  }
}
```

### 6.4 偏好设置详细清单

```dart
class AppSettings {
  // 主题
  ThemeMode themeMode; // system / light / dark
  bool useOledDark;    // OLED纯黑模式

  // 音效
  SoundEffect soundEffect; // none / water_drop / flush / fart / custom
  double soundVolume;      // 0.0 - 1.0

  // 提醒
  bool morningReminderEnabled;
  TimeOfDay morningReminderTime; // 默认 07:00-09:00 窗口
  bool sedentaryReminderEnabled;
  int sedentaryReminderMinutes;  // 默认 120
  bool irregularReminderEnabled; // 规律异常提醒
  bool smallReminderEnabled;     // 小号超时提醒开关，默认 true
  int smallReminderHours;        // 小号超时阈值(小时)，默认 4
  bool bigReminderEnabled;       // 大号超时提醒开关，默认 true
  int bigReminderDays;           // 大号超时阈值(天)，默认 2

  // 隐私
  bool appLockEnabled;
  BiometricType preferredBiometric;
  bool privacyModeEnabled; // 最近任务卡片空白
  bool anonymousRanking;   // 排行榜匿名

  // 记录
  bool autoDetectWorkHours; // 自动判断带薪（基于时间）
  bool quickRecordDefault;  // 默认快速记录（不弹出详情）
  bool showBristolReminder; // 记录时提醒选择布里斯托分型

  // Emoji风格
  EmojiStyle emojiStyle; // cute(💩) / serious(🚻) / minimal(文字)
}

enum SoundEffect { none, water_drop, flush, fart, custom }
enum EmojiStyle { cute, serious, minimal }
```

### 6.5 服务器配置模块

#### 6.5.1 功能概述

设置 → 服务器配置 页面允许用户手动指定后端服务器地址，替代编译时环境变量的方式：

| 功能 | 说明 |
|------|------|
| 手动输入 | 用户可输入任意 HTTP/HTTPS 服务器地址 |
| 健康检查 | `GET /health` 请求，实时显示服务器状态（🟢正常/🔴异常） |
| 连接测试 | 验证服务器可达性，显示详细错误原因 |
| 持久化保存 | 地址通过 `DatabaseService.setSetting` 持久化存储 |
| Dio 连接 | 使用 Dio HTTP 客户端进行网络请求，5秒超时 |

#### 6.5.2 页面结构

```
ServerConfigPage (StatefulWidget)
├── AppBar: 服务器配置
├── TextField: 服务器地址输入（带清除按钮）
├── 状态指示卡片（彩色边框 + 图标 + 状态文字）
│   ├── 🟢 服务器运行正常
│   ├── 🟡 服务器响应异常
│   └── 🔴 连接失败
├── 操作按钮行
│   ├── [健康检查] - 检测 /health 端点
│   └── [连接服务器] - 保存配置 + 健康检查
└── 提示卡片: 连接成功后积分自动上报说明
```

#### 6.5.3 健康检查实现

```dart
Future<void> _checkHealth() async {
  final dio = Dio(BaseOptions(
    connectTimeout: Duration(seconds: 5),
    receiveTimeout: Duration(seconds: 5),
  ));
  final response = await dio.get('$url/health');

  if (response.statusCode == 200) {
    // 服务器正常，显示绿色状态
  } else {
    // 响应异常，显示黄色警告
  }
}
```

#### 6.5.4 路由注册

```dart
'/settings/server': (ctx) => const ServerConfigPage(),
```

---

## 七、后端服务设计

### 7.1 项目目录结构（Go）

```
la-le-me-backend/
├── cmd/
│   └── server/
│       └── main.go              # 入口
├── internal/
│   ├── config/
│   │   └── config.go            # 配置管理（viper）
│   ├── handler/
│   │   ├── auth_handler.go      # 认证接口
│   │   ├── user_handler.go      # 用户接口
│   │   ├── record_handler.go    # 积分上报接口
│   │   ├── ranking_handler.go   # 排行榜接口
│   │   ├── backup_handler.go    # 备份接口
│   │   └── ws_handler.go        # WebSocket
│   ├── middleware/
│   │   ├── jwt_auth.go          # JWT认证
│   │   ├── rate_limit.go        # 限流
│   │   ├── cors.go              # 跨域
│   │   └── recovery.go          #  panic恢复
│   ├── model/
│   │   ├── user.go
│   │   ├── score_log.go
│   │   ├── achievement.go
│   │   └── season.go
│   ├── repository/
│   │   ├── user_repo.go         # 用户数据访问
│   │   ├── score_repo.go        # 积分数据访问
│   │   └── redis_repo.go        # Redis访问
│   ├── service/
│   │   ├── auth_service.go
│   │   ├── score_service.go     # 积分结算核心
│   │   ├── ranking_service.go   # 排行榜计算
│   │   └── anti_cheat_service.go # 反作弊
│   └── util/
│       ├── jwt.go
│       ├── hash.go
│       └── response.go
├── pkg/
│   └── errors/
│       └── errors.go            # 业务错误码
├── scripts/
│   └── migrate.sh
├── docker/
│   ├── Dockerfile
│   └── docker-compose.yml
├── config/
│   └── config.yaml
├── go.mod
├── go.sum
└── Makefile
```

### 7.2 核心服务实现

#### 7.2.1 积分结算服务

```go
package service

import (
    "context"
    "math"
    "time"

    "github.com/redis/go-redis/v9"
    "gorm.io/gorm"
)

type ScoreService struct {
    db          *gorm.DB
    redis       *redis.Client
    antiCheat   *AntiCheatService
}

// ScoreSettlementRequest 客户端上报的请求结构
type ScoreSettlementRequest struct {
    RecordUUID     string             `json:"record_uuid" binding:"required,uuid"`
    Type           string             `json:"type" binding:"required,oneof=small big"`
    Timestamp      int64              `json:"timestamp" binding:"required"`
    Duration       int                `json:"duration" binding:"min=0,max=3600"`
    IsWorkHours    bool               `json:"is_work_hours"`
    IsPaidPoop     bool               `json:"is_paid_poop"`
    BristolType    *int               `json:"bristol_type,omitempty" binding:"omitempty,min=1,max=7"`
    BaseScore      float64            `json:"base_score" binding:"required,min=1,max=5"`
    Multipliers    Multipliers        `json:"multipliers" binding:"required"`
    FinalScore     float64            `json:"final_score" binding:"required,min=0,max=25"`
    AchievementIDs []string           `json:"achievement_ids"`
    LocationHash   string             `json:"location_hash,omitempty"`
}

type Multipliers struct {
    R float64 `json:"r" binding:"min=0.8,max=1.5"`
    H float64 `json:"h" binding:"min=0.5,max=1.2"`
    T float64 `json:"t" binding:"min=0.7,max=1.1"`
    P float64 `json:"p" binding:"min=1.0,max=1.2"`
    S float64 `json:"s" binding:"min=1.0,max=2.0"`
    M float64 `json:"m" binding:"min=1.0,max=1.15"`
}

// Settle 积分结算主流程
func (s *ScoreService) Settle(ctx context.Context, userID int64, req ScoreSettlementRequest) (*SettlementResult, error) {
    // 1. 反作弊预检
    cheatResult := s.antiCheat.Check(ctx, userID, req)
    if cheatResult.Flag == CheatFlagInvalid {
        return nil, errors.NewBusinessError(ErrCheatDetected, "记录被判定为无效")
    }

    // 2. 服务端二次校验乘数
    serverMultiplier := req.Multipliers.R * req.Multipliers.H * req.Multipliers.T * 
                        req.Multipliers.P * req.Multipliers.S * req.Multipliers.M
    maxReasonable := 1.5 * 1.2 * 1.1 * 1.2 * 2.0 * 1.15 // 5.445
    if serverMultiplier > maxReasonable*1.1 {
        return nil, errors.NewBusinessError(ErrCheatDetected, "乘数异常")
    }

    // 3. 重新计算验证（服务端也计算一次，与客户端比对，允许5%误差）
    serverCalculated := req.BaseScore * serverMultiplier
    if math.Abs(serverCalculated-req.FinalScore) > req.FinalScore*0.05 {
        return nil, errors.NewBusinessError(ErrScoreMismatch, "积分计算不一致")
    }

    // 4. 写入积分流水
    scoreLog := model.ScoreLog{
        UserID:        userID,
        RecordUUID:    req.RecordUUID,
        BaseScore:     req.BaseScore,
        MultiplierR:   req.Multipliers.R,
        MultiplierH:   req.Multipliers.H,
        MultiplierT:   req.Multipliers.T,
        MultiplierP:   req.Multipliers.P,
        MultiplierS:   req.Multipliers.S,
        MultiplierM:   req.Multipliers.M,
        FinalScore:    req.FinalScore,
        AchievementIDs: req.AchievementIDs,
        CheatFlag:     string(cheatResult.Flag),
    }

    if err := s.db.WithContext(ctx).Create(&scoreLog).Error; err != nil {
        return nil, err
    }

    // 5. 更新用户赛季积分（原子操作）
    season := getCurrentSeason()
    var user model.User
    if err := s.db.WithContext(ctx).First(&user, userID).Error; err != nil {
        return nil, err
    }

    // 事务更新
    err := s.db.WithContext(ctx).Transaction(func(tx *gorm.DB) error {
        // 更新用户总积分和赛季积分
        if err := tx.Model(&user).Updates(map[string]interface{}{
            "total_score":  gorm.Expr("total_score + ?", req.FinalScore),
            "season_score": gorm.Expr("season_score + ?", req.FinalScore),
            "updated_at":   time.Now(),
        }).Error; err != nil {
            return err
        }

        // 检查段位变化
        newRank := determineRank(int(user.SeasonScore + int64(req.FinalScore)))
        if newRank != user.CurrentRank {
            if err := tx.Model(&user).Update("current_rank", newRank).Error; err != nil {
                return err
            }
        }

        return nil
    })

    if err != nil {
        return nil, err
    }

    // 6. 更新 Redis 排行榜
    pipe := s.redis.Pipeline()
    seasonKey := fmt.Sprintf("global:ranking:%s", season)
    pipe.ZIncrBy(ctx, seasonKey, req.FinalScore, fmt.Sprintf("%d", userID))

    // 同城榜
    if user.CityCode != "" {
        cityKey := fmt.Sprintf("city:ranking:%s:%s", user.CityCode, season)
        pipe.ZIncrBy(ctx, cityKey, req.FinalScore, fmt.Sprintf("%d", userID))
    }

    // 缓存用户赛季积分
    cacheKey := fmt.Sprintf("user:season_score:%d:%s", userID, season)
    pipe.Set(ctx, cacheKey, user.SeasonScore+int64(req.FinalScore), time.Hour)

    _, err = pipe.Exec(ctx)
    if err != nil {
        // Redis失败不影响主流程，记录日志
        log.Printf("Redis update failed: %v", err)
    }

    // 7. 检查成就解锁（服务端也校验）
    newAchievements := s.checkAchievements(ctx, userID, req.AchievementIDs)

    // 8. 获取新排名
    newRank, _ := s.redis.ZRevRank(ctx, seasonKey, fmt.Sprintf("%d", userID)).Result()

    return &SettlementResult{
        Accepted:         true,
        NewSeasonScore:   user.SeasonScore + int64(req.FinalScore),
        NewRank:          int(newRank) + 1,
        RankChange:       0, // 需要查询旧排名计算
        NewAchievements:  newAchievements,
        CheatFlag:        string(cheatResult.Flag),
        CurrentRankTitle: newRank,
    }, nil
}

func getCurrentSeason() string {
    now := time.Now()
    return fmt.Sprintf("%d-%02d", now.Year(), now.Month())
}

func determineRank(score int) string {
    switch {
    case score >= 20000:
        return "最强王者"
    case score >= 10000:
        return "星耀肠道长"
    case score >= 5000:
        return "钻石所长"
    case score >= 2000:
        return "铂金肠王"
    case score >= 500:
        return "规律黄金"
    case score >= 100:
        return "通畅白银"
    default:
        return "便秘青铜"
    }
}
```

#### 7.2.2 排行榜服务

```go
package service

type RankingService struct {
    redis *redis.Client
    db    *gorm.DB
}

// GetGlobalRanking 获取全球榜
func (s *RankingService) GetGlobalRanking(ctx context.Context, season string, page, limit int) (*RankingPageResult, error) {
    if season == "" {
        season = getCurrentSeason()
    }

    key := fmt.Sprintf("global:ranking:%s", season)
    start := int64((page - 1) * limit)
    stop := int64(page*limit - 1)

    // 获取排名范围
    results, err := s.redis.ZRevRangeWithScores(ctx, key, start, stop).Result()
    if err != nil {
        return nil, err
    }

    // 批量查询用户信息
    userIDs := make([]string, len(results))
    for i, r := range results {
        userIDs[i] = r.Member.(string)
    }

    var users []model.User
    if err := s.db.WithContext(ctx).Where("id IN ?", userIDs).Find(&users).Error; err != nil {
        return nil, err
    }

    userMap := make(map[int64]model.User)
    for _, u := range users {
        userMap[u.ID] = u
    }

    // 组装结果
    items := make([]RankingItem, len(results))
    for i, r := range results {
        uid, _ := strconv.ParseInt(r.Member.(string), 10, 64)
        user := userMap[uid]

        items[i] = RankingItem{
            Rank:      (page-1)*limit + i + 1,
            UserID:    uid,
            Nickname:  user.Nickname,
            AvatarURL: user.AvatarURL,
            Score:     r.Score,
            RankTitle: user.CurrentRank,
        }
    }

    // 获取总用户数
    total, _ := s.redis.ZCard(ctx, key).Result()

    return &RankingPageResult{
        Items:      items,
        Total:      int(total),
        Page:       page,
        Limit:      limit,
        TotalPages: int(math.Ceil(float64(total) / float64(limit))),
    }, nil
}

// GetUserRank 获取用户当前排名
func (s *RankingService) GetUserRank(ctx context.Context, userID int64, season string) (*UserRankInfo, error) {
    key := fmt.Sprintf("global:ranking:%s", season)
    member := fmt.Sprintf("%d", userID)

    // 获取排名（0-based）
    rank, err := s.redis.ZRevRank(ctx, key, member).Result()
    if err == redis.Nil {
        return &UserRankInfo{Rank: -1, Score: 0}, nil // 未上榜
    }
    if err != nil {
        return nil, err
    }

    // 获取分数
    score, _ := s.redis.ZScore(ctx, key, member).Result()

    // 获取附近用户（前2后2）
    nearbyStart := rank - 2
    if nearbyStart < 0 {
        nearbyStart = 0
    }
    nearbyResults, _ := s.redis.ZRevRangeWithScores(ctx, key, nearbyStart, rank+2).Result()

    return &UserRankInfo{
        Rank:      int(rank) + 1,
        Score:     score,
        Nearby:    s.convertToItems(nearbyResults, int(nearbyStart)+1),
    }, nil
}
```

#### 7.2.3 WebSocket 实时推送

```go
package handler

type WSHandler struct {
    hub *WSHub
}

type WSHub struct {
    clients    map[int64]*Client
    broadcast  chan WSMessage
    register   chan *Client
    unregister chan *Client
    mu         sync.RWMutex
}

type Client struct {
    hub      *WSHub
    conn     *websocket.Conn
    userID   int64
    send     chan []byte
}

type WSMessage struct {
    Type      string      `json:"type"`
    UserID    int64       `json:"user_id,omitempty"`
    Season    string      `json:"season"`
    Payload   interface{} `json:"payload"`
}

func (h *WSHandler) HandleWebSocket(c *gin.Context) {
    userID, exists := c.Get("userID")
    if !exists {
        c.JSON(401, gin.H{"error": "unauthorized"})
        return
    }

    conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
    if err != nil {
        log.Printf("WebSocket upgrade failed: %v", err)
        return
    }

    client := &Client{
        hub:    h.hub,
        conn:   conn,
        userID: userID.(int64),
        send:   make(chan []byte, 256),
    }

    h.hub.register <- client

    go client.writePump()
    go client.readPump()
}

// 排名变化时广播
func (h *WSHub) BroadcastRankChange(userID int64, season string, newRank int, scoreDelta float64) {
    msg := WSMessage{
        Type:   "rank_update",
        UserID: userID,
        Season: season,
        Payload: map[string]interface{}{
            "new_rank":    newRank,
            "score_delta": scoreDelta,
            "message":     fmt.Sprintf("您的排名上升至第 %d 名！", newRank),
        },
    }

    data, _ := json.Marshal(msg)

    h.mu.RLock()
    defer h.mu.RUnlock()

    // 推送给该用户
    if client, ok := h.clients[userID]; ok {
        select {
        case client.send <- data:
        default:
            close(client.send)
            delete(h.clients, userID)
        }
    }

    // 推送给好友（需要查询好友关系）
    // 此处简化，实际需查询好友列表
}
```

---

## 八、数据库设计

### 8.1 ER 图描述

```
[users] 1 ─── N [score_logs]
       1 ─── N [user_achievements]
       1 ─── N [backups]
       1 ─── 1 [api_configs]

[seasons] 1 ─── N [score_logs] (通过 season 字段关联)

[users] N ─── N [friends] (通过 friend_relations 关联表)
```

### 8.2 完整 Schema（PostgreSQL）

```sql
-- 启用 UUID 扩展
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 用户表
CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    uuid UUID UNIQUE DEFAULT uuid_generate_v4(),
    device_id VARCHAR(64) UNIQUE NOT NULL,
    nickname VARCHAR(32) NOT NULL DEFAULT '',
    avatar_url TEXT,
    gender SMALLINT CHECK (gender IN (0, 1, 2, 3)),
    age_range VARCHAR(10),
    city_code VARCHAR(10),
    total_score BIGINT DEFAULT 0,
    season_score BIGINT DEFAULT 0,
    highest_rank VARCHAR(20) DEFAULT '便秘青铜',
    current_rank VARCHAR(20) DEFAULT '便秘青铜',
    is_anonymous BOOLEAN DEFAULT false,
    status SMALLINT DEFAULT 1, -- 0:禁用 1:正常
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE users IS '用户主表，不存储任何敏感生理数据';
COMMENT ON COLUMN users.device_id IS '设备唯一标识，用于无密码登录';
COMMENT ON COLUMN users.city_code IS '模糊城市编码，如510100（成都）';

-- 索引
CREATE INDEX idx_users_uuid ON users(uuid);
CREATE INDEX idx_users_city ON users(city_code) WHERE city_code IS NOT NULL;
CREATE INDEX idx_users_rank ON users(current_rank);
CREATE INDEX idx_users_score ON users(season_score DESC);

-- 积分流水表
CREATE TABLE score_logs (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    record_uuid UUID NOT NULL,
    type VARCHAR(10) CHECK (type IN ('small', 'big')),
    base_score DECIMAL(5,2) NOT NULL,
    multiplier_r DECIMAL(3,2) DEFAULT 1.0,
    multiplier_h DECIMAL(3,2) DEFAULT 1.0,
    multiplier_t DECIMAL(3,2) DEFAULT 1.0,
    multiplier_p DECIMAL(3,2) DEFAULT 1.0,
    multiplier_s DECIMAL(3,2) DEFAULT 1.0,
    multiplier_m DECIMAL(3,2) DEFAULT 1.0,
    final_score DECIMAL(5,2) NOT NULL,
    achievement_ids JSONB DEFAULT '[]',
    cheat_flag VARCHAR(20) DEFAULT 'OK' CHECK (cheat_flag IN ('OK', 'SUSPICIOUS', 'CHEAT', 'INVALID')),
    location_hash VARCHAR(64),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    season VARCHAR(7) NOT NULL -- YYYY-MM
);

COMMENT ON TABLE score_logs IS '积分审计流水，用于反作弊追溯';

CREATE INDEX idx_score_logs_user ON score_logs(user_id, created_at DESC);
CREATE INDEX idx_score_logs_season ON score_logs(season);
CREATE INDEX idx_score_logs_cheat ON score_logs(cheat_flag) WHERE cheat_flag != 'OK';
CREATE INDEX idx_score_logs_record ON score_logs(record_uuid);

-- 成就表
CREATE TABLE user_achievements (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    achievement_id VARCHAR(32) NOT NULL,
    unlocked_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, achievement_id)
);

CREATE INDEX idx_achievements_user ON user_achievements(user_id);

-- 赛季表
CREATE TABLE seasons (
    id BIGSERIAL PRIMARY KEY,
    season_name VARCHAR(7) UNIQUE NOT NULL, -- YYYY-MM
    start_at TIMESTAMP WITH TIME ZONE NOT NULL,
    end_at TIMESTAMP WITH TIME ZONE NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 好友关系表
CREATE TABLE friend_relations (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    friend_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status VARCHAR(10) DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'blocked')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, friend_id)
);

CREATE INDEX idx_friends_user ON friend_relations(user_id, status);
CREATE INDEX idx_friends_friend ON friend_relations(friend_id, status);

-- 备份元数据表
CREATE TABLE backups (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    file_key VARCHAR(128) NOT NULL,
    file_size BIGINT,
    checksum VARCHAR(64) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP WITH TIME ZONE -- 自动删除过期备份
);

CREATE INDEX idx_backups_user ON backups(user_id, created_at DESC);

-- API 配置表（仅存储配置元数据，不存 Key）
CREATE TABLE api_configs (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    provider VARCHAR(32),
    base_url TEXT,
    model_name VARCHAR(64),
    temperature DECIMAL(3,2) DEFAULT 0.3,
    is_enabled BOOLEAN DEFAULT false,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 触发器：自动更新 updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 分区表（score_logs 按赛季分区，数据量大时启用）
-- CREATE TABLE score_logs_partitioned (LIKE score_logs INCLUDING ALL)
-- PARTITION BY LIST (season);
```

### 8.3 Redis 数据结构详细定义

```redis
# ============================================
# 1. 全球赛季排行榜（Sorted Set）
# ============================================
# Key: global:ranking:{season}
# Score: 赛季积分（浮点数，支持小数）
# Member: user_id (string)
# TTL: 赛季结束后保留30天
ZADD global:ranking:2026-05 1523.5 "10001"
ZADD global:ranking:2026-05 8990.0 "10002"

# 获取前100名
ZREVRANGE global:ranking:2026-05 0 99 WITHSCORES

# 获取用户排名（0-based，需+1）
ZREVRANK global:ranking:2026-05 "10001"

# 获取用户积分
ZSCORE global:ranking:2026-05 "10001"

# ============================================
# 2. 同城排行榜
# ============================================
# Key: city:ranking:{city_code}:{season}
ZADD city:ranking:510100:2026-05 1523.5 "10001"

# ============================================
# 3. 好友排行榜（每个用户一个 ZSet）
# ============================================
# Key: friends:ranking:{user_id}:{season}
# 初始化时从好友列表批量添加
ZADD friends:ranking:10001:2026-05 1523.5 "10002"
ZADD friends:ranking:10001:2026-05 2341.0 "10003"

# ============================================
# 4. 用户赛季积分缓存
# ============================================
# Key: user:season_score:{user_id}:{season}
# Value: 积分（string）
# TTL: 1小时
SET user:season_score:10001:2026-05 "1523" EX 3600

# ============================================
# 5. 用户成就缓存
# ============================================
# Key: user:achievements:{user_id}
# Value: JSON 数组
SET user:achievements:10001 '["morning_7", "paid_pooper"]' EX 86400

# ============================================
# 6. 反作弊限流（Redis Cell）
# ============================================
# 使用 Redis Cell 模块或原生实现
# Key: rate_limit:score_upload:{user_id}
# 每5分钟最多10次上报
CL.THROTTLE rate_limit:score_upload:10001 15 10 300 1

# ============================================
# 7. 在线状态（用于 WebSocket）
# ============================================
# Key: online:{user_id}
# Value: "1"
# TTL: 5分钟（需心跳续期）
SET online:10001 "1" EX 300

# ============================================
# 8. 赛季切换锁
# ============================================
# Key: season:lock:{season}
# Value: "1"
# TTL: 10分钟（防止重复切换）
SET season:lock:2026-05 "1" NX EX 600
```

---

## 九、API 接口详细定义

### 9.1 认证接口

#### POST /api/v1/auth/register
注册/设备登录

**请求**：
```json
{
  "device_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "nickname": "肠友_8X3d",
  "platform": "ios",      // ios | android
  "app_version": "1.2.0",
  "push_token": "..."     // 可选，推送令牌
}
```

**响应 201**：
```json
{
  "code": 0,
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIs...",
    "refresh_token": "eyJhbGciOiJIUzI1NiIs...",
    "expires_in": 900,
    "user": {
      "uuid": "550e8400-e29b-41d4-a716-446655440000",
      "nickname": "肠友_8X3d",
      "current_rank": "便秘青铜",
      "is_new_user": true
    }
  }
}
```

#### POST /api/v1/auth/refresh
刷新 Token

**请求**：
```json
{
  "refresh_token": "eyJhbGciOiJIUzI1NiIs..."
}
```

**响应 200**：
```json
{
  "code": 0,
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIs...",
    "expires_in": 900
  }
}
```

### 9.2 用户接口

#### GET /api/v1/user/profile
获取个人资料

**响应 200**：
```json
{
  "code": 0,
  "data": {
    "uuid": "550e8400-e29b-41d4-a716-446655440000",
    "nickname": "肠道长老王",
    "avatar_url": "https://cdn.example.com/avatars/xxx.jpg",
    "gender": 1,
    "age_range": "26-35",
    "city_code": "510100",
    "city_name": "成都",
    "total_score": 15230,
    "season_score": 5230,
    "highest_rank": "钻石所长",
    "current_rank": "铂金肠王",
    "is_anonymous": false,
    "created_at": "2025-01-15T08:30:00Z"
  }
}
```

#### PUT /api/v1/user/profile
更新个人资料

**请求**：
```json
{
  "nickname": "新昵称",
  "gender": 1,
  "age_range": "26-35",
  "city_code": "510100",
  "is_anonymous": false
}
```

**校验规则**：
- nickname: 1-32字符，禁止敏感词，正则 `^[\w\u4e00-\u9fa5]{1,32}$`
- city_code: 6位数字行政区划码

### 9.3 积分上报接口

#### POST /api/v1/records/sync
上报积分记录

**请求头**：
```
Authorization: Bearer <token>
X-Request-ID: <uuid>
```

**请求体**：
```json
{
  "record_uuid": "550e8400-e29b-41d4-a716-446655440000",
  "type": "big",
  "timestamp": 1715328000000,
  "duration": 300,
  "is_work_hours": true,
  "is_paid_poop": true,
  "bristol_type": 4,
  "base_score": 5.0,
  "multipliers": {
    "r": 1.3,
    "h": 1.2,
    "t": 1.1,
    "p": 1.2,
    "s": 1.2,
    "m": 1.15
  },
  "final_score": 14.9,
  "achievement_ids": ["morning_7", "paid_pooper"],
  "location_hash": "hash_of_chengdu"
}
```

**响应 200**：
```json
{
  "code": 0,
  "data": {
    "accepted": true,
    "new_season_score": 5244.9,
    "new_rank": 156,
    "rank_change": -5,
    "new_achievements": ["morning_7"],
    "cheat_flag": "OK",
    "current_rank_title": "铂金肠王",
    "score_breakdown": {
      "base": 5.0,
      "regularity_bonus": 1.5,
      "health_bonus": 1.0,
      "total": 14.9
    }
  }
}
```

**错误响应 400**：
```json
{
  "code": 1001,
  "message": "积分计算不一致",
  "data": {
    "client_calculated": 14.9,
    "server_calculated": 13.2,
    "diff_percent": 11.4
  }
}
```

### 9.4 排行榜接口

#### GET /api/v1/rankings/global
获取全球排行榜

**查询参数**：
```
season=2026-05    # 可选，默认当前赛季
page=1            # 可选，默认1
limit=20          # 可选，默认20，最大100
```

**响应 200**：
```json
{
  "code": 0,
  "data": {
    "items": [
      {
        "rank": 1,
        "user_id": 10001,
        "nickname": "肠道长老王",
        "avatar_url": "https://...",
        "score": 8990.5,
        "rank_title": "钻石所长",
        "is_anonymous": false
      }
    ],
    "total": 15420,
    "page": 1,
    "limit": 20,
    "total_pages": 771,
    "my_rank": {
      "rank": 156,
      "score": 5244.9,
      "rank_title": "铂金肠王"
    }
  }
}
```

#### GET /api/v1/rankings/city
获取同城排行榜

**查询参数**：
```
city_code=510100  # 必填
season=2026-05
page=1
limit=20
```

#### GET /api/v1/rankings/friends
获取好友排行榜

**查询参数**：
```
season=2026-05
```

**响应**：好友列表按积分排序

### 9.5 备份接口

#### POST /api/v1/backup
上传备份文件

**请求头**：
```
Authorization: Bearer <token>
Content-Type: multipart/form-data
```

**请求体**：
```
file: <binary>
```

**响应 201**：
```json
{
  "code": 0,
  "data": {
    "backup_id": 123,
    "file_key": "backups/10001/20260510_165400.enc",
    "file_size": 1024000,
    "checksum": "sha256:abc123...",
    "download_url": "https://oss.example.com/...",
    "expires_at": "2026-06-10T16:54:00Z"
  }
}
```

#### GET /api/v1/backup/list
获取备份列表

**响应 200**：
```json
{
  "code": 0,
  "data": {
    "backups": [
      {
        "id": 123,
        "file_size": 1024000,
        "checksum": "sha256:abc123...",
        "created_at": "2026-05-10T16:54:00Z",
        "expires_at": "2026-06-10T16:54:00Z"
      }
    ]
  }
}
```

#### GET /api/v1/backup/:id/download
获取下载链接

**响应 302**：重定向至预签名 URL（有效期5分钟）

### 9.6 WebSocket 接口

#### WS /ws/rankings?token={jwt}
建立 WebSocket 连接

**连接后心跳**：
```json
// 客户端每30秒发送
{ "type": "ping", "timestamp": 1715328000 }

// 服务端响应
{ "type": "pong", "timestamp": 1715328000 }
```

**服务端推送消息类型**：

```json
// 1. 排名变化
{
  "type": "rank_update",
  "season": "2026-05",
  "payload": {
    "new_rank": 155,
    "old_rank": 160,
    "score_delta": 14.9,
    "message": "排名上升 5 位！"
  }
}

// 2. 好友超越
{
  "type": "friend_surpass",
  "payload": {
    "friend_nickname": "肠道小张",
    "friend_rank": 154,
    "your_rank": 155,
    "message": "肠道小张超越了您！"
  }
}

// 3. 成就解锁
{
  "type": "achievement_unlock",
  "payload": {
    "achievement_id": "morning_7",
    "achievement_name": "晨便达人",
    "icon": "🌅"
  }
}

// 4. 赛季切换
{
  "type": "season_change",
  "payload": {
    "new_season": "2026-06",
    "last_season": "2026-05",
    "last_rank": "钻石所长",
    "last_score": 8500
  }
}
```

---

## 十、安全与合规

### 10.1 数据安全矩阵

| 数据类型 | 存储位置 | 加密方式 | 传输方式 | 服务端可见性 |
|---------|---------|---------|---------|------------|
| 原始如厕记录 | 本地 SQLite | AES-256 | 不上传 | ❌ 不可见 |
| 三围数据 | 本地 SQLite | AES-256 | 不上传 | ❌ 不可见 |
| API Key | Keychain/Keystore | 系统级 | 直调厂商 | ❌ 不可见 |
| 积分流水 | PostgreSQL | TLS传输中加密 | HTTPS | ✅ 可见（审计） |
| 用户昵称 | PostgreSQL | TLS | HTTPS | ✅ 可见 |
| 城市编码 | PostgreSQL | TLS | HTTPS | ✅ 可见（模糊） |
| 备份文件 | 对象存储 | 客户端AES-256 | HTTPS | ⚠️ 加密 blob |
| 积分乘数 | PostgreSQL | TLS | HTTPS | ✅ 可见 |

### 10.2 隐私政策要点

1. **数据最小化**：服务端仅存储运行排行榜所必需的最少数据。
2. **本地优先**：所有敏感原始数据（如厕时间、地点、颜色、三围）仅存储在用户设备上。
3. **用户控制**：用户可随时导出、删除自己的全部数据。
4. **AI 隐私**：大模型分析完全在客户端进行，服务端不触碰用户数据。
5. **第三方**：除用户自行配置的大模型厂商外，不向任何第三方共享数据。

### 10.3 医疗免责声明

```text
「拉了么」提供的所有健康分析、建议和评分仅供信息参考和娱乐目的，
不能替代专业医疗诊断、治疗或建议。如果您有任何健康疑虑，特别是：
- 持续便秘超过5天
- 持续腹泻超过3天
- 发现血便或黑便
- 严重腹痛伴随排便异常

请立即咨询专业医疗人员。
```

### 10.4 App Store 审核合规

- **应用分类**：Health & Fitness（健康健美）
- **年龄分级**：12+（包含轻微粗俗幽默）
- **元数据策略**：
  - 应用名称：「拉了么 - 肠道健康助手」
  - 副标题：「记录习惯，科学关爱肠道」
  - 描述中强调健康管理属性，弱化娱乐排名
- **截图策略**：展示统计图表、健康建议，避免过度展示便便 emoji
- **审核备注**：说明数据本地存储、隐私保护措施、医疗免责声明

---

## 十一、部署架构

### 11.1 Docker Compose 开发环境

```yaml
version: '3.8'

services:
  api:
    build:
      context: .
      dockerfile: docker/Dockerfile
    ports:
      - "8080:8080"
    environment:
      - DB_HOST=postgres
      - DB_PORT=5432
      - DB_USER=la-le-me
      - DB_PASSWORD=dev_password
      - DB_NAME=la-le-me
      - REDIS_HOST=redis
      - REDIS_PORT=6379
      - JWT_SECRET=dev_secret_change_in_prod
      - MINIO_ENDPOINT=minio:9000
    depends_on:
      - postgres
      - redis
      - minio
    restart: unless-stopped

  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_USER: la-le-me
      POSTGRES_PASSWORD: dev_password
      POSTGRES_DB: la-le-me
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./scripts/init.sql:/docker-entrypoint-initdb.d/init.sql
    ports:
      - "5432:5432"
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    restart: unless-stopped

  minio:
    image: minio/minio:latest
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: minioadmin
      MINIO_ROOT_PASSWORD: minioadmin
    volumes:
      - minio_data:/data
    ports:
      - "9000:9000"
      - "9001:9001"
    restart: unless-stopped

  prometheus:
    image: prom/prometheus:latest
    volumes:
      - ./docker/prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    ports:
      - "9090:9090"

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    volumes:
      - grafana_data:/var/lib/grafana

volumes:
  postgres_data:
  redis_data:
  minio_data:
  prometheus_data:
  grafana_data:
```

### 11.2 生产环境 Kubernetes 部署

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: la-le-me-api
  namespace: production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: la-le-me-api
  template:
    metadata:
      labels:
        app: la-le-me-api
    spec:
      containers:
      - name: api
        image: registry.example.com/la-le-me/api:v1.2.0
        ports:
        - containerPort: 8080
        env:
        - name: DB_HOST
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: host
        - name: JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: api-secrets
              key: jwt-secret
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: la-le-me-api-service
spec:
  selector:
    app: la-le-me-api
  ports:
  - port: 80
    targetPort: 8080
  type: ClusterIP
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: la-le-me-ingress
  annotations:
    nginx.ingress.kubernetes.io/rate-limit: "100"
spec:
  tls:
  - hosts:
    - api.la-le-me.app
    secretName: la-le-me-tls
  rules:
  - host: api.la-le-me.app
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: la-le-me-api-service
            port:
              number: 80
```

### 11.3 Android APK 构建脚本

项目根目录提供了 `build_apk.sh` 一键构建脚本：

```bash
#!/bin/bash
set -e

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
ANDROID_HOME="${PROJECT_ROOT}/android-sdk"
JAVA_HOME="/opt/homebrew/opt/openjdk@17"
FLUTTER_BIN="/opt/homebrew/opt/flutter/bin"
DIST_DIR="${PROJECT_ROOT}/dist"

export ANDROID_HOME
export JAVA_HOME
export PATH="${FLUTTER_BIN}:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${PATH}"

cd "${PROJECT_ROOT}/la-le-me-app"
flutter pub get
flutter build apk --release

mkdir -p "${DIST_DIR}"
cp build/app/outputs/flutter-apk/app-release.apk "${DIST_DIR}/la-le-me-app-release.apk"
```

| 步骤 | 操作 |
|------|------|
| 1 | 自动设置 `ANDROID_HOME`、`JAVA_HOME`、Flutter 等环境变量 |
| 2 | `flutter pub get` 安装依赖 |
| 3 | `flutter build apk --release` 构建 Release APK |
| 4 | 复制 APK 到 `dist/la-le-me-app-release.apk` |

使用方法：
```bash
./build_apk.sh
```

构建产物：
- 输出路径：`dist/la-le-me-app-release.apk`
- 签名证书：`CN=kaptree, RSA 2048-bit`
- 签名方案：APK Signature Scheme v2

---

## 十二、开发里程碑

| 阶段 | 周期 | 交付物 | 验收标准 |
|------|------|--------|---------|
| **MVP 0.1** | 2 周 | 本地记录 + 首页 UI + SQLite | 可记录大小号，展示今日次数 |
| **MVP 0.2** | 1 周 | 统计模块 + 图表 | 周/月/年统计可查看，规律指数计算正确 |
| **MVP 0.3** | 1 周 | 积分体系 + 段位 | 本地积分计算准确，段位晋升逻辑正确 |
| **Beta 1.0** | 2 周 | 后端服务 + 注册登录 + 积分上报 | 服务端可接收积分，全球榜可查看 |
| **Beta 1.1** | 1 周 | 好友系统 + 同城榜 + WebSocket | 实时排名推送正常，好友添加流程通畅 |
| **Beta 1.2** | 1 周 | AI 分析模块 | 支持 DeepSeek/OpenAI，Prompt 输出正确 JSON |
| **Beta 1.3** | 1 周 | 设置模块 + 生物识别 + 备份 | 指纹解锁正常，备份加密/恢复流程完整 |
| **RC 2.0** | 2 周 | 防作弊 + 压测 + 安全审计 | 作弊检测准确率>95%，QPS 1000+，无高危漏洞 |
| **Release** | 1 周 | 上架准备 | 通过 App Store / 应用宝审核 |

---

## 十三、错误码定义

| 错误码 | 名称 | 说明 | HTTP 状态 |
|--------|------|------|----------|
| 0 | Success | 成功 | 200 |
| 1 | UnknownError | 未知错误 | 500 |
| 100 | InvalidParams | 参数错误 | 400 |
| 101 | Unauthorized | 未认证 | 401 |
| 102 | Forbidden | 无权限 | 403 |
| 103 | NotFound | 资源不存在 | 404 |
| 104 | RateLimited | 请求过于频繁 | 429 |
| 200 | TokenExpired | Token 已过期 | 401 |
| 201 | TokenInvalid | Token 无效 | 401 |
| 300 | UserNotFound | 用户不存在 | 404 |
| 301 | NicknameInvalid | 昵称不合法 | 400 |
| 400 | ScoreMismatch | 积分计算不一致 | 400 |
| 401 | CheatDetected | 检测到作弊行为 | 400 |
| 402 | SeasonEnded | 赛季已结束 | 400 |
| 500 | DBError | 数据库错误 | 500 |
| 501 | RedisError | 缓存错误 | 500 |
| 600 | BackupNotFound | 备份不存在 | 404 |
| 601 | BackupExpired | 备份已过期 | 400 |
| 700 | WSAuthFailed | WebSocket 认证失败 | 400 |

---

---

## 十四、开发进度记录

### 2026-05-14 超时提醒弹窗功能

#### 新增功能 — ✅ 已实现

| 功能 | 说明 | 实现文件 |
|------|------|---------|
| ⏰ 小号超时提醒 | 检测距上次小号超过配置阈值(默认4小时)时弹窗提醒喝水 | `reminder_service.dart` + `reminder_dialog.dart` |
| 💩 大号超时提醒 | 检测距上次大号超过配置天数(默认2天)时弹窗提醒膳食纤维 | `reminder_service.dart` + `reminder_dialog.dart` |
| ⚙️ 提醒阈值配置 | 设置页新增小号/大号提醒开关及阈值选择器（SimpleDialog） | `settings_page.dart` |
| 🔗 应用集成 | 启动时、快速记录后、详细记录后三处触发检查 | `home_page.dart` |

**实现细节：**
- `ReminderService.checkReminders()` 静态方法：读取 `AppSettings` 配置 → 查询最后一次小号/大号记录时间 → 与当前时间比较 → 返回 `ReminderCheckResult`
- `ReminderDialog.show()` 静态方法：构建 `AlertDialog` 弹窗，包含彩色信息卡片（💧蓝色/💩棕色），提供「知道了」关闭和「去记录」跳转两个操作
- `AppSettings` 新增 4 个字段：`smallReminderEnabled`（默认true）、`smallReminderHours`（默认4）、`bigReminderEnabled`（默认true）、`bigReminderDays`（默认2）
- 阈值配置通过 `SimpleDialog` + checkmark 选择，小号支持 2/3/4/5/6 小时，大号支持 1/2/3/4/5 天
- 所有持久化通过 `SharedPreferences` 实现，与现有 settings 架构一致
- 提醒在每次记录保存后触发，记录更新（小号/大号）会使对应的计时器重置

#### 新增文件清单

| 文件 | 说明 |
|------|------|
| `lib/services/reminder_service.dart` | 超时提醒检测服务 |
| `lib/widgets/reminder_dialog.dart` | 超时提醒弹窗组件 |

#### 测验结果
- `flutter analyze`：✅ 0 issues
- APK 构建：✅ Dart 编译通过（macOS 环境无 Android SDK，完整 APK 待 Android 环境构建验证）

### 2026-05-14 成就系统全面修复（Bug 修复 + 功能补全）

#### Bug 修复 — ✅ 已修复

| Bug | 原因 | 修复方案 |
|-----|------|---------|
| 🐛 里程碑成就无法解锁 | `checkAndUnlock` 仅加载 30 天历史 → `first_50`/`first_100` 等永远达不到 | 改为从数据库加载全部记录 `DatabaseService.getRecords()` |
| 🐛 大部分成就进度恒为 0/1 | `_calcProgress` 只覆盖约 20 个成就的 switch case | 补全全部 102 个成就的进度计算逻辑 |
| 🐛 61 个成就定义存在但检测未实现 | 社交类、收藏家类、特殊日期类等成就的检测逻辑为空 | 为所有成就补全检测辅助方法 |

#### 功能补全 — ✅ 已实现

**已补全的成就类别及检测逻辑：**

| 类别 | 成就数 | 检测方式 |
|------|--------|---------|
| 里程碑（次数） | 7（first_big ~ first_1000） | 记录总数计数 |
| 里程碑（首达） | 6（first_bristol / _paid / _morning / _weekend / _achievement / _share） | 单次事件检测 |
| 规律健康（晨便） | 5（morning_7 ~ hour_all） | 时间槽/星期几/月份/时段覆盖统计 |
| 规律健康（连续） | 4（streak_7 ~ no_skip_30） | 连续天数/无中断天数计算 |
| 健康指标（布里斯托） | 13（perfect_bristol ~ hydration） | 分型比例/分布/连续性/时段/颜色/顺畅度分析 |
| 健康指标（评级） | 2（health_a_7 / _30） | 月度 A 级连续天数检测 |
| 趣味挑战（带薪） | 3（paid_pooper ~ marathon_1h） | 带薪次数/总时长/单次时长 |
| 趣味挑战（时间） | 5（week_warrior ~ gamer） | 周末/夜猫/双杀/打卡/游戏时间检测 |
| 趣味挑战（场景） | 8（holiday_pooper ~ gas_station） | 笔记关键词/城市匹配/特殊地点/节假日检测 |
| 趣味挑战（特殊） | 2（birthday_pooper / new_year） | 生日/新年日期匹配 |
| 趣味挑战（打卡） | 8（mood_* / all_moods / color_all / duration_all） | 心情/颜色/时长分布统计 |
| 收藏家 | 4（location_5 ~ achievement_all） | 地点/天气/月相/日期特殊性/成就数 |
| 特殊日期 | 5（rainy_day ~ leap_day） | 笔记关键词/月相/13号星期五/闰日 |
| 积分段位 | 3（score_500 / _2000 / _10000） | 赛季积分查询 `_getCurrentSeasonScore()` |
| 社交（分享） | 0（first_share） | 依赖分享功能，预留接口 |

#### 新增辅助方法清单

| 方法 | 用途 |
|------|------|
| `_countMorningDays()` | 统计晨便天数（6:00-9:00） |
| `_timeSlotStreak()` | 指定时间段内连续天数计算 |
| `_checkSameTime7()` / `_countSameTimeStreak()` | 同一半小时间隔出现 7 次/计数 |
| `_checkWeekendRegular()` / `_countWeekendRegular()` | 周末记录天数检测/计数 |
| `_checkMidnight3()` / `_midnightConsecutive()` | 凌晨连续天数检测/计数 |
| `_checkNoSkip30()` / `_countNoSkipStreak()` | 30 天无中断检测/连续天数 |
| `_checkBristolGold()` / `_checkBristolAll()` | 黄金比例 70% 3-4 型 / 集齐 7 种分型 |
| `_checkFiberRich()` / `_checkFiberStreak()` | 3 天/指定天数连续 3-4 型 |
| `_checkBristolConsecutive()` / `_countBristolConsecutive()` | 连续指定分型天数 |
| `_checkNoBadBristol()` / `_countNoBadBristolStreak()` | 无 1/2/6/7 型连续天数 |
| `_checkGolden30()` / `_countGoldenStreak()` | 30 天黄金分型连续 |
| `_checkBalanced()` | 3 型 4 型均 ≥20 次 |
| `_checkComeback()` | 间隔 5 天以上后恢复记录 |
| `_checkDurationPerfect()` | 连续 7 次 3-8 分钟 |
| `_checkBrownOnly()` | 连续 20 次颜色=1（棕色） |
| `_checkHydration()` | 连续 7 天顺畅度≥4 |
| `_checkHealthAConsecutive()` / `_countHealthAConsecutive()` | 连续 A 级评级 |
| `_checkPaidKing()` | 50 次带薪 + 总时长≥5 小时 |
| `_checkSpeedKing()` | 5 次 1-3 分钟 |
| `_checkMarathon()` | 单次≥15 分钟 |
| `_checkWeekendWarrior()` | 周末同日大小号≥4 天 |
| `_checkMoodRecorder()` | 5 种不同心情 |
| `_checkNightOwl()` | 凌晨 0-5 点≥3 次 |
| `_checkDoubleKill()` | 同日大小号 |
| `_checkNoteKeyword()` / `_countNoteKeyword()` | 笔记关键词匹配/计数 |
| `_checkNoteThought()` / `_countThoughtRecords()` | 长笔记（>30 字）检测/计数 |
| `_checkHolidayStreak()` / `_countHolidayStreak()` | 节假日连续记录 |
| `_extractCity()` | 从笔记/位置提取城市名 |
| `_countLocationType()` / `_countDistinctLocations()` | 按类别统计地点/去重 |
| `_noteContains()` | 笔记关键词匹配 |
| `_checkDateMatch()` | 日期条件匹配 |
| `_checkColorAll()` / `_checkDurationAll()` | 颜色 5 种/时长 3 种全收集 |
| `_countLocationCategories()` | 地点去重计数 |
| `_isFullMoonDay()` | 满月日判定（含 2024-2025 年满月日历） |
| `_getCurrentSeasonScore()` | 当前赛季积分查询 |
| `getUnlockedCount()` / `getTotalCount()` | 已解锁/总数查询（供 stats_page 使用） |

#### 测验结果
- `flutter analyze`：✅ 0 errors, 0 warnings（仅 4 个 info lint 为预存在）
- 成就覆盖率：88 个成就定义 → 102 个成就完整检测逻辑

### 2026-05-14 紧急 Bug 修复（日期格式 + 页面刷新）

**Bug 1：** 成就页 `FormatException: invalid date format` 崩溃 — 新增 `_dateKey()` helper 零补全日期，替换 17 处日期拼接  
**Bug 2：** 添加记录后页面不刷新 &mdash; `checkAndUnlock` 包裹 try-catch 保证后续 `_refreshData()`/SnackBar 正常执行  
**验证：** `flutter analyze` 0 errors, 0 warnings

### 2026-05-14 月度统计评级 Bug 修复

**Bug：** 月度统计评级始终 D 级 — `_daysInMonth()` 依赖列表顺序取起止时间，数据库 DESC 排序导致 `frequencyScore=0`，改写为显式时间戳排序。  
**验证：** `flutter analyze` 0 errors, 0 warnings

### 2026-05-13 首页优化与统计增强

#### 首页功能优化 — ✅ 已实现

| 功能 | 说明 | 实现文件 |
|------|------|---------|
| 📈 小号趋势曲线 | 首页出库趋势图新增绿色小号线（Color 0xFF66BB6A）展示每日小号趋势 | `home_page.dart` + `record_provider.dart` |
| ⭐ 历史总次数 | 首页「次叔」卡片改为统计从开始到现在的全部记录总数（`getTotalRecordCount()`） | `home_page.dart` + `record_provider.dart` |
| ❤️ 智能健康状态 | 首页状态卡片基于今日+7天记录科学判定，支持9种动态状态（模范标兵/肠道畅通/运转正常/等待出库/稍需留意/便秘警报/频率偏高/频率异常/数据收集中） | `home_page.dart` + `regularity_calculator.dart` |

**实现细节：**
- `FiveDayStats` 新增 `List<int> smallCounts` 字段，Provider 中计算每日小号次数
- 趋势图由双线（大号+总计）升级为三线（大号+小号+总计），图例同步更新
- `totalRecordCountProvider` 独立 FutureProvider，调用 `DatabaseService.getTotalRecordCount()` 获取历史总记录数
- `HomeHealthStatusCalculator` 综合评估：最近大号间隔、7天规律指数、布里斯托质量、时长质量，按严重度分级

#### 月度统计日历优化 — ✅ 已实现

| 功能 | 说明 | 实现文件 |
|------|------|---------|
| 💩 Emoji 标记 | 月度统计日历中有出库记录的日期用 💩 标记替代棕色热力图 | `stats_pages.dart` |

**实现细节：**
- 当天有记录（count > 0）：显示 💩（15sp）+ 日期数字（9sp, 棕色粗体）
- 当天无记录（count == 0）：灰色圆形背景 + 日期数字（11sp, 灰色）
- 移除原有的 `getHeatColor()` 棕色热力映射逻辑

#### 工作时间段智能判定 — ✅ 已实现

| 功能 | 说明 | 实现文件 |
|------|------|---------|
| 🕘 工作时间段配置 | 个人档案页新增上班/下班时间选择器，默认基于年龄（22岁以下08-18点，23岁以上09-18点） | `profile_page.dart` + `profile_model.dart` |
| 🤖 自动带薪判定 | 移除手动「工作时间」「💰 带薪」开关，根据档案工作时间段自动判定（周一至周五有效） | `record_detail_page.dart` + `home_page.dart` |
| 📦 数据库迁移 | `user_profile` 表新增 `work_start_hour`/`work_end_hour` 列，v3 迁移平滑升级 | `database_service.dart` |

**实现细节：**
- `ProfileModel` 新增 `workStartHour`/`workEndHour` 字段 + `age` getter + `defaultWorkStartHour`/`defaultWorkEndHour` 智能默认值
- 出生年份变更时自动应用年龄段默认工作时间（`_applyAgeDefault()`）
- `AppUtils` 新增 `isWorkHoursForTime(dt, startHour, endHour)` 方法，支持传入自定义工作时间段
- 详细记录页移除手动开关，改为显示「当前为工作时间 / 当前非工作时间」信息卡片
- 快速记录和详细记录均根据档案工作时间段自动设置 `isPaidPoop = isWorkTime`
- 背包曲线兼容：`ScoreCalculator._calculatePaid()` 读取自动设置的 P 因子，无需修改计算逻辑

### 2026-05-12 安全设置与时间轴完成

#### 安全设置模块 — ✅ 已实现

| 功能 | 说明 | 实现文件 |
|------|------|---------|
| 🔐 生物识别应用锁 | 指纹/面部识别锁定应用，后台切换自动锁定 | `security_service.dart` + `lock_screen.dart` |
| 👁️ 隐私模式 | FLAG_SECURE 隐藏最近任务与截图内容 | `security_service.dart` + `MainActivity.kt` |
| ⚙️ 安全设置页面 | 开关控制 + 生物识别测试按钮 + 说明提示 | `security_page.dart` |

**实现细节：**
- `AppLockWrapper` 通过 `WidgetsBindingObserver` 监听 `AppLifecycleState`
- 应用切换到后台时自动设置锁定标记，恢复前台时弹出生物识别认证
- 认证使用 `local_auth` 包的 `biometricOnly: true` 模式，仅接受指纹/面部
- 隐私模式通过 `MethodChannel` 调用原生 `WindowManager.LayoutParams.FLAG_SECURE`

#### 时间轴模块 — ✅ 已实现

| 功能 | 说明 |
|------|------|
| 🕐 记录时间轴 | 数据 Tab 顶部入口，按日期分组显示全部记录 |
| 🗑️ 滑动删除 | Dismissible 左滑手势 + 确认对话框防误删 |
| 🔄 实时刷新 | 删除后自动触发全局 refreshTriggerProvider |

#### 其他完成项
- ✅ 头像上传功能（image_picker + base64 持久化）
- ✅ 数据刷新机制修复（refreshTriggerProvider 统一刷新）
- ✅ 应用图标替换为 logo.png

#### APK 构建信息
| 项目 | 值 |
|------|------|
| 版本号 | 1.0.4+1 |
| 签名证书 | CN=kaptree, RSA 2048-bit |

### 2026-05-11 开发进度更新

#### 里程碑
- ✅ **Release APK 构建成功** (59MB, kaptree 正式签名)
- ✅ **GitHub 代码同步** (https://github.com/MangataTS/WcRemark)
- ✅ **Android 签名配置** — RSA 2048-bit, 有效期 10000 天
- ✅ **Flutter SDK 3.38.5 环境就绪**
- ✅ **首页近5天出库曲线图** — fl_chart 三线折线图（大号+小号+总计，v1.0.5 升级）
- ✅ **记录详情页优化** — 按钮黑色字体 + 底部提交按钮
- ✅ **个人档案页优化** — 底部保存按钮
- ✅ **新增服务器配置页** — 手动填写地址 + 健康检查 + 连接测试

#### 后端 (Go/Gin) — ✅ 已完成基础架构

**已创建文件清单**：

| 文件 | 说明 |
|------|------|
| `cmd/server/main.go` | 服务入口，路由注册，优雅关闭 |
| `internal/config/config.go` | 环境变量配置加载 |
| `internal/model/user.go` | 用户模型 |
| `internal/model/score_log.go` | 积分流水模型 |
| `internal/model/season.go` | 赛季模型 |
| `internal/model/achievement.go` | 成就模型 |
| `internal/model/friend.go` | 好友关系模型 |
| `internal/model/backup.go` | 备份模型 |
| `internal/model/api_config.go` | API 配置模型 |
| `internal/model/migrate.go` | 数据库自动迁移 |
| `internal/handler/handlers.go` | 所有 HTTP Handler（Auth/User/Record/Ranking/Backup） |
| `internal/handler/ws_hub.go` | WebSocket Hub 与 Client |
| `internal/handler/ws_handler.go` | WebSocket Handler |
| `internal/middleware/jwt_auth.go` | JWT 认证中间件 |
| `internal/middleware/rate_limit.go` | Redis 限流中间件 |
| `internal/middleware/cors.go` | CORS 跨域中间件 |
| `internal/repository/user_repo.go` | 用户数据访问层 |
| `internal/repository/score_repo.go` | 积分数据访问层 |
| `internal/repository/redis_repo.go` | Redis 排行榜操作 |
| `internal/service/auth_service.go` | 认证服务（注册/登录/刷新Token） |
| `internal/service/score_service.go` | 积分结算核心逻辑 |
| `internal/service/ranking_service.go` | 排行榜查询服务 |
| `internal/service/anti_cheat_service.go` | 反作弊检测服务 |
| `internal/service/backup_service.go` | 备份管理服务 |
| `internal/util/jwt.go` | JWT 工具（Generate/Parse/Claims） |
| `internal/util/response.go` | 统一响应工具 |
| `pkg/errors/errors.go` | 业务错误码与 HTTP 状态映射 |
| `docker/docker-compose.yml` | 开发环境编排（PG/Redis/MinIO/Prom/Grafana） |
| `docker/Dockerfile` | 多阶段 Go 构建 |
| `docker/prometheus.yml` | Prometheus 配置 |
| `config/config.yaml` | 本地开发配置 |
| `Makefile` | 构建/运行/测试命令 |

**编译状态**：✅ `go build ./...` 编译通过

#### Flutter 客户端 — ✅ 已完成基础架构

**已创建文件清单**：

| 文件 | 说明 |
|------|------|
| `pubspec.yaml` | 项目配置与依赖声明 |
| `lib/main.dart` | 应用入口，路由注册 |
| `lib/models/toilet_record.dart` | 如厕记录模型（含 RecordType 枚举） |
| `lib/models/profile_model.dart` | 用户档案模型（含 BMI、腰臀比计算） |
| `lib/models/ranking.dart` | 段位系统与排行榜数据模型 |
| `lib/models/season.dart` | 赛季管理与历史模型 |
| `lib/models/achievement.dart` | 成就定义与查询 |
| `lib/models/score.dart` | 积分乘数与结算结果模型 |
| `lib/providers/record_provider.dart` | 记录状态管理 (Riverpod) |
| `lib/providers/ranking_provider.dart` | 排行榜状态管理 (Riverpod) |
| `lib/services/database_service.dart` | SQLite 数据库服务（CRUD、查询、同步标记） |
| `lib/services/database_factory_io.dart` | 数据库工厂 IO 实现 |
| `lib/services/database_factory_stub.dart` | 数据库工厂 Stub |
| `lib/services/database_factory_web.dart` | 数据库工厂 Web 实现 |
| `lib/services/api_service.dart` | REST API 客户端（Dio + JWT 认证） |
| `lib/services/api_config.dart` | 环境变量配置管理 |
| `lib/services/score_calculator.dart` | 客户端积分计算引擎（R/H/T/P/S/M 六维乘数） |
| `lib/services/regularity_calculator.dart` | 规律指数、健康等级、年度关键词、首页健康状态判定算法 |
| `lib/services/ai_service.dart` | AI 肠道顾问服务（多厂商大模型接入） |
| `lib/services/anomaly_detector.dart` | 异常预警检测（便秘/腹泻/血便） |
| `lib/services/anti_cheat_service.dart` | 客户端反作弊预检 |
| `lib/services/achievement_service.dart` | 成就自动检测与解锁 |
| `lib/services/season_service.dart` | 赛季切换与重置 |
| `lib/services/backup_encryption.dart` | AES-256-GCM 加密/解密 |
| `lib/services/notification_service.dart` | 8 种本地通知类型 |
| `lib/services/settings_service.dart` | 应用偏好设置持久化 |
| `lib/services/reminder_service.dart` | 超时提醒检测服务（v1.0.7 新增） |
| `lib/services/theme_service.dart` | Light/Dark/OLED 主题切换 |
| `lib/screens/main_shell.dart` | 底部 4 Tab 主壳 |
| `lib/screens/home_page.dart` | 首页（问候语、核心卡片、5日趋势三线图、快速记录） |
| `lib/screens/stats_page.dart` | 统计入口页 |
| `lib/screens/stats_pages.dart` | 周/月(💩日历)/年统计页面 |
| `lib/screens/ranking_page.dart` | 排行榜（全球/同城/好友三栏 Tab） |
| `lib/screens/record_detail_page.dart` | 详细记录页面 |
| `lib/screens/settings_page.dart` | 设置主页面 |
| `lib/screens/profile_page.dart` | 个人档案页面（昵称/头像/出生年份/身体数据/工作时间段） |
| `lib/screens/ai_config_page.dart` | AI 配置页面 |
| `lib/screens/security_page.dart` | 安全设置页面 |
| `lib/screens/data_management_page.dart` | 数据管理页面 |
| `lib/screens/backup_page.dart` | 云端备份页面 |
| `lib/screens/server_config_page.dart` | 服务器配置页面 |
| `lib/widgets/reminder_dialog.dart` | 超时提醒弹窗组件（v1.0.7 新增） |
| `lib/utils/app_utils.dart` | 通用工具函数 |
| `lib/utils/theme.dart` | 主题颜色、样式、常量定义 |

**关键算法实现状态**：

| 算法 | 客户端 | 服务端 | 状态 |
|------|--------|--------|------|
| 积分六维乘数计算 (R/H/T/P/S/M) | ✅ score_calculator.dart | ✅ score_service.go | 完整实现 |
| 规律指数（时间标准差+环形展开） | ✅ regularity_calculator.dart | - | 完整实现 |
| 首页健康状态判定 | ✅ regularity_calculator.dart | - | v1.0.5 新增，9种动态状态 |
| 带薪收益计算 | ✅ score_calculator.dart | - | 完整实现 |
| 健康等级评定 | ✅ regularity_calculator.dart | - | 完整实现 |
| 布里斯托分型映射 | ✅ score_calculator.dart | ✅ anti_cheat_service.go | 完整实现 |
| 段位系统 | ✅ ranking.dart | ✅ score_service.go | 完整实现 |
| 反作弊检测 | ✅ anti_cheat_service.dart | ✅ anti_cheat_service.go | 完整实现 |
| AI 数据脱敏聚合 | ✅ ai_service.dart | - | 完整实现 |
| 年度关键词生成 | ✅ regularity_calculator.dart | - | 完整实现 |
| 状态管理 (Riverpod) | ✅ providers/ | - | 完整实现 |
| 通知/提醒系统 | ✅ notification_service.dart + reminder_service.dart | - | 完整实现（含 v1.0.7 超时弹窗） |
| 备份加密/恢复 | ✅ backup_encryption.dart | ✅ backup_service.go | 完整实现 |
| 主题切换 | ✅ theme_service.dart | - | 完整实现 |
| 成就系统 | ✅ achievement_service.dart | ✅ score_service.go | 完整实现 |
| 赛季管理 | ✅ season_service.dart | ✅ score_service.go | 完整实现 |

#### APK 构建信息

| 项目 | 值 |
|------|------|
| 输出文件 | `dist/la-le-me-app-release.apk` |
| 文件大小 | 59 MB |
| 应用 ID | `com.example.la_le_me_app` |
| 版本号 | 1.0.0+1 |
| 签名证书 | CN=kaptree, RSA 2048-bit, SHA256withRSA |
| 签名方案 | APK Signature Scheme v2 |

#### 待开发功能

| 功能 | 优先级 | 说明 |
|------|--------|------|
| 头像选择与裁剪 | 低 | 品牌视觉资产 |
| 同城排行榜完整实现 | 中 | 需补充城市定位逻辑 |
| 好友排行榜 | 中 | 需补充好友关系管理 |
| 趣味排行榜 | 低 | 6 种趣味维度排行 |
| 云端数据同步 | 中 | 需要服务端配合 |
| 推送通知集成 (Firebase/APNs) | 中 | 需要配置 Firebase 项目 |
| iOS 真机构建与上架 | 中 | 需要 Apple Developer 账号 |
| E2E 测试覆盖 | 高 | 关键流程端到端测试 |
| CI/CD 流水线 | 中 | 自动化构建与发布 |

#### 已解决问题

| 问题 | 状态 | 解决方案 |
|------|------|---------|
| `getCurrentSeasonStr` 不可见 | ✅ 已修复 | 改为导出函数 `GetCurrentSeason()` |
| Claims 结构体位置冲突 | ✅ 已修复 | 统一使用 `util.Claims` |
| Flutter SDK 未安装 | ✅ 已解决 | 安装 Flutter 3.38.5 (Homebrew) |
| Java JDK 未安装 | ✅ 已解决 | 安装 OpenJDK 17 (Homebrew) |
| Android SDK 未配置 | ✅ 已解决 | 手动安装 cmdline-tools + platforms/build-tools |
| `intl` 依赖本地化问题 | ✅ 已解决 | `flutter pub get` 正常解析 |
| GitHub 推送大文件被拒 | ✅ 已解决 | `.gitignore` 排除 `android-sdk/` 和 `dist/` |

*文档结束 — 由「拉了么」产品团队编制*
