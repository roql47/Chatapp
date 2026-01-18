import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:no_screenshot/no_screenshot.dart';
import '../config/theme.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../providers/auth_provider.dart';
import '../models/chat_message.dart';
import '../widgets/profile_image_viewer.dart';
import '../widgets/blurred_image.dart';

class DMChatScreen extends StatefulWidget {
  final String roomId;
  final Map<String, dynamic> partner;

  const DMChatScreen({
    super.key,
    required this.roomId,
    required this.partner,
  });

  @override
  State<DMChatScreen> createState() => _DMChatScreenState();
}

class _DMChatScreenState extends State<DMChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ApiService _apiService = ApiService();
  final SocketService _socketService = SocketService();
  
  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _partnerTyping = false;

  @override
  void initState() {
    super.initState();
    _enableSecureMode();
    _loadMessages();
    _setupSocketListeners();
    _socketService.joinRoom(widget.roomId);
  }

  @override
  void dispose() {
    _disableSecureMode();
    _messageController.dispose();
    _scrollController.dispose();
    _socketService.leaveRoom(widget.roomId);
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

  void _setupSocketListeners() {
    _socketService.onMessageReceived = (message) {
      if (message.roomId == widget.roomId) {
        setState(() {
          _messages.add(message);
        });
        _scrollToBottom();
      }
    };

    _socketService.onTypingStatus = (userId, isTyping) {
      if (userId == widget.partner['id']) {
        setState(() {
          _partnerTyping = isTyping;
        });
      }
    };
  }

  Future<void> _loadMessages() async {
    try {
      final response = await _apiService.get(
        '/api/friends/dm/${widget.partner['id']}/messages?limit=100',
      );
      
      final messagesList = response['messages'] as List? ?? [];
      setState(() {
        _messages = messagesList.map((m) => ChatMessage(
          id: m['_id'] ?? '',
          roomId: widget.roomId,
          senderId: m['senderId'] ?? '',
          senderNickname: m['senderNickname'] ?? '',
          content: m['content'] ?? '',
          type: m['type'] == 'image' ? MessageType.image : MessageType.text,
          timestamp: DateTime.parse(m['timestamp'] ?? DateTime.now().toIso8601String()),
        )).toList();
        _isLoading = false;
      });
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      print('메시지 로드 오류: $e');
      setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    if (user == null) return;

    setState(() => _isSending = true);
    _messageController.clear();

    final message = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      roomId: widget.roomId,
      senderId: user.id,
      senderNickname: user.nickname,
      content: content,
      type: MessageType.text,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(message);
    });
    _scrollToBottom();

    // 소켓으로 메시지 전송
    _socketService.sendMessage(message);

    setState(() => _isSending = false);
  }

  void _showPartnerProfile() {
    ProfileImageViewer.show(
      context,
      imageUrl: widget.partner['profileImage'],
      nickname: widget.partner['nickname'] ?? '친구',
      heroTag: 'dm_partner_${widget.partner['id']}',
      mbti: widget.partner['mbti'],
      interests: (widget.partner['interests'] as List?)?.cast<String>(),
      gender: widget.partner['gender'],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUserId = authProvider.user?.id ?? '';

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // 메시지 목록
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length + (_partnerTyping ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (_partnerTyping && index == _messages.length) {
                            return _buildTypingIndicator();
                          }
                          return _buildMessageBubble(
                            _messages[index],
                            _messages[index].senderId == currentUserId,
                          );
                        },
                      ),
          ),
          // 메시지 입력
          _buildMessageInput(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final partnerName = widget.partner['nickname'] ?? '친구';
    final partnerImage = widget.partner['profileImage'];
    final isOnline = widget.partner['isOnline'] ?? false;

    return AppBar(
      backgroundColor: AppTheme.darkSurface,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white70),
        onPressed: () => context.pop(),
      ),
      title: GestureDetector(
        onTap: _showPartnerProfile,
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppTheme.primaryColor,
                  backgroundImage: partnerImage != null
                      ? CachedNetworkImageProvider(partnerImage)
                      : null,
                  child: partnerImage == null
                      ? const Icon(Icons.person, color: Colors.white, size: 20)
                      : null,
                ),
                if (isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.darkSurface, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  partnerName,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                Text(
                  isOnline ? '온라인' : '오프라인',
                  style: TextStyle(
                    color: isOnline ? Colors.green : Colors.white38,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.people, color: Colors.blue, size: 16),
              SizedBox(width: 4),
              Text('친구', style: TextStyle(color: Colors.blue, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.white24),
          const SizedBox(height: 16),
          Text(
            '${widget.partner['nickname']}님과의 대화를 시작하세요!',
            style: const TextStyle(color: Colors.white60, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            '첫 메시지를 보내보세요 💬',
            style: TextStyle(color: Colors.white38, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isMe) {
    final isImage = message.type == MessageType.image;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            GestureDetector(
              onTap: _showPartnerProfile,
              child: CircleAvatar(
                radius: 16,
                backgroundColor: AppTheme.primaryColor,
                backgroundImage: widget.partner['profileImage'] != null
                    ? CachedNetworkImageProvider(widget.partner['profileImage'])
                    : null,
                child: widget.partner['profileImage'] == null
                    ? const Icon(Icons.person, color: Colors.white, size: 16)
                    : null,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: isImage 
                  ? const EdgeInsets.all(4)
                  : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? AppTheme.primaryColor : AppTheme.darkCard,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isImage)
                    BlurredImage(
                      imageUrl: message.content,
                      width: 200,
                      onTapFullScreen: () => _showImageViewer(message.content),
                    )
                  else
                    Text(
                      message.content,
                      style: TextStyle(
                        color: isMe ? Colors.white : Colors.white.withOpacity(0.9),
                        fontSize: 15,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      color: isMe ? Colors.white60 : Colors.white38,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }
  
  // 이미지 전체화면 보기
  void _showImageViewer(String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullScreenImageViewer(imageUrl: imageUrl),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.primaryColor,
            backgroundImage: widget.partner['profileImage'] != null
                ? CachedNetworkImageProvider(widget.partner['profileImage'])
                : null,
            child: widget.partner['profileImage'] == null
                ? const Icon(Icons.person, color: Colors.white, size: 16)
                : null,
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + (index * 200)),
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

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.darkCard,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: Colors.white),
                maxLines: null,
                decoration: const InputDecoration(
                  hintText: '메시지를 입력하세요...',
                  hintStyle: TextStyle(color: Colors.white38),
                  border: InputBorder.none,
                ),
                onChanged: (text) {
                  _socketService.sendTypingStatus(widget.roomId, text.isNotEmpty);
                },
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

// 이미지 전체 화면 뷰어
class _FullScreenImageViewer extends StatefulWidget {
  final String imageUrl;
  
  const _FullScreenImageViewer({required this.imageUrl});
  
  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  final TransformationController _transformationController = TransformationController();
  
  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
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
