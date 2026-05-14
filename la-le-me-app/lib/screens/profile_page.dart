import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/profile_model.dart';
import '../services/database_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _nicknameController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _waistController = TextEditingController();
  Gender _selectedGender = Gender.unknown;
  int? _selectedBirthYear;
  JobType _selectedJobType = JobType.other;
  String? _avatarBase64;
  bool _isLoading = true;
  int _workStartHour = 9;
  int _workEndHour = 18;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await DatabaseService.getProfile();
    if (mounted) {
      setState(() {
        _nicknameController.text = profile.nickname ?? '';
        _selectedGender = profile.gender ?? Gender.unknown;
        _selectedBirthYear = profile.birthYear;
        _heightController.text = profile.heightCm?.toString() ?? '';
        _weightController.text = profile.weightKg?.toString() ?? '';
        _waistController.text = profile.waistCm?.toString() ?? '';
        _selectedJobType = profile.jobType ?? JobType.other;
        _avatarBase64 = profile.avatarBase64;
        _workStartHour = profile.workStartHour ?? profile.defaultWorkStartHour;
        _workEndHour = profile.workEndHour ?? profile.defaultWorkEndHour;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickAvatar() async {
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
              '设置头像',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: Color(0xFF795548)),
              title: const Text('从相册选择'),
              onTap: () {
                Navigator.pop(ctx);
                _pickFromGallery();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined,
                  color: Color(0xFF795548)),
              title: const Text('拍照'),
              onTap: () {
                Navigator.pop(ctx);
                _pickFromCamera();
              },
            ),
            if (_avatarBase64 != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('移除头像', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _avatarBase64 = null);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFromGallery() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() => _avatarBase64 = base64Encode(bytes));
    }
  }

  Future<void> _pickFromCamera() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() => _avatarBase64 = base64Encode(bytes));
    }
  }

  Widget _buildAvatar() {
    Widget avatar;
    if (_avatarBase64 != null) {
      try {
        final bytes = base64Decode(_avatarBase64!);
        avatar = CircleAvatar(
          radius: 48,
          backgroundImage: MemoryImage(bytes),
        );
      } catch (_) {
        avatar = _buildDefaultAvatar();
      }
    } else {
      avatar = _buildDefaultAvatar();
    }

    return avatar;
  }

  Widget _buildDefaultAvatar() {
    return CircleAvatar(
      radius: 48,
      backgroundColor: const Color(0xFFD4A574),
      child: const Icon(Icons.person, size: 48, color: Colors.white),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final genderLabels = ['未知', '男', '女', '其他'];
    final jobLabels = ['久坐办公', '站立为主', '体力劳动', '混合', '其他'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('个人档案'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('保存', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickAvatar,
                child: Stack(
                  children: [
                    _buildAvatar(),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFF795548),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt,
                            size: 20, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nicknameController,
              decoration: const InputDecoration(
                labelText: '昵称',
                hintText: '给自己取个名字吧',
                border: OutlineInputBorder(),
              ),
              maxLength: 16,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Gender>(
              initialValue: _selectedGender,
              decoration: const InputDecoration(
                labelText: '性别',
                border: OutlineInputBorder(),
              ),
              items: Gender.values
                  .map((g) => DropdownMenuItem(
                        value: g,
                        child: Text(genderLabels[g.index]),
                      ))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _selectedGender = v ?? Gender.unknown),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _selectedBirthYear,
              decoration: const InputDecoration(
                labelText: '出生年份',
                border: OutlineInputBorder(),
              ),
              items: List.generate(80, (i) => DateTime.now().year - 18 - i)
                  .map((y) => DropdownMenuItem(value: y, child: Text('$y年')))
                  .toList(),
              onChanged: (v) => setState(() {
                _selectedBirthYear = v;
                _applyAgeDefault();
              }),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _heightController,
                    decoration: const InputDecoration(
                      labelText: '身高 (cm)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _weightController,
                    decoration: const InputDecoration(
                      labelText: '体重 (kg)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _waistController,
              decoration: const InputDecoration(
                labelText: '腰围 (cm)（选填）',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<JobType>(
              initialValue: _selectedJobType,
              decoration: const InputDecoration(
                labelText: '职业类型',
                border: OutlineInputBorder(),
              ),
              items: JobType.values
                  .map((j) => DropdownMenuItem(
                        value: j,
                        child: Text(jobLabels[j.index]),
                      ))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _selectedJobType = v ?? JobType.other),
            ),
            const SizedBox(height: 24),
            _buildWorkTimeSection(),
            const SizedBox(height: 24),
            const Card(
              color: Color(0xFFFFF8E1),
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.security, size: 16, color: Color(0xFFF57C00)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '三围数据仅存储在本地，不会上传到服务器',
                        style:
                            TextStyle(fontSize: 12, color: Color(0xFF795548)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
                child: const Text('保存档案',
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

  Widget _buildWorkTimeSection() {
    final String startLabel = '${_workStartHour.toString().padLeft(2, '0')}:00';
    final String endLabel = '${_workEndHour.toString().padLeft(2, '0')}:00';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.work_outline, size: 18, color: Color(0xFF795548)),
            const SizedBox(width: 8),
            const Text(
              '工作时间段',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Text(
              '默认基于年龄',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '在时间段内的大号记录将自动计为带薪',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildTimeCard(
                icon: Icons.login,
                label: '上班时间',
                time: startLabel,
                onTap: () => _showTimePicker(isStart: true),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child:
                  Icon(Icons.arrow_forward, color: Color(0xFF795548), size: 20),
            ),
            Expanded(
              child: _buildTimeCard(
                icon: Icons.logout,
                label: '下班时间',
                time: endLabel,
                onTap: () => _showTimePicker(isStart: false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '周一至周五有效，22岁以下默认08-18点，23岁以上默认09-18点',
          style: TextStyle(fontSize: 11, color: Colors.grey[400]),
        ),
      ],
    );
  }

  Widget _buildTimeCard({
    required IconData icon,
    required String label,
    required String time,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          border:
              Border.all(color: const Color(0xFFD4A574).withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFFFFF8E1),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF795548)),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(fontSize: 11, color: Color(0xFF999999))),
            const SizedBox(height: 4),
            Text(time,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF795548))),
          ],
        ),
      ),
    );
  }

  Future<void> _showTimePicker({required bool isStart}) async {
    final int currentHour = isStart ? _workStartHour : _workEndHour;
    final int? result = await showDialog<int>(
      context: context,
      builder: (ctx) {
        int selected = currentHour;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isStart ? '选择上班时间' : '选择下班时间'),
              content: SizedBox(
                height: 200,
                child: ListWheelScrollView.useDelegate(
                  itemExtent: 48,
                  diameterRatio: 2.0,
                  controller:
                      FixedExtentScrollController(initialItem: selected),
                  onSelectedItemChanged: (i) {
                    setDialogState(() => selected = i);
                  },
                  childDelegate: ListWheelChildBuilderDelegate(
                    builder: (ctx, i) => Center(
                      child: Text(
                        '${i.toString().padLeft(2, '0')}:00',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: i == selected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: i == selected
                              ? const Color(0xFF795548)
                              : Colors.grey,
                        ),
                      ),
                    ),
                    childCount: 24,
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, selected),
                  child: const Text('确定'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        if (isStart) {
          _workStartHour = result;
        } else {
          _workEndHour = result;
        }
      });
    }
  }

  void _applyAgeDefault() {
    final tempProfile = ProfileModel(birthYear: _selectedBirthYear);
    setState(() {
      _workStartHour = tempProfile.defaultWorkStartHour;
      _workEndHour = tempProfile.defaultWorkEndHour;
    });
  }

  Future<void> _save() async {
    final profile = ProfileModel(
      nickname:
          _nicknameController.text.isEmpty ? null : _nicknameController.text,
      avatarBase64: _avatarBase64,
      gender: _selectedGender,
      birthYear: _selectedBirthYear,
      heightCm: double.tryParse(_heightController.text),
      weightKg: double.tryParse(_weightController.text),
      waistCm: double.tryParse(_waistController.text),
      jobType: _selectedJobType,
      workStartHour: _workStartHour,
      workEndHour: _workEndHour,
    );

    await DatabaseService.saveProfile(profile);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('档案已保存 ✅')),
      );
      Navigator.pop(context);
    }
  }
}
