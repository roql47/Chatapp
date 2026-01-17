import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../models/chat_room.dart';
import '../models/matching_filter.dart';
import '../models/user_model.dart';
import '../services/socket_service.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';
import 'dart:io';

// 성별 필터 매칭 비용
const int genderFilterCost = 10;

enum MatchingState {
  idle,
  matching,
  matched,
  chatting,
}

class ChatProvider extends ChangeNotifier {
  final SocketService _socketService = SocketService();
  final StorageService _storageService = StorageService();
  final AuthService _authService = AuthService();

  MatchingState _matchingState = MatchingState.idle;
  ChatRoom? _currentRoom;
  UserModel? _partner;
  List<ChatMessage> _messages = [];
  bool _partnerTyping = false;
  MatchingFilter _filter = MatchingFilter();
  String? _matchingError;

  MatchingState get matchingState => _matchingState;
  ChatRoom? get currentRoom => _currentRoom;
  UserModel? get partner => _partner;
  List<ChatMessage> get messages => _messages;
  bool get partnerTyping => _partnerTyping;
  MatchingFilter get filter => _filter;
  String? get matchingError => _matchingError;

  ChatProvider() {
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    // 메시지 수신
    _socketService.onMessageReceived = (message) {
      _messages.add(message);
      notifyListeners();
    };

    // 매칭 완료
    _socketService.onMatchFound = (data) {
      _currentRoom = ChatRoom.fromJson(data['room']);
      _partner = UserModel.fromJson(data['partner']);
      _matchingState = MatchingState.matched;
      _messages = [];
      
      // 시스템 메시지 추가
      _messages.add(ChatMessage.systemMessage(
        roomId: _currentRoom!.id,
        content: '${_partner!.nickname}님과 연결되었습니다!',
      ));
      
      // 방 참가
      _socketService.joinRoom(_currentRoom!.id);
      _matchingState = MatchingState.chatting;
      notifyListeners();
    };

    // 매칭 취소
    _socketService.onMatchCancelled = () {
      _matchingState = MatchingState.idle;
      notifyListeners();
    };

    // 타이핑 상태
    _socketService.onTypingStatus = (userId, isTyping) {
      if (_partner != null && userId == _partner!.id) {
        _partnerTyping = isTyping;
        notifyListeners();
      }
    };

    // 상대방 연결 해제
    _socketService.onPartnerDisconnected = () {
      if (_currentRoom != null) {
        _messages.add(ChatMessage.systemMessage(
          roomId: _currentRoom!.id,
          content: '상대방이 채팅을 종료했습니다.',
        ));
        notifyListeners();
      }
    };
  }

  // 필터 업데이트
  void updateFilter(MatchingFilter newFilter) {
    _filter = newFilter;
    notifyListeners();
  }

  // 성별 필터 사용 여부 확인
  bool get hasGenderFilter => _filter.preferredGender != null && 
                               _filter.preferredGender != 'any';

  // 매칭에 필요한 포인트
  int get requiredPoints => hasGenderFilter ? genderFilterCost : 0;

  // 포인트 충분한지 확인
  Future<bool> hasEnoughPointsForMatching() async {
    if (!hasGenderFilter) return true;
    return await _authService.hasEnoughPoints(genderFilterCost);
  }

  // 매칭 시작 (포인트 차감 포함)
  Future<bool> startMatchingWithPoints() async {
    _matchingError = null;
    
    // 성별 필터가 있으면 포인트 차감
    if (hasGenderFilter) {
      final hasEnough = await _authService.hasEnoughPoints(genderFilterCost);
      
      if (!hasEnough) {
        _matchingError = '포인트가 부족합니다. 성별 필터 매칭에는 ${genderFilterCost}P가 필요합니다.';
        notifyListeners();
        return false;
      }
      
      // 포인트 차감
      final success = await _authService.usePoints(
        genderFilterCost, 
        '성별 필터 매칭',
      );
      
      if (!success) {
        _matchingError = '포인트 차감에 실패했습니다.';
        notifyListeners();
        return false;
      }
    }
    
    // 매칭 시작
    startMatching();
    return true;
  }

  // 매칭 시작 (기본 - 포인트 차감 없음)
  void startMatching() {
    _matchingState = MatchingState.matching;
    _matchingError = null;
    _socketService.startMatching(_filter.toJson());
    notifyListeners();
  }

  // 매칭 취소
  void cancelMatching() {
    _socketService.cancelMatching();
    _matchingState = MatchingState.idle;
    notifyListeners();
  }

  // 메시지 전송
  void sendTextMessage(String content, String senderId, String senderNickname) {
    if (_currentRoom == null || content.trim().isEmpty) return;

    final message = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      roomId: _currentRoom!.id,
      senderId: senderId,
      senderNickname: senderNickname,
      content: content,
      type: MessageType.text,
      timestamp: DateTime.now(),
    );

    _messages.add(message);
    _socketService.sendMessage(message);
    notifyListeners();
  }

  // 이미지 전송
  Future<void> sendImageMessage(File imageFile, String senderId, String senderNickname) async {
    if (_currentRoom == null) return;

    // 이미지 업로드
    final imageUrl = await _storageService.uploadImage(imageFile);
    if (imageUrl == null) return;

    final message = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      roomId: _currentRoom!.id,
      senderId: senderId,
      senderNickname: senderNickname,
      content: imageUrl,
      type: MessageType.image,
      timestamp: DateTime.now(),
    );

    _messages.add(message);
    _socketService.sendMessage(message);
    notifyListeners();
  }

  // 타이핑 상태 전송
  void sendTypingStatus(bool isTyping) {
    if (_currentRoom != null) {
      _socketService.sendTypingStatus(_currentRoom!.id, isTyping);
    }
  }

  // 채팅 종료
  void endChat() {
    if (_currentRoom != null) {
      _socketService.leaveRoom(_currentRoom!.id);
    }
    _currentRoom = null;
    _partner = null;
    _messages = [];
    _partnerTyping = false;
    _matchingState = MatchingState.idle;
    notifyListeners();
  }

  // 다음 상대 찾기
  void findNextPartner() {
    endChat();
    startMatching();
  }
}
