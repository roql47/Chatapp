import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/socket_service.dart';
import '../services/webrtc_service.dart';

enum CallState {
  idle,
  calling,
  ringing,
  connected,
  ended,
}

enum CallType {
  video,
  audio,
}

class CallProvider extends ChangeNotifier {
  final SocketService _socketService = SocketService();
  final WebRTCService _webrtcService = WebRTCService();

  CallState _callState = CallState.idle;
  CallType _callType = CallType.video;
  String? _currentRoomId;
  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _isSpeakerOn = true;

  CallState get callState => _callState;
  CallType get callType => _callType;
  bool get isMuted => _isMuted;
  bool get isVideoOff => _isVideoOff;
  bool get isSpeakerOn => _isSpeakerOn;
  RTCVideoRenderer get localRenderer => _webrtcService.localRenderer;
  RTCVideoRenderer get remoteRenderer => _webrtcService.remoteRenderer;

  CallProvider() {
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    // 통화 요청 수신
    _socketService.onCallOffer = (data) async {
      _currentRoomId = data['roomId'];
      _callState = CallState.ringing;
      notifyListeners();
    };

    // 통화 응답 수신
    _socketService.onCallAnswer = (data) async {
      final answer = RTCSessionDescription(
        data['answer']['sdp'],
        data['answer']['type'],
      );
      await _webrtcService.setRemoteDescription(answer);
      _callState = CallState.connected;
      notifyListeners();
    };

    // ICE Candidate 수신
    _socketService.onIceCandidate = (data) async {
      final candidate = RTCIceCandidate(
        data['candidate']['candidate'],
        data['candidate']['sdpMid'],
        data['candidate']['sdpMLineIndex'],
      );
      await _webrtcService.addIceCandidate(candidate);
    };

    // 통화 종료 수신
    _socketService.onCallEnded = () {
      endCall();
    };
  }

  // 통화 초기화
  Future<void> initialize() async {
    if (!_webrtcService.isInitialized) {
      await _webrtcService.initialize();
    }
  }

  // 통화 시작 (발신)
  Future<void> startCall(String roomId, CallType type) async {
    _currentRoomId = roomId;
    _callType = type;
    _callState = CallState.calling;
    notifyListeners();

    try {
      // WebRTC 초기화
      await initialize();
      
      // 로컬 스트림 시작
      await _webrtcService.startLocalStream(
        video: type == CallType.video,
        audio: true,
      );

      // PeerConnection 생성
      await _webrtcService.initPeerConnection();

      // ICE Candidate 콜백 설정
      _webrtcService.onIceCandidate = (candidate) {
        _socketService.sendIceCandidate(roomId, {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        });
      };

      // Offer 생성 및 전송
      final offer = await _webrtcService.createOffer();
      _socketService.sendCallOffer(roomId, {
        'sdp': offer.sdp,
        'type': offer.type,
      });

      notifyListeners();
    } catch (e) {
      print('통화 시작 오류: $e');
      _callState = CallState.ended;
      notifyListeners();
    }
  }

  // 통화 수락 (수신)
  Future<void> acceptCall(Map<String, dynamic> offerData) async {
    try {
      _callState = CallState.connected;
      notifyListeners();

      // WebRTC 초기화
      await initialize();

      // 로컬 스트림 시작
      await _webrtcService.startLocalStream(
        video: _callType == CallType.video,
        audio: true,
      );

      // PeerConnection 생성
      await _webrtcService.initPeerConnection();

      // ICE Candidate 콜백 설정
      _webrtcService.onIceCandidate = (candidate) {
        _socketService.sendIceCandidate(_currentRoomId!, {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        });
      };

      // Remote Description 설정
      final offer = RTCSessionDescription(
        offerData['sdp'],
        offerData['type'],
      );
      await _webrtcService.setRemoteDescription(offer);

      // Answer 생성 및 전송
      final answer = await _webrtcService.createAnswer();
      _socketService.sendCallAnswer(_currentRoomId!, {
        'sdp': answer.sdp,
        'type': answer.type,
      });

      notifyListeners();
    } catch (e) {
      print('통화 수락 오류: $e');
      endCall();
    }
  }

  // 통화 거절
  void rejectCall() {
    if (_currentRoomId != null) {
      _socketService.endCall(_currentRoomId!);
    }
    _callState = CallState.idle;
    _currentRoomId = null;
    notifyListeners();
  }

  // 통화 종료
  Future<void> endCall() async {
    if (_currentRoomId != null) {
      _socketService.endCall(_currentRoomId!);
    }
    
    await _webrtcService.endCall();
    
    _callState = CallState.idle;
    _currentRoomId = null;
    _isMuted = false;
    _isVideoOff = false;
    notifyListeners();
  }

  // 마이크 토글
  void toggleMute() {
    _webrtcService.toggleMute();
    _isMuted = !_isMuted;
    notifyListeners();
  }

  // 비디오 토글
  void toggleVideo() {
    _webrtcService.toggleVideo();
    _isVideoOff = !_isVideoOff;
    notifyListeners();
  }

  // 카메라 전환
  Future<void> switchCamera() async {
    await _webrtcService.switchCamera();
    notifyListeners();
  }

  // 스피커 토글
  void toggleSpeaker() {
    _isSpeakerOn = !_isSpeakerOn;
    // 실제 스피커 전환 로직은 플랫폼별로 구현 필요
    notifyListeners();
  }

  @override
  void dispose() {
    _webrtcService.dispose();
    super.dispose();
  }
}
