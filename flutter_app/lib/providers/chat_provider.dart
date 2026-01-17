import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

// 저장 키
const String _activeChatKey = 'active_chat_session';

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
  bool _isRestoring = false;
  Map<String, dynamic>? _lastGiftData;

  MatchingState get matchingState => _matchingState;
  ChatRoom? get currentRoom => _currentRoom;
  UserModel? get partner => _partner;
  List<ChatMessage> get messages => _messages;
  bool get partnerTyping => _partnerTyping;
  MatchingFilter get filter => _filter;
  String? get matchingError => _matchingError;
  bool get isRestoring => _isRestoring;
  bool get hasActiveChat => _currentRoom != null && _matchingState == MatchingState.chatting;
  Map<String, dynamic>? get lastGiftData => _lastGiftData;
  
  // 선물 애니메이션 표시 후 데이터 클리어
  void clearGiftData() {
    _lastGiftData = null;
  }

  ChatProvider() {
    _setupSocketListeners();
    _restoreSession(); // 앱 시작 시 세션 복원
  }
  
  // 세션 저장 (백그라운드 전환 시)
  Future<void> saveSession() async {
    if (_currentRoom == null || _partner == null) {
      await clearSession();
      return;
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionData = {
        'room': {
          'id': _currentRoom!.id,
          'participants': _currentRoom!.participants,
          'createdAt': _currentRoom!.createdAt.toIso8601String(),
        },
        'partner': _partner!.toJson(),
        'matchingState': _matchingState.index,
        'savedAt': DateTime.now().toIso8601String(),
      };
      await prefs.setString(_activeChatKey, jsonEncode(sessionData));
      print('💾 채팅 세션 저장됨: ${_currentRoom!.id}');
    } catch (e) {
      print('채팅 세션 저장 오류: $e');
    }
  }
  
  // 세션 복원 (앱 재시작 시)
  Future<void> _restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionJson = prefs.getString(_activeChatKey);
      
      if (sessionJson == null) return;
      
      final sessionData = jsonDecode(sessionJson) as Map<String, dynamic>;
      final savedAt = DateTime.parse(sessionData['savedAt']);
      
      // 30분 이상 지난 세션은 무시
      if (DateTime.now().difference(savedAt).inMinutes > 30) {
        await clearSession();
        return;
      }
      
      _isRestoring = true;
      notifyListeners();
      
      _currentRoom = ChatRoom.fromJson(sessionData['room']);
      _partner = UserModel.fromJson(sessionData['partner']);
      _matchingState = MatchingState.values[sessionData['matchingState'] ?? 3];
      
      print('🔄 채팅 세션 복원됨: ${_currentRoom!.id}');
      
      // 소켓 연결 후 방에 다시 참여
      if (_socketService.isConnected && _currentRoom != null) {
        _socketService.joinRoom(_currentRoom!.id);
      }
      
      _isRestoring = false;
      notifyListeners();
    } catch (e) {
      print('채팅 세션 복원 오류: $e');
      await clearSession();
      _isRestoring = false;
    }
  }
  
  // 세션 삭제
  Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_activeChatKey);
    } catch (e) {
      print('세션 삭제 오류: $e');
    }
  }
  
  // 소켓 재연결 시 호출
  void onSocketReconnected() {
    if (_currentRoom != null && _matchingState == MatchingState.chatting) {
      _socketService.joinRoom(_currentRoom!.id);
      print('🔌 소켓 재연결 - 채팅방 재참여: ${_currentRoom!.id}');
    }
  }

  void _setupSocketListeners() {
    // 메시지 수신
    _socketService.onMessageReceived = (message) {
      // 현재 방의 메시지만 추가
      if (_currentRoom != null && message.roomId == _currentRoom!.id) {
        _messages.add(message);
        notifyListeners();
      }
    };
    
    // 소켓 재연결 시
    _socketService.onReconnected = () {
      onSocketReconnected();
    };

    // 매칭 완료
    _socketService.onMatchFound = (data) {
      _currentRoom = ChatRoom.fromJson(data['room']);
      _partner = UserModel.fromJson(data['partner']);
      _matchingState = MatchingState.matched;
      _messages = [];
      
      // 상대방 정보 문자열 생성
      final partnerInfo = StringBuffer();
      partnerInfo.writeln('${_partner!.nickname}님과 연결되었습니다!');
      
      // MBTI 표시
      if (_partner!.mbti.isNotEmpty) {
        partnerInfo.writeln('');
        partnerInfo.writeln('MBTI: ${_partner!.mbti}');
      }
      
      // 시스템 메시지 추가
      _messages.add(ChatMessage.systemMessage(
        roomId: _currentRoom!.id,
        content: partnerInfo.toString().trim(),
      ));
      
      // 방 참가
      _socketService.joinRoom(_currentRoom!.id);
      _matchingState = MatchingState.chatting;
      
      // 세션 저장
      saveSession();
      
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

    // 상대방 연결 해제 (완전 종료)
    _socketService.onPartnerDisconnected = () {
      if (_currentRoom != null) {
        _messages.add(ChatMessage.systemMessage(
          roomId: _currentRoom!.id,
          content: '상대방이 채팅을 종료했습니다.',
        ));
        _partnerTyping = false;
        notifyListeners();
      }
    };
    
    // 상대방 일시적 연결 끊김
    _socketService.onPartnerConnectionLost = () {
      if (_currentRoom != null) {
        _messages.add(ChatMessage.systemMessage(
          roomId: _currentRoom!.id,
          content: '⏳ 상대방의 연결이 일시적으로 끊겼습니다. 재연결을 기다리는 중...',
        ));
        _partnerTyping = false;
        notifyListeners();
      }
    };
    
    // 상대방 재연결
    _socketService.onPartnerReconnected = () {
      if (_currentRoom != null) {
        _messages.add(ChatMessage.systemMessage(
          roomId: _currentRoom!.id,
          content: '🔌 상대방이 다시 연결되었습니다!',
        ));
        notifyListeners();
      }
    };
    
    // 선물 수신
    _socketService.onGiftReceived = (data) {
      _lastGiftData = data;
      if (_currentRoom != null) {
        final giftInfo = data['giftInfo'] as Map<String, dynamic>?;
        final senderNickname = data['senderNickname'] ?? '누군가';
        final receiverNickname = data['receiverNickname'] ?? '누군가';
        final giftName = giftInfo?['name'] ?? '선물';
        final rewardPoints = data['rewardPoints'] ?? 0;
        
        _messages.add(ChatMessage.systemMessage(
          roomId: _currentRoom!.id,
          content: '$senderNickname님이 $receiverNickname님에게 $giftName을(를) 선물했습니다! (+${rewardPoints}P)',
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

  // 이미지 전송 - 성공 여부 반환
  Future<bool> sendImageMessage(File imageFile, String senderId, String senderNickname) async {
    if (_currentRoom == null) return false;

    try {
      // 이미지 업로드
      final imageUrl = await _storageService.uploadImage(imageFile);
      if (imageUrl == null) {
        print('❌ 이미지 업로드 실패');
        return false;
      }

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
      print('✅ 이미지 전송 성공: $imageUrl');
      return true;
    } catch (e) {
      print('❌ 이미지 전송 오류: $e');
      return false;
    }
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
    
    // 세션 삭제
    clearSession();
    
    notifyListeners();
  }

  // 다음 상대 찾기
  void findNextPartner() {
    endChat();
    startMatching();
  }
}
