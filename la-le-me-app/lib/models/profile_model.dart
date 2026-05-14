import 'dart:math';

enum Gender { unknown, male, female, other }

enum JobType { sedentary, standing, physical, mixed, other }

class ProfileModel {
  String? nickname;
  String? avatarBase64;
  Gender? gender;
  int? birthYear;
  double? heightCm;
  double? weightKg;
  double? chestCm;
  double? waistCm;
  double? hipCm;
  JobType? jobType;
  int? workStartHour;
  int? workEndHour;

  ProfileModel({
    this.nickname,
    this.avatarBase64,
    this.gender,
    this.birthYear,
    this.heightCm,
    this.weightKg,
    this.chestCm,
    this.waistCm,
    this.hipCm,
    this.jobType,
    this.workStartHour,
    this.workEndHour,
  });

  double? get bmi {
    if (weightKg != null && heightCm != null && heightCm! > 0) {
      return weightKg! / pow(heightCm! / 100, 2);
    }
    return null;
  }

  String? get bmiCategory {
    if (bmi == null) return null;
    if (bmi! < 18.5) return "偏瘦";
    if (bmi! < 24) return "正常";
    if (bmi! < 28) return "偏胖";
    return "肥胖";
  }

  String? get waistToHipRatio {
    if (waistCm != null && hipCm != null && hipCm! > 0) {
      return (waistCm! / hipCm!).toStringAsFixed(2);
    }
    return null;
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

  int get defaultWorkStartHour {
    if (age == null) return 9;
    return age! <= 22 ? 8 : 9;
  }

  int get defaultWorkEndHour => 18;

  Map<String, dynamic> toMap() {
    return {
      'nickname': nickname,
      'avatar_base64': avatarBase64,
      'gender': gender?.index ?? 0,
      'birth_year': birthYear,
      'height_cm': heightCm,
      'weight_kg': weightKg,
      'chest_cm': chestCm,
      'waist_cm': waistCm,
      'hip_cm': hipCm,
      'job_type': jobType?.index ?? 0,
      'work_start_hour': workStartHour,
      'work_end_hour': workEndHour,
    };
  }

  factory ProfileModel.fromMap(Map<String, dynamic> map) {
    return ProfileModel(
      nickname: map['nickname'] as String?,
      avatarBase64: map['avatar_base64'] as String?,
      gender: map['gender'] != null
          ? Gender.values[map['gender'] as int]
          : Gender.unknown,
      birthYear: map['birth_year'] as int?,
      heightCm: (map['height_cm'] as num?)?.toDouble(),
      weightKg: (map['weight_kg'] as num?)?.toDouble(),
      chestCm: (map['chest_cm'] as num?)?.toDouble(),
      waistCm: (map['waist_cm'] as num?)?.toDouble(),
      hipCm: (map['hip_cm'] as num?)?.toDouble(),
      jobType: map['job_type'] != null
          ? JobType.values[map['job_type'] as int]
          : JobType.other,
      workStartHour: map['work_start_hour'] as int?,
      workEndHour: map['work_end_hour'] as int?,
    );
  }
}
