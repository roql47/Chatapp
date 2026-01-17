// 매칭 필터 모델
class MatchingFilter {
  final String? preferredGender; // 'male', 'female', 'any'
  final List<String> preferredMbtis; // MBTI 유형 리스트 (중복 선택 가능)
  final List<String> interests; // 관심사 리스트 (중복 선택 가능)

  MatchingFilter({
    this.preferredGender = 'any',
    this.preferredMbtis = const [],
    this.interests = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'preferredGender': preferredGender,
      'preferredMbtis': preferredMbtis,
      'interests': interests,
    };
  }

  factory MatchingFilter.fromJson(Map<String, dynamic> json) {
    return MatchingFilter(
      preferredGender: json['preferredGender'] ?? 'any',
      preferredMbtis: List<String>.from(json['preferredMbtis'] ?? []),
      interests: List<String>.from(json['interests'] ?? []),
    );
  }

  MatchingFilter copyWith({
    String? preferredGender,
    List<String>? preferredMbtis,
    List<String>? interests,
  }) {
    return MatchingFilter(
      preferredGender: preferredGender ?? this.preferredGender,
      preferredMbtis: preferredMbtis ?? this.preferredMbtis,
      interests: interests ?? this.interests,
    );
  }
  
  // 필터가 비어있는지 확인
  bool get isEmpty => 
    (preferredGender == null || preferredGender == 'any') &&
    preferredMbtis.isEmpty &&
    interests.isEmpty;
}

// MBTI 유형 목록
class MbtiTypes {
  static const List<String> types = [
    'INTJ', 'INTP', 'ENTJ', 'ENTP',
    'INFJ', 'INFP', 'ENFJ', 'ENFP',
    'ISTJ', 'ISFJ', 'ESTJ', 'ESFJ',
    'ISTP', 'ISFP', 'ESTP', 'ESFP',
  ];
}

// 관심사 목록
class InterestCategories {
  static const List<Map<String, dynamic>> categories = [
    {'id': 'music', 'name': '음악'},
    {'id': 'movie', 'name': '영화'},
    {'id': 'game', 'name': '게임'},
    {'id': 'sports', 'name': '스포츠'},
    {'id': 'travel', 'name': '여행'},
    {'id': 'food', 'name': '맛집'},
    {'id': 'book', 'name': '독서'},
    {'id': 'art', 'name': '예술'},
    {'id': 'tech', 'name': 'IT/테크'},
    {'id': 'fashion', 'name': '패션'},
    {'id': 'pet', 'name': '반려동물'},
    {'id': 'cooking', 'name': '요리'},
  ];
}
