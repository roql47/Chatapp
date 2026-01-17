// 매칭 필터 모델
class MatchingFilter {
  final String? preferredGender; // 'male', 'female', 'any'
  final String? preferredMbti; // MBTI 유형 또는 'any'
  final List<String> interests;

  MatchingFilter({
    this.preferredGender = 'any',
    this.preferredMbti = 'any',
    this.interests = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'preferredGender': preferredGender,
      'preferredMbti': preferredMbti,
      'interests': interests,
    };
  }

  factory MatchingFilter.fromJson(Map<String, dynamic> json) {
    return MatchingFilter(
      preferredGender: json['preferredGender'] ?? 'any',
      preferredMbti: json['preferredMbti'] ?? 'any',
      interests: List<String>.from(json['interests'] ?? []),
    );
  }

  MatchingFilter copyWith({
    String? preferredGender,
    String? preferredMbti,
    List<String>? interests,
  }) {
    return MatchingFilter(
      preferredGender: preferredGender ?? this.preferredGender,
      preferredMbti: preferredMbti ?? this.preferredMbti,
      interests: interests ?? this.interests,
    );
  }
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
