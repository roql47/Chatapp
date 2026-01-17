// 채팅 메시지 모델
enum MessageType {
  text,
  image,
  system,
}

class ChatMessage {
  final String id;
  final String roomId;
  final String senderId;
  final String senderNickname;
  final String content;
  final MessageType type;
  final DateTime timestamp;
  final bool isRead;

  ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderNickname,
    required this.content,
    required this.type,
    required this.timestamp,
    this.isRead = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['_id'] ?? json['id'] ?? '',
      roomId: json['roomId'] ?? '',
      senderId: json['senderId'] ?? '',
      senderNickname: json['senderNickname'] ?? '',
      content: json['content'] ?? '',
      type: MessageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => MessageType.text,
      ),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      isRead: json['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'roomId': roomId,
      'senderId': senderId,
      'senderNickname': senderNickname,
      'content': content,
      'type': type.name,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
    };
  }

  // 시스템 메시지 생성 헬퍼
  static ChatMessage systemMessage({
    required String roomId,
    required String content,
  }) {
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      roomId: roomId,
      senderId: 'system',
      senderNickname: '시스템',
      content: content,
      type: MessageType.system,
      timestamp: DateTime.now(),
      isRead: true,
    );
  }
}
