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
  bool _isSpeakerOn = true;
  bool get isInitialized => _isInitialized;

  // 초기화
  Future<void> initialize() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
    _isInitialized = true;
    
    // 스피커폰 기본 활성화
    await Helper.setSpeakerphoneOn(true);
  }

  // 로컬 미디어 스트림 시작
  Future<void> startLocalStream({bool video = true, bool audio = true}) async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': audio ? {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      } : false,
      'video': video ? {
        'facingMode': 'user',
        'width': {'ideal': 1280},
        'height': {'ideal': 720},
      } : false,
    };

    try {
      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      localRenderer.srcObject = _localStream;
      
      // 로컬 오디오 트랙 활성화 확인
      for (var track in _localStream!.getAudioTracks()) {
        track.enabled = true;
        print('🎤 로컬 오디오 트랙 활성화: ${track.id}');
      }
      
      // 스피커폰 활성화
      await Helper.setSpeakerphoneOn(_isSpeakerOn);
      
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
      print('🎧 원격 트랙 수신: ${event.track.kind}, enabled: ${event.track.enabled}');
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        remoteRenderer.srcObject = _remoteStream;
        
        // 오디오 트랙 활성화 확인
        final audioTracks = _remoteStream!.getAudioTracks();
        print('🔊 원격 오디오 트랙 수: ${audioTracks.length}');
        for (var track in audioTracks) {
          track.enabled = true;
          print('🔊 원격 오디오 트랙 활성화: ${track.id}, enabled: ${track.enabled}');
        }
        
        // 비디오 트랙 확인
        final videoTracks = _remoteStream!.getVideoTracks();
        print('📹 원격 비디오 트랙 수: ${videoTracks.length}');
        for (var track in videoTracks) {
          print('📹 원격 비디오 트랙: ${track.id}, enabled: ${track.enabled}');
        }
        
        // 스피커폰 강제 활성화
        _isSpeakerOn = true;
        Helper.setSpeakerphoneOn(true);
        print('🔊 스피커폰 강제 활성화');
        
        onRemoteStream?.call(_remoteStream!);
      } else {
        print('⚠️ 원격 스트림이 비어있음');
      }
    };

    // 연결 상태 변경
    _peerConnection?.onConnectionState = (state) {
      print('🔗 Connection state: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        print('✅ WebRTC 연결 완료! 스피커폰 재확인');
        Helper.setSpeakerphoneOn(true);
      }
    };

    _peerConnection?.onIceConnectionState = (state) {
      print('🧊 ICE connection state: $state');
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected) {
        print('✅ ICE 연결 완료!');
        // 연결 완료 시 스피커폰 재활성화
        Helper.setSpeakerphoneOn(true);
      }
    };
    
    // 시그널링 상태 변경
    _peerConnection?.onSignalingState = (state) {
      print('📡 Signaling state: $state');
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
  
  // 스피커 토글
  Future<void> toggleSpeaker() async {
    _isSpeakerOn = !_isSpeakerOn;
    await Helper.setSpeakerphoneOn(_isSpeakerOn);
    print('🔊 스피커: ${_isSpeakerOn ? "ON" : "OFF"}');
  }
  
  // 스피커 상태
  bool get isSpeakerOn => _isSpeakerOn;

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
