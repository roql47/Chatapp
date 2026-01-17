import 'user_model.dart';

// 채팅방 모델
class ChatRoom {
  final String id;
  final List<String> participants;
  final UserModel? partner;
  final DateTime createdAt;
  final bool isActive;

  ChatRoom({
    required this.id,
    required this.participants,
    this.partner,
    required this.createdAt,
    this.isActive = true,
  });

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    return ChatRoom(
      id: json['_id'] ?? json['id'] ?? '',
      participants: List<String>.from(json['participants'] ?? []),
      partner: json['partner'] != null 
          ? UserModel.fromJson(json['partner']) 
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'participants': participants,
      'partner': partner?.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'isActive': isActive,
    };
  }
}
