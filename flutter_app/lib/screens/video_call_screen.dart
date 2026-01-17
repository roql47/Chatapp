import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../providers/call_provider.dart';
import '../providers/chat_provider.dart';
import '../config/theme.dart';

class VideoCallScreen extends StatefulWidget {
  final String callType;
  
  const VideoCallScreen({super.key, this.callType = 'video'});

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _initializeCall();
  }

  Future<void> _initializeCall() async {
    final callProvider = Provider.of<CallProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    
    await callProvider.initialize();
    
    if (chatProvider.currentRoom != null) {
      await callProvider.startCall(
        chatProvider.currentRoom!.id,
        widget.callType == 'video' ? CallType.video : CallType.audio,
      );
    }
  }

  void _endCall() {
    final callProvider = Provider.of<CallProvider>(context, listen: false);
    callProvider.endCall();
    context.pop();
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
  }

  @override
  Widget build(BuildContext context) {
    final callProvider = Provider.of<CallProvider>(context);
    final isVideoCall = widget.callType == 'video';

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            // 원격 비디오 (전체화면)
            if (isVideoCall)
              Positioned.fill(
                child: RTCVideoView(
                  callProvider.remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              )
            else
              // 음성 통화 화면
              _buildAudioCallScreen(),

            // 로컬 비디오 (PIP)
            if (isVideoCall && !callProvider.isVideoOff)
              Positioned(
                top: 60,
                right: 20,
                child: Container(
                  width: 120,
                  height: 160,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: RTCVideoView(
                      callProvider.localRenderer,
                      mirror: true,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
                  ),
                ),
              ),

            // 컨트롤 오버레이
            if (_showControls)
              AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.5),
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                      stops: const [0, 0.2, 0.7, 1],
                    ),
                  ),
                ),
              ),

            // 상단 바
            if (_showControls)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: _endCall,
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        _buildCallStatusBadge(callProvider.callState),
                        const Spacer(),
                        if (isVideoCall)
                          IconButton(
                            onPressed: callProvider.switchCamera,
                            icon: const Icon(
                              Icons.cameraswitch,
                              color: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

            // 하단 컨트롤
            if (_showControls)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // 음소거
                        _buildControlButton(
                          icon: callProvider.isMuted ? Icons.mic_off : Icons.mic,
                          label: callProvider.isMuted ? '음소거 해제' : '음소거',
                          isActive: callProvider.isMuted,
                          onTap: callProvider.toggleMute,
                        ),
                        // 통화 종료
                        _buildEndCallButton(),
                        // 비디오 토글
                        if (isVideoCall)
                          _buildControlButton(
                            icon: callProvider.isVideoOff
                                ? Icons.videocam_off
                                : Icons.videocam,
                            label: callProvider.isVideoOff ? '카메라 켜기' : '카메라 끄기',
                            isActive: callProvider.isVideoOff,
                            onTap: callProvider.toggleVideo,
                          ),
                        // 스피커
                        _buildControlButton(
                          icon: callProvider.isSpeakerOn
                              ? Icons.volume_up
                              : Icons.volume_off,
                          label: callProvider.isSpeakerOn ? '스피커 끄기' : '스피커 켜기',
                          isActive: !callProvider.isSpeakerOn,
                          onTap: callProvider.toggleSpeaker,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // 연결 중 오버레이
            if (callProvider.callState == CallState.calling ||
                callProvider.callState == CallState.ringing)
              _buildConnectingOverlay(callProvider.callState),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioCallScreen() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.darkBackground,
            AppTheme.darkSurface,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 상대방 아바타
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.4),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.person,
                size: 80,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              '음성 통화 중',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            _buildCallTimer(),
          ],
        ),
      ),
    );
  }

  Widget _buildCallTimer() {
    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
      builder: (context, snapshot) {
        final seconds = snapshot.data ?? 0;
        final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
        final secs = (seconds % 60).toString().padLeft(2, '0');
        return Text(
          '$minutes:$secs',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 16,
          ),
        );
      },
    );
  }

  Widget _buildCallStatusBadge(CallState state) {
    String text;
    Color color;
    
    switch (state) {
      case CallState.calling:
        text = '연결 중...';
        color = Colors.orange;
        break;
      case CallState.ringing:
        text = '벨 울리는 중...';
        color = Colors.orange;
        break;
      case CallState.connected:
        text = '통화 중';
        color = AppTheme.successColor;
        break;
      default:
        text = '';
        color = Colors.transparent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? Colors.white : Colors.white.withOpacity(0.2),
            ),
            child: Icon(
              icon,
              color: isActive ? Colors.black : Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEndCallButton() {
    return GestureDetector(
      onTap: _endCall,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.errorColor,
            ),
            child: const Icon(
              Icons.call_end,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '종료',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectingOverlay(CallState state) {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              state == CallState.calling ? '연결 중...' : '상대방 응답 대기 중...',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
