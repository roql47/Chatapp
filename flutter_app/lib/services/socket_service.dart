import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/app_config.dart';
import '../models/chat_message.dart';

typedef MessageCallback = void Function(ChatMessage message);
typedef MatchCallback = void Function(Map<String, dynamic> data);
typedef TypingCallback = void Function(String oderId, bool isTyping);
typedef CallCallback = void Function(Map<String, dynamic> data);

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? _socket;
  String? _userId;
  
  // 콜백들
  MessageCallback? onMessageReceived;
  MatchCallback? onMatchFound;
  VoidCallback? onMatchCancelled;
  TypingCallback? onTypingStatus;
  VoidCallback? onPartnerDisconnected;
  CallCallback? onCallOffer;
  CallCallback? onCallAnswer;
  CallCallback? onIceCandidate;
  VoidCallback? onCallEnded;

  bool get isConnected => _socket?.connected ?? false;

  // 소켓 연결
  void connect(String userId, String token) {
    _userId = userId;
    
    _socket = io.io(
      AppConfig.serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .setQuery({'userId': userId})
          .enableAutoConnect()
          .enableReconnection()
          .build(),
    );

    _setupListeners();
    _socket?.connect();
  }

  void _setupListeners() {
    _socket?.onConnect((_) {
      print('Socket connected');
    });

    _socket?.onDisconnect((_) {
      print('Socket disconnected');
    });

    _socket?.onError((error) {
      print('Socket error: $error');
    });

    // 메시지 수신
    _socket?.on('message', (data) {
      final message = ChatMessage.fromJson(data);
      onMessageReceived?.call(message);
    });

    // 매칭 완료
    _socket?.on('match_found', (data) {
      onMatchFound?.call(data);
    });

    // 매칭 취소
    _socket?.on('match_cancelled', (_) {
      onMatchCancelled?.call();
    });

    // 타이핑 상태
    _socket?.on('typing', (data) {
      onTypingStatus?.call(data['userId'], data['isTyping']);
    });

    // 상대방 연결 해제
    _socket?.on('partner_disconnected', (_) {
      onPartnerDisconnected?.call();
    });

    // WebRTC 시그널링
    _socket?.on('call_offer', (data) {
      onCallOffer?.call(data);
    });

    _socket?.on('call_answer', (data) {
      onCallAnswer?.call(data);
    });

    _socket?.on('ice_candidate', (data) {
      onIceCandidate?.call(data);
    });

    _socket?.on('call_ended', (_) {
      onCallEnded?.call();
    });
  }

  // 매칭 시작
  void startMatching(Map<String, dynamic> filter) {
    _socket?.emit('start_matching', {
      'userId': _userId,
      'filter': filter,
    });
  }

  // 매칭 취소
  void cancelMatching() {
    _socket?.emit('cancel_matching', {'userId': _userId});
  }

  // 채팅방 참가
  void joinRoom(String roomId) {
    _socket?.emit('join_room', {'roomId': roomId, 'userId': _userId});
  }

  // 채팅방 나가기
  void leaveRoom(String roomId) {
    _socket?.emit('leave_room', {'roomId': roomId, 'userId': _userId});
  }

  // 메시지 전송
  void sendMessage(ChatMessage message) {
    _socket?.emit('send_message', message.toJson());
  }

  // 타이핑 상태 전송
  void sendTypingStatus(String roomId, bool isTyping) {
    _socket?.emit('typing', {
      'roomId': roomId,
      'userId': _userId,
      'isTyping': isTyping,
    });
  }

  // WebRTC 시그널링
  void sendCallOffer(String roomId, Map<String, dynamic> offer) {
    _socket?.emit('call_offer', {
      'roomId': roomId,
      'userId': _userId,
      'offer': offer,
    });
  }

  void sendCallAnswer(String roomId, Map<String, dynamic> answer) {
    _socket?.emit('call_answer', {
      'roomId': roomId,
      'userId': _userId,
      'answer': answer,
    });
  }

  void sendIceCandidate(String roomId, Map<String, dynamic> candidate) {
    _socket?.emit('ice_candidate', {
      'roomId': roomId,
      'userId': _userId,
      'candidate': candidate,
    });
  }

  void endCall(String roomId) {
    _socket?.emit('end_call', {
      'roomId': roomId,
      'userId': _userId,
    });
  }

  // 연결 해제
  void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }
}

typedef VoidCallback = void Function();
