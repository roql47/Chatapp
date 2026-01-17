// 친구 모델
class FriendModel {
  final String id;
  final String oderId;
  final String friendUserId; // 친구 사용자 ID (DM용)
  final String nickname;
  final String? profileImage;
  final String status; // 'pending', 'accepted', 'rejected'
  final DateTime createdAt;
  final bool isOnline;

  FriendModel({
    required this.id,
    required this.oderId,
    required this.friendUserId,
    required this.nickname,
    this.profileImage,
    required this.status,
    required this.createdAt,
    this.isOnline = false,
  });

  factory FriendModel.fromJson(Map<String, dynamic> json) {
    final oderId = json['oderId']?.toString() ?? json['userId']?.toString() ?? json['friendId']?.toString() ?? '';
    return FriendModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      oderId: oderId,
      friendUserId: json['friendUserId']?.toString() ?? oderId, // friendUserId가 없으면 oderId 사용
      nickname: json['nickname'] ?? '',
      profileImage: json['profileImage'],
      status: json['status'] ?? 'pending',
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
      isOnline: json['isOnline'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'friendId': oderId,
      'friendUserId': friendUserId,
      'nickname': nickname,
      'profileImage': profileImage,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'isOnline': isOnline,
    };
  }
}

// 친구 요청 상태
enum FriendRequestStatus {
  pending,   // 대기중
  accepted,  // 수락됨
  rejected,  // 거절됨
}
