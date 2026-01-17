import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../config/app_config.dart';

class WebRTCService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  // 콜백
  Function(MediaStream)? onLocalStream;
  Function(MediaStream)? onRemoteStream;
  Function(RTCIceCandidate)? onIceCandidate;
  Function(RTCSessionDescription)? onOffer;
  Function(RTCSessionDescription)? onAnswer;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // 초기화
  Future<void> initialize() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
    _isInitialized = true;
  }

  // 로컬 미디어 스트림 시작
  Future<void> startLocalStream({bool video = true, bool audio = true}) async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': audio,
      'video': video ? {
        'facingMode': 'user',
        'width': {'ideal': 1280},
        'height': {'ideal': 720},
      } : false,
    };

    try {
      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      localRenderer.srcObject = _localStream;
      onLocalStream?.call(_localStream!);
    } catch (e) {
      print('Error getting user media: $e');
      rethrow;
    }
  }

  // PeerConnection 생성
  Future<void> initPeerConnection() async {
    final configuration = <String, dynamic>{
      'iceServers': AppConfig.iceServers,
    };
    
    _peerConnection = await createPeerConnection(configuration);

    // 로컬 스트림 추가
    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) {
        _peerConnection?.addTrack(track, _localStream!);
      });
    }

    // ICE Candidate 이벤트
    _peerConnection?.onIceCandidate = (candidate) {
      if (candidate.candidate != null) {
        onIceCandidate?.call(candidate);
      }
    };

    // 원격 스트림 수신
    _peerConnection?.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        remoteRenderer.srcObject = _remoteStream;
        onRemoteStream?.call(_remoteStream!);
      }
    };

    // 연결 상태 변경
    _peerConnection?.onConnectionState = (state) {
      print('Connection state: $state');
    };

    _peerConnection?.onIceConnectionState = (state) {
      print('ICE connection state: $state');
    };
  }

  // Offer 생성
  Future<RTCSessionDescription> createOffer() async {
    final offer = await _peerConnection!.createOffer({
      'offerToReceiveVideo': true,
      'offerToReceiveAudio': true,
    });
    await _peerConnection!.setLocalDescription(offer);
    return offer;
  }

  // Answer 생성
  Future<RTCSessionDescription> createAnswer() async {
    final answer = await _peerConnection!.createAnswer({
      'offerToReceiveVideo': true,
      'offerToReceiveAudio': true,
    });
    await _peerConnection!.setLocalDescription(answer);
    return answer;
  }

  // Remote Description 설정
  Future<void> setRemoteDescription(RTCSessionDescription description) async {
    await _peerConnection?.setRemoteDescription(description);
  }

  // ICE Candidate 추가
  Future<void> addIceCandidate(RTCIceCandidate candidate) async {
    await _peerConnection?.addCandidate(candidate);
  }

  // 카메라 전환
  Future<void> switchCamera() async {
    if (_localStream != null) {
      final videoTrack = _localStream!.getVideoTracks().first;
      await Helper.switchCamera(videoTrack);
    }
  }

  // 마이크 음소거 토글
  void toggleMute() {
    if (_localStream != null) {
      final audioTrack = _localStream!.getAudioTracks().first;
      audioTrack.enabled = !audioTrack.enabled;
    }
  }

  // 비디오 토글
  void toggleVideo() {
    if (_localStream != null) {
      final videoTrack = _localStream!.getVideoTracks().first;
      videoTrack.enabled = !videoTrack.enabled;
    }
  }

  // 마이크 음소거 상태
  bool get isMuted {
    if (_localStream != null && _localStream!.getAudioTracks().isNotEmpty) {
      return !_localStream!.getAudioTracks().first.enabled;
    }
    return false;
  }

  // 비디오 꺼짐 상태
  bool get isVideoOff {
    if (_localStream != null && _localStream!.getVideoTracks().isNotEmpty) {
      return !_localStream!.getVideoTracks().first.enabled;
    }
    return true;
  }

  // 정리
  Future<void> dispose() async {
    await _localStream?.dispose();
    await _remoteStream?.dispose();
    await _peerConnection?.close();
    await localRenderer.dispose();
    await remoteRenderer.dispose();
    
    _localStream = null;
    _remoteStream = null;
    _peerConnection = null;
    _isInitialized = false;
  }

  // 통화 종료
  Future<void> endCall() async {
    await _localStream?.dispose();
    await _remoteStream?.dispose();
    await _peerConnection?.close();
    
    _localStream = null;
    _remoteStream = null;
    _peerConnection = null;
    
    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;
  }
}
