// 사용자 모델
class UserModel {
  final String id;
  final String kakaoId;
  final String nickname;
  final String? profileImage;
  final String gender; // 'male', 'female', 'other'
  final bool genderLocked; // 성별 변경 잠금 여부
  final String mbti; // MBTI 유형
  final List<String> interests;
  final DateTime createdAt;
  final bool isOnline;
  final int points; // 포인트
  final double? latitude; // 위치 - 위도
  final double? longitude; // 위치 - 경도
  final bool isAdultVerified; // 성인인증 여부

  UserModel({
    required this.id,
    required this.kakaoId,
    required this.nickname,
    this.profileImage,
    required this.gender,
    this.genderLocked = false,
    this.mbti = '',
    required this.interests,
    required this.createdAt,
    this.isOnline = false,
    this.points = 100, // 기본 100 포인트
    this.latitude,
    this.longitude,
    this.isAdultVerified = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // 위치 정보 파싱
    double? lat, lng;
    if (json['location'] != null) {
      lat = (json['location']['latitude'] as num?)?.toDouble();
      lng = (json['location']['longitude'] as num?)?.toDouble();
    }
    
    // 성인인증 정보 파싱
    bool isAdultVerified = false;
    if (json['adultVerification'] != null) {
      isAdultVerified = json['adultVerification']['isVerified'] ?? false;
    }
    
    return UserModel(
      id: json['_id'] ?? json['id'] ?? '',
      kakaoId: json['kakaoId'] ?? '',
      nickname: json['nickname'] ?? '',
      profileImage: json['profileImage'],
      gender: json['gender'] ?? 'other',
      genderLocked: json['genderLocked'] ?? false,
      mbti: json['mbti'] ?? '',
      interests: List<String>.from(json['interests'] ?? []),
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
      isOnline: json['isOnline'] ?? false,
      points: json['points'] ?? 100,
      latitude: lat,
      longitude: lng,
      isAdultVerified: isAdultVerified,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'kakaoId': kakaoId,
      'nickname': nickname,
      'profileImage': profileImage,
      'gender': gender,
      'genderLocked': genderLocked,
      'mbti': mbti,
      'interests': interests,
      'createdAt': createdAt.toIso8601String(),
      'isOnline': isOnline,
      'points': points,
      'location': (latitude != null && longitude != null) 
          ? {'latitude': latitude, 'longitude': longitude} 
          : null,
      'adultVerification': {'isVerified': isAdultVerified},
    };
  }

  UserModel copyWith({
    String? id,
    String? kakaoId,
    String? nickname,
    String? profileImage,
    String? gender,
    bool? genderLocked,
    String? mbti,
    List<String>? interests,
    DateTime? createdAt,
    bool? isOnline,
    int? points,
    double? latitude,
    double? longitude,
    bool? isAdultVerified,
  }) {
    return UserModel(
      id: id ?? this.id,
      kakaoId: kakaoId ?? this.kakaoId,
      nickname: nickname ?? this.nickname,
      profileImage: profileImage ?? this.profileImage,
      gender: gender ?? this.gender,
      genderLocked: genderLocked ?? this.genderLocked,
      mbti: mbti ?? this.mbti,
      interests: interests ?? this.interests,
      createdAt: createdAt ?? this.createdAt,
      isOnline: isOnline ?? this.isOnline,
      points: points ?? this.points,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isAdultVerified: isAdultVerified ?? this.isAdultVerified,
    );
  }
}

// 포인트 내역 모델
class PointHistory {
  final String type; // 'charge', 'use', 'bonus'
  final int amount;
  final String description;
  final DateTime createdAt;

  PointHistory({
    required this.type,
    required this.amount,
    required this.description,
    required this.createdAt,
  });

  factory PointHistory.fromJson(Map<String, dynamic> json) {
    return PointHistory(
      type: json['type'] ?? '',
      amount: json['amount'] ?? 0,
      description: json['description'] ?? '',
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
    );
  }
}
