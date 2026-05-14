import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../utils/app_utils.dart';

class RecordDetailPage extends StatefulWidget {
  const RecordDetailPage({super.key});

  @override
  State<RecordDetailPage> createState() => _RecordDetailPageState();
}

class _RecordDetailPageState extends State<RecordDetailPage> {
  int _selectedType = 1; // 0: small, 1: big
  int? _selectedDuration;
  int? _selectedBristolType;
  int _smoothness = 3;
  final _noteController = TextEditingController();
  String _selectedMood = '😊';
  bool _isWorkTime = false;
  int _workStartHour = 9;
  int _workEndHour = 18;
  bool _isLoading = true;

  final List<String> _moodOptions = ['😊', '😌', '😤', '😩', '🤢', '😄', '😎'];

  final List<Map<String, dynamic>> _durationOptions = [
    {'label': '<1分钟', 'seconds': 30},
    {'label': '1-3分钟', 'seconds': 120},
    {'label': '3-8分钟', 'seconds': 330},
    {'label': '8-15分钟', 'seconds': 690},
    {'label': '>15分钟', 'seconds': 1200},
  ];

  @override
  void initState() {
    super.initState();
    _loadWorkSettings();
  }

  Future<void> _loadWorkSettings() async {
    final profile = await DatabaseService.getProfile();
    if (mounted) {
      final start = profile.workStartHour ?? profile.defaultWorkStartHour;
      final end = profile.workEndHour ?? profile.defaultWorkEndHour;
      final now = DateTime.now();
      final isWork = AppUtils.isWorkHoursForTime(now, start, end);
      setState(() {
        _workStartHour = start;
        _workEndHour = end;
        _isWorkTime = isWork;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('详细记录'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('保存',
                style: TextStyle(fontSize: 16, color: Colors.black)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTypeSelector(),
            const SizedBox(height: 24),
            if (_selectedType == 1) ...[
              _buildDurationSelector(),
              const SizedBox(height: 24),
              _buildBristolSelector(),
              const SizedBox(height: 24),
            ],
            _buildSmoothnessSlider(),
            const SizedBox(height: 24),
            _buildWorkTimeInfo(),
            const SizedBox(height: 24),
            _buildMoodSelector(),
            const SizedBox(height: 24),
            _buildNoteField(),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF795548),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
                child: const Text('提交记录',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('类型',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label:
                    const Text('💧 小号', style: TextStyle(color: Colors.black)),
                selected: _selectedType == 0,
                onSelected: (_) => setState(() => _selectedType = 0),
                selectedColor: Colors.blue.shade100,
                backgroundColor: Colors.grey.shade100,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ChoiceChip(
                label:
                    const Text('💩 大号', style: TextStyle(color: Colors.black)),
                selected: _selectedType == 1,
                onSelected: (_) => setState(() => _selectedType = 1),
                selectedColor: Colors.brown.shade100,
                backgroundColor: Colors.grey.shade100,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDurationSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('时长',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _durationOptions.map((opt) {
            int index = _durationOptions.indexOf(opt);
            return ChoiceChip(
              label: Text(opt['label'] as String,
                  style: const TextStyle(color: Colors.black)),
              selected: _selectedDuration == index,
              onSelected: (_) => setState(() => _selectedDuration = index),
              selectedColor: const Color(0xFFD4A574).withValues(alpha: 0.3),
              backgroundColor: Colors.grey.shade100,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildBristolSelector() {
    final bristolLabels = {
      1: '1型: 硬球状',
      2: '2型: 腊肠状块',
      3: '3型: 腊肠裂纹',
      4: '4型: 光滑软便',
      5: '5型: 软团块',
      6: '6型: 糊状',
      7: '7型: 水样',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('布里斯托分型',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: bristolLabels.entries.map((e) {
            return ChoiceChip(
              label: Text(e.value,
                  style: const TextStyle(fontSize: 12, color: Colors.black)),
              selected: _selectedBristolType == e.key,
              onSelected: (_) => setState(() => _selectedBristolType = e.key),
              selectedColor: const Color(0xFFD4A574).withValues(alpha: 0.3),
              backgroundColor: Colors.grey.shade100,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSmoothnessSlider() {
    const labels = ['很费劲', '略费劲', '正常', '通畅', '一泻千里'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('顺畅度',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: labels
              .map((l) => Text(l,
                  style:
                      const TextStyle(fontSize: 10, color: Color(0xFF999999))))
              .toList(),
        ),
        Slider(
          value: _smoothness.toDouble(),
          min: 1,
          max: 5,
          divisions: 4,
          activeColor: const Color(0xFF795548),
          onChanged: (v) => setState(() => _smoothness = v.toInt()),
        ),
      ],
    );
  }

  Widget _buildWorkTimeInfo() {
    final startLabel = '${_workStartHour.toString().padLeft(2, '0')}:00';
    final endLabel = '${_workEndHour.toString().padLeft(2, '0')}:00';
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(
              child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              _isWorkTime ? Icons.work : Icons.nightlight_round,
              color: _isWorkTime ? const Color(0xFF4CAF50) : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isWorkTime ? '当前为工作时间' : '当前非工作时间',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color:
                          _isWorkTime ? const Color(0xFF4CAF50) : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '工作时间段：周一至周五 $startLabel - $endLabel',
                    style:
                        const TextStyle(fontSize: 12, color: Color(0xFF999999)),
                  ),
                ],
              ),
            ),
            if (_isWorkTime)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('💰 带薪',
                    style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF4CAF50),
                        fontWeight: FontWeight.w600)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoodSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('心情',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: _moodOptions.map((mood) {
            return GestureDetector(
              onTap: () => setState(() => _selectedMood = mood),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _selectedMood == mood
                      ? const Color(0xFFD4A574).withValues(alpha: 0.3)
                      : Colors.transparent,
                  border: _selectedMood == mood
                      ? Border.all(color: const Color(0xFF795548), width: 2)
                      : null,
                ),
                child: Center(
                  child: Text(mood, style: const TextStyle(fontSize: 24)),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildNoteField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('备注（选填）',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _noteController,
          maxLines: 3,
          maxLength: 200,
          decoration: InputDecoration(
            hintText: '记录更多细节...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: const Color(0xFFF7F7F7),
          ),
        ),
      ],
    );
  }

  void _save() {
    final record = <String, dynamic>{
      'type': _selectedType,
      'duration': _selectedDuration != null
          ? _durationOptions[_selectedDuration!]['seconds']
          : null,
      'bristol_type': _selectedBristolType,
      'smoothness': _smoothness,
      'is_work_hours': _isWorkTime,
      'is_paid_poop': _isWorkTime,
      'mood': _selectedMood,
      'note': _noteController.text.isNotEmpty ? _noteController.text : null,
    };

    Navigator.pop(context, record);
  }
}
