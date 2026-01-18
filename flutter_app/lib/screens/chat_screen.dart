import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:no_screenshot/no_screenshot.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/call_provider.dart';
import '../models/chat_message.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/socket_service.dart';
import '../config/theme.dart';
import '../widgets/rating_dialog.dart';
import '../widgets/gift_dialog.dart';
import '../widgets/profile_image_viewer.dart';
import '../widgets/gift_animation.dart';
import '../widgets/blurred_image.dart';
import 'dart:async';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final StorageService _storageService = StorageService();
  final LocationService _locationService = LocationService();
  final SocketService _socketService = SocketService();
  Timer? _typingTimer;
  bool _isTyping = false;
  bool _isShowingCallDialog = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 스크린샷 방지 활성화
    _enableSecureMode();
    // 통화 수신 감지 및 소켓 연결 확인
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIncomingCall();
      _ensureSocketConnection();
    });
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // 앱이 포그라운드로 돌아왔을 때 소켓 연결 확인
      print('📱 ChatScreen: 포그라운드 복귀 - 소켓 연결 확인');
      _ensureSocketConnection();
    }
  }
  
  // 소켓 연결 확인 및 채팅방 재참여
  void _ensureSocketConnection() {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (!_socketService.isConnected && authProvider.user != null && authProvider.token != null) {
      print('🔌 소켓 재연결 시도...');
      _socketService.connect(authProvider.user!.id, authProvider.token!);
    }
    
    // 채팅방 재참여
    Future.delayed(const Duration(milliseconds: 500), () {
      chatProvider.rejoinRoom();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // 스크린샷 방지 비활성화
    _disableSecureMode();
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }
  
  final _noScreenshot = NoScreenshot.instance;
  
  // 스크린샷 방지 활성화
  Future<void> _enableSecureMode() async {
    try {
      await _noScreenshot.screenshotOff();
    } catch (e) {
      print('스크린샷 방지 활성화 오류: $e');
    }
  }
  
  // 스크린샷 방지 비활성화
  Future<void> _disableSecureMode() async {
    try {
      await _noScreenshot.screenshotOn();
    } catch (e) {
      print('스크린샷 방지 비활성화 오류: $e');
    }
  }
  
  void _checkIncomingCall() {
    final callProvider = Provider.of<CallProvider>(context, listen: false);
    if (callProvider.callState == CallState.ringing && !_isShowingCallDialog) {
      _showIncomingCallDialog();
    }
  }
  
  void _showGiftAnimation(Map<String, dynamic> giftData) {
    if (!mounted) return;
    GiftAnimation.show(context, giftData, () {
      // 애니메이션 완료 후
    });
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final user = authProvider.user!;

    chatProvider.sendTextMessage(text, user.id, user.nickname);
    _messageController.clear();
    _stopTyping();
    _scrollToBottom();
  }

  void _onTextChanged(String text) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    
    if (text.isNotEmpty && !_isTyping) {
      _isTyping = true;
      chatProvider.sendTypingStatus(true);
    }
    
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), _stopTyping);
  }

  void _stopTyping() {
    if (_isTyping) {
      _isTyping = false;
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      chatProvider.sendTypingStatus(false);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickAndSendImage() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final user = authProvider.user!;

    final imageFile = await _storageService.pickImageFromGallery();
    if (imageFile != null) {
      // 로딩 표시
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20, 
                  height: 20, 
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                SizedBox(width: 12),
                Text('이미지 전송 중...'),
              ],
            ),
            duration: Duration(seconds: 10),
          ),
        );
      }
      
      final success = await chatProvider.sendImageMessage(imageFile, user.id, user.nickname);
      
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        if (success) {
          _scrollToBottom();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('이미지 전송에 실패했습니다'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _startVideoCall() {
    context.push('/video-call', extra: 'video');
  }

  void _startAudioCall() {
    context.push('/video-call', extra: 'audio');
  }
  
  void _showIncomingCallDialog() {
    if (_isShowingCallDialog) return;
    _isShowingCallDialog = true;
    
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final callProvider = Provider.of<CallProvider>(context, listen: false);
    final partner = chatProvider.partner;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: Row(
          children: [
            const Icon(Icons.call, color: Colors.green, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${partner?.nickname ?? "상대방"}님의 통화 요청',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: AppTheme.primaryColor,
              backgroundImage: partner?.profileImage != null
                  ? CachedNetworkImageProvider(partner!.profileImage!)
                  : null,
              child: partner?.profileImage == null
                  ? const Icon(Icons.person, size: 40, color: Colors.white)
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              callProvider.callType == CallType.video ? '영상 통화' : '음성 통화',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _isShowingCallDialog = false;
              callProvider.rejectCall();
            },
            child: const Text('거절', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              _isShowingCallDialog = false;
              context.push('/video-call', extra: callProvider.callType == CallType.video ? 'video' : 'audio');
            },
            icon: const Icon(Icons.call, color: Colors.white),
            label: const Text('수락'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
        ],
      ),
    ).then((_) {
      _isShowingCallDialog = false;
    });
  }

  void _endChat() {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final partner = chatProvider.partner;
    final room = chatProvider.currentRoom;
    final isTestBot = partner?.id.startsWith('test_bot') ?? true;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: const Text('채팅 종료', style: TextStyle(color: Colors.white)),
        content: const Text(
          '채팅을 종료하시겠습니까?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              
              // 테스트 봇이 아닌 경우에만 평가 다이얼로그 표시
              if (!isTestBot && partner != null && room != null && mounted) {
                await showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) => RatingDialog(
                    partnerName: partner.nickname,
                    partnerId: partner.id,
                    roomId: room.id,
                  ),
                );
              }
              
              if (mounted) {
                chatProvider.endChat();
                context.go('/home');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('종료'),
          ),
        ],
      ),
    );
  }

  Future<void> _showRatingDialog() async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final partner = chatProvider.partner;
    final room = chatProvider.currentRoom;

    if (partner == null || room == null) return;

    // 테스트 봇인 경우 평가 스킵
    if (partner.id.startsWith('test_bot')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('테스트 봇과의 대화는 평가할 수 없습니다.')),
      );
      return;
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => RatingDialog(
        partnerName: partner.nickname,
        partnerId: partner.id,
        roomId: room.id,
      ),
    );
  }

  void _showGiftDialog() {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final partner = chatProvider.partner;
    final room = chatProvider.currentRoom;

    if (partner == null) return;

    // 테스트 봇인 경우 선물 불가
    if (partner.id.startsWith('test_bot')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('테스트 봇에게는 선물할 수 없습니다.')),
          );
        }
      });
      return;
    }

    // 팝업 메뉴가 완전히 닫힌 후 다이얼로그 표시
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (dialogContext) => GiftDialog(
            partnerName: partner.nickname,
            partnerId: partner.id,
            roomId: room?.id,
          ),
        );
      }
    });
  }

  void _findNextPartner() {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    chatProvider.findNextPartner();
    context.go('/matching');
  }

  Future<void> _sendFriendRequest() async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final partner = chatProvider.partner;
    
    if (partner == null) return;

    // 테스트 봇인 경우 친구 요청 불가
    if (partner.id.startsWith('test_bot')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('테스트 봇에게는 친구 요청을 보낼 수 없습니다.')),
          );
        }
      });
      return;
    }

    // 팝업 메뉴가 닫힌 후 처리
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      
      try {
        final apiService = ApiService();
        await apiService.post('/api/friends/request/${partner.id}', {});
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${partner.nickname}님에게 친구 요청을 보냈습니다!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('친구 요청 실패: ${e.toString()}')),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    final callProvider = Provider.of<CallProvider>(context);
    final user = authProvider.user!;
    final partner = chatProvider.partner;
    
    // 통화 수신 감지
    if (callProvider.callState == CallState.ringing && !_isShowingCallDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showIncomingCallDialog();
      });
    }
    
    // 선물 애니메이션 표시
    if (chatProvider.lastGiftData != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showGiftAnimation(chatProvider.lastGiftData!);
        chatProvider.clearGiftData();
      });
    }

    return Scaffold(
      body: Container(
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
        child: SafeArea(
          child: Column(
            children: [
              // 상단 바
              _buildAppBar(partner),
              // 채팅 메시지 영역
              Expanded(
                child: _buildMessageList(chatProvider, user.id),
              ),
              // 타이핑 표시
              if (chatProvider.partnerTyping) _buildTypingIndicator(),
              // 입력 영역
              _buildInputArea(),
            ],
          ),
        ),
      ),
    );
  }

  void _showPartnerProfile() {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final partner = chatProvider.partner;
    if (partner == null) return;
    
    // 거리 계산
    final distance = _locationService.getDistanceFrom(
      partner.latitude,
      partner.longitude,
    );

    ProfileImageViewer.show(
      context,
      imageUrl: partner.profileImage,
      nickname: partner.nickname,
      heroTag: 'partner_profile_${partner.id}',
      mbti: partner.mbti,
      interests: partner.interests,
      gender: partner.gender,
      createdAt: partner.createdAt,
      distance: distance,
    );
  }
  
  // 이미지 확대 뷰어
  void _showImageViewer(String imageUrl) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        barrierDismissible: true,
        pageBuilder: (context, animation, secondaryAnimation) {
          return _ImageViewerScreen(imageUrl: imageUrl);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Widget _buildAppBar(partner) {
    final partnerName = partner?.nickname ?? '상대방';
    final partnerImage = partner?.profileImage;
    final partnerId = partner?.id ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _endChat,
            icon: const Icon(Icons.close, color: Colors.white70),
          ),
          // 상대방 프로필 사진 (클릭 시 확대)
          GestureDetector(
            onTap: _showPartnerProfile,
            child: Hero(
              tag: 'partner_profile_$partnerId',
              child: CircleAvatar(
                radius: 20,
                backgroundColor: AppTheme.primaryColor,
                backgroundImage: partnerImage != null
                    ? NetworkImage(partnerImage)
                    : null,
                child: partnerImage == null
                    ? const Icon(Icons.person, color: Colors.white, size: 20)
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  partnerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Text(
                  '온라인',
                  style: TextStyle(
                    color: AppTheme.successColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _startAudioCall,
            icon: const Icon(Icons.call, color: Colors.white70),
          ),
          IconButton(
            onPressed: _startVideoCall,
            icon: const Icon(Icons.videocam, color: Colors.white70),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white70),
            color: AppTheme.darkCard,
            onSelected: (value) {
              if (value == 'gift') _showGiftDialog();
              if (value == 'friend') _sendFriendRequest();
              if (value == 'next') _findNextPartner();
              if (value == 'report') _showReportDialog();
              if (value == 'block') _showBlockDialog();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'gift',
                child: Row(
                  children: [
                    Icon(Icons.card_giftcard, color: Colors.pink, size: 20),
                    SizedBox(width: 12),
                    Text('선물하기', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'friend',
                child: Row(
                  children: [
                    Icon(Icons.person_add, color: AppTheme.primaryColor, size: 20),
                    SizedBox(width: 12),
                    Text('친구 요청', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'next',
                child: Row(
                  children: [
                    Icon(Icons.skip_next, color: Colors.white70, size: 20),
                    SizedBox(width: 12),
                    Text('다음 상대', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.flag, color: Colors.orange, size: 20),
                    SizedBox(width: 12),
                    Text('신고하기', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'block',
                child: Row(
                  children: [
                    Icon(Icons.block, color: Colors.red, size: 20),
                    SizedBox(width: 12),
                    Text('차단하기', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(ChatProvider chatProvider, String myId) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: chatProvider.messages.length,
      itemBuilder: (context, index) {
        final message = chatProvider.messages[index];
        return _buildMessageBubble(message, myId);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message, String myId) {
    final isMe = message.senderId == myId;
    final isSystem = message.type == MessageType.system;

    if (isSystem) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.darkCard.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            message.content,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ),
      );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: message.type == MessageType.image
                  ? const EdgeInsets.all(4)
                  : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isMe ? AppTheme.primaryColor : AppTheme.darkCard,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
              ),
              child: message.type == MessageType.image
                  ? BlurredImage(
                      imageUrl: message.content,
                      width: 200,
                      onTapFullScreen: () => _showImageViewer(message.content),
                    )
                  : Text(
                      message.content,
                      style: const TextStyle(color: Colors.white),
                    ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(message.timestamp),
              style: const TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTypingDot(0),
                _buildTypingDot(1),
                _buildTypingDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + (index * 100)),
      builder: (context, value, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.3 + (value * 0.4)),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 이미지 버튼
          IconButton(
            onPressed: _pickAndSendImage,
            icon: const Icon(Icons.image, color: Colors.white70),
          ),
          // 입력 필드
          Expanded(
            child: TextField(
              controller: _messageController,
              onChanged: _onTextChanged,
              style: const TextStyle(color: Colors.white),
              maxLength: 1000,
              maxLines: null,
              decoration: InputDecoration(
                hintText: '메시지를 입력하세요...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                filled: true,
                fillColor: AppTheme.darkCard,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                counterText: '', // 글자수 카운터 숨기기
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          // 전송 버튼
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
              ),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _sendMessage,
              icon: const Icon(Icons.send, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: const Text('신고하기', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildReportOption('욕설/비방'),
            _buildReportOption('음란물'),
            _buildReportOption('스팸/광고'),
            _buildReportOption('기타'),
          ],
        ),
      ),
    );
  }

  Widget _buildReportOption(String reason) {
    return ListTile(
      title: Text(reason, style: const TextStyle(color: Colors.white70)),
      onTap: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('신고가 접수되었습니다.')),
        );
      },
    );
  }

  void _showBlockDialog() {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final partner = chatProvider.partner;
    
    if (partner == null) return;
    
    // 테스트 봇은 차단 불가
    if (partner.id.startsWith('test_bot')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('테스트 봇은 차단할 수 없습니다.')),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: const Text('차단하기', style: TextStyle(color: Colors.white)),
        content: Text(
          '${partner.nickname}님을 차단하시겠습니까?\n\n차단하면 다시 매칭되지 않으며, 설정에서 해제할 수 있습니다.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              
              try {
                // 차단 API 호출
                final apiService = ApiService();
                await apiService.post('/api/auth/block/${partner.id}', {});
                
                // 채팅 종료
                chatProvider.endChat();
                
                if (mounted) {
                  context.go('/home');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${partner.nickname}님을 차단했습니다.')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('차단 실패: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('차단'),
          ),
        ],
      ),
    );
  }
}

// 이미지 확대 뷰어 화면
class _ImageViewerScreen extends StatefulWidget {
  final String imageUrl;
  
  const _ImageViewerScreen({required this.imageUrl});

  @override
  State<_ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<_ImageViewerScreen> {
  final TransformationController _transformationController = TransformationController();
  final _noScreenshot = NoScreenshot.instance;
  
  @override
  void initState() {
    super.initState();
    // 이미지 뷰어에서도 스크린샷 방지
    _enableSecureMode();
  }
  
  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }
  
  Future<void> _enableSecureMode() async {
    try {
      await _noScreenshot.screenshotOff();
    } catch (e) {
      print('스크린샷 방지 오류: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_out_map, color: Colors.white),
            onPressed: () {
              _transformationController.value = Matrix4.identity();
            },
            tooltip: '원래 크기로',
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          transformationController: _transformationController,
          minScale: 0.5,
          maxScale: 4.0,
          child: CachedNetworkImage(
            imageUrl: widget.imageUrl,
            fit: BoxFit.contain,
            placeholder: (context, url) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            errorWidget: (context, url, error) => const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, color: Colors.white54, size: 48),
                SizedBox(height: 16),
                Text(
                  '이미지를 불러올 수 없습니다',
                  style: TextStyle(color: Colors.white54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
