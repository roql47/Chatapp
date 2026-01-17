import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/auth_service.dart';

class ChatHistoryScreen extends StatefulWidget {
  const ChatHistoryScreen({super.key});

  @override
  State<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen> {
  List<Map<String, dynamic>> _chatHistory = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  Future<void> _loadChatHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final token = authProvider.isLoggedIn ? AuthService().authToken : null;

      if (token == null) {
        setState(() {
          _error = '로그인이 필요합니다.';
          _isLoading = false;
        });
        return;
      }

      final apiService = ApiService();
      final response = await apiService.getChatHistory(token);

      setState(() {
        _chatHistory = List<Map<String, dynamic>>.from(response['history'] ?? []);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '채팅 기록을 불러오는데 실패했습니다.';
        _isLoading = false;
      });
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '';
    final date = DateTime.parse(dateString).toLocal();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return '오늘 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return '어제';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      return '${date.month}/${date.day}';
    }
  }

  String _getLastMessagePreview(Map<String, dynamic>? lastMessage) {
    if (lastMessage == null) return '메시지 없음';
    
    final type = lastMessage['type'];
    if (type == 'image') return '📷 이미지';
    if (type == 'system') return '🔔 시스템 메시지';
    
    final content = lastMessage['content'] ?? '';
    return content.length > 30 ? '${content.substring(0, 30)}...' : content;
  }

  // 전체 삭제 확인
  void _confirmDeleteAll() {
    final themeProvider = context.read<ThemeProvider>();
    final isDark = themeProvider.themeMode == ThemeMode.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1a1a2e) : Colors.white,
        title: Text(
          '전체 채팅 기록 삭제',
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        ),
        content: Text(
          '모든 채팅 기록을 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.',
          style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소', style: TextStyle(color: Colors.grey[500])),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAllHistory();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // 전체 삭제 실행
  Future<void> _deleteAllHistory() async {
    try {
      final apiService = ApiService();
      await apiService.delete('/api/chat/history/all');
      
      setState(() {
        _chatHistory.clear();
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('전체 채팅 기록이 삭제되었습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 실패: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // 개별 삭제 확인
  void _confirmDeleteChat(Map<String, dynamic> chat) {
    final themeProvider = context.read<ThemeProvider>();
    final isDark = themeProvider.themeMode == ThemeMode.dark;
    final partner = chat['partner'] as Map<String, dynamic>?;
    final partnerNickname = partner?['nickname'] ?? '알 수 없음';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1a1a2e) : Colors.white,
        title: Text(
          '채팅 기록 삭제',
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        ),
        content: Text(
          '$partnerNickname님과의 채팅 기록을 삭제하시겠습니까?',
          style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소', style: TextStyle(color: Colors.grey[500])),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteChatHistory(chat);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // 개별 삭제 실행
  Future<void> _deleteChatHistory(Map<String, dynamic> chat) async {
    final roomId = chat['roomId'];
    
    try {
      final apiService = ApiService();
      await apiService.delete('/api/chat/room/$roomId');
      
      setState(() {
        _chatHistory.removeWhere((c) => c['roomId'] == roomId);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('채팅 기록이 삭제되었습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 실패: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.themeMode == ThemeMode.dark;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: isDark 
          ? const Color(0xFF1a1a2e) 
          : theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDark 
            ? const Color(0xFF16213e) 
            : theme.primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/home'),
        ),
        title: const Text(
          '채팅 기록',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadChatHistory,
          ),
          if (_chatHistory.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (value) {
                if (value == 'delete_all') {
                  _confirmDeleteAll();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete_all',
                  child: Row(
                    children: [
                      Icon(Icons.delete_sweep, color: Colors.red),
                      SizedBox(width: 8),
                      Text('전체 삭제', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _buildBody(isDark, theme),
    );
  }

  Widget _buildBody(bool isDark, ThemeData theme) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: isDark ? Colors.pinkAccent : theme.primaryColor,
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadChatHistory,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.pinkAccent : theme.primaryColor,
              ),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (_chatHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 80,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              '채팅 기록이 없습니다',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '새로운 대화를 시작해보세요!',
              style: TextStyle(
                color: isDark ? Colors.grey[500] : Colors.grey[500],
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadChatHistory,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _chatHistory.length,
        itemBuilder: (context, index) {
          final chat = _chatHistory[index];
          return _buildChatItem(chat, isDark, theme);
        },
      ),
    );
  }

  Widget _buildChatItem(Map<String, dynamic> chat, bool isDark, ThemeData theme) {
    final partner = chat['partner'] as Map<String, dynamic>?;
    final lastMessage = chat['lastMessage'] as Map<String, dynamic>?;
    final isActive = chat['isActive'] ?? false;
    final messageCount = chat['messageCount'] ?? 0;
    final roomId = chat['roomId']?.toString() ?? '';

    final partnerNickname = partner?['nickname'] ?? '알 수 없음';
    final partnerImage = partner?['profileImage'];
    final lastMessageTime = lastMessage?['timestamp'];

    return Dismissible(
      key: Key(roomId),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1a1a2e) : Colors.white,
            title: Text(
              '채팅 기록 삭제',
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            ),
            content: Text(
              '$partnerNickname님과의 채팅 기록을 삭제하시겠습니까?',
              style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700]),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('취소', style: TextStyle(color: Colors.grey[500])),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('삭제', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (direction) {
        _deleteChatHistory(chat);
      },
      child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark 
            ? Colors.white.withOpacity(0.05) 
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isActive 
            ? Border.all(color: Colors.greenAccent.withOpacity(0.5), width: 1)
            : null,
        boxShadow: isDark ? null : [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: isDark 
                  ? Colors.pinkAccent.withOpacity(0.2) 
                  : theme.primaryColor.withOpacity(0.2),
              backgroundImage: partnerImage != null 
                  ? NetworkImage(partnerImage) 
                  : null,
              child: partnerImage == null
                  ? Text(
                      partnerNickname.isNotEmpty ? partnerNickname[0] : '?',
                      style: TextStyle(
                        color: isDark ? Colors.pinkAccent : theme.primaryColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            if (isActive)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.greenAccent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? const Color(0xFF1a1a2e) : Colors.white,
                      width: 2,
                    ),
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                partnerNickname,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (lastMessageTime != null)
              Text(
                _formatDate(lastMessageTime),
                style: TextStyle(
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                  fontSize: 12,
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              _getLastMessagePreview(lastMessage),
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.message,
                  size: 12,
                  color: isDark ? Colors.grey[600] : Colors.grey[500],
                ),
                const SizedBox(width: 4),
                Text(
                  '$messageCount개의 메시지',
                  style: TextStyle(
                    color: isDark ? Colors.grey[600] : Colors.grey[500],
                    fontSize: 11,
                  ),
                ),
                if (!isActive) ...[
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '종료됨',
                      style: TextStyle(
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        onTap: () {
          // 채팅방 상세 보기 (향후 구현)
          _showChatDetail(chat);
        },
      ),
      ),
    );
  }

  void _showChatDetail(Map<String, dynamic> chat) {
    final partner = chat['partner'] as Map<String, dynamic>?;
    final partnerNickname = partner?['nickname'] ?? '알 수 없음';
    final messageCount = chat['messageCount'] ?? 0;
    final isActive = chat['isActive'] ?? false;
    final themeProvider = context.read<ThemeProvider>();
    final isDark = themeProvider.themeMode == ThemeMode.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1a1a2e) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            CircleAvatar(
              radius: 40,
              backgroundColor: isDark 
                  ? Colors.pinkAccent.withOpacity(0.2) 
                  : Theme.of(context).primaryColor.withOpacity(0.2),
              child: Text(
                partnerNickname.isNotEmpty ? partnerNickname[0] : '?',
                style: TextStyle(
                  color: isDark ? Colors.pinkAccent : Theme.of(context).primaryColor,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              partnerNickname,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '총 $messageCount개의 메시지',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isActive 
                    ? Colors.greenAccent.withOpacity(0.2) 
                    : Colors.grey.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isActive ? '진행 중' : '종료된 대화',
                style: TextStyle(
                  color: isActive ? Colors.greenAccent : Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  icon: Icons.message,
                  label: '메시지 보기',
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: 메시지 목록 화면으로 이동
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('메시지 보기 기능은 곧 추가됩니다')),
                    );
                  },
                  isDark: isDark,
                ),
                _buildActionButton(
                  icon: Icons.delete,
                  label: '삭제',
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDeleteChat(chat);
                  },
                  isDark: isDark,
                  isDestructive: true,
                ),
                if (isActive)
                  _buildActionButton(
                    icon: Icons.chat,
                    label: '대화 계속하기',
                    onTap: () {
                      Navigator.pop(context);
                      // TODO: 채팅 화면으로 이동
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('대화 계속하기 기능은 곧 추가됩니다')),
                      );
                    },
                    isDark: isDark,
                    isHighlighted: true,
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
    bool isHighlighted = false,
    bool isDestructive = false,
  }) {
    Color bgColor;
    Color fgColor;
    
    if (isDestructive) {
      bgColor = Colors.red.withOpacity(0.1);
      fgColor = Colors.red;
    } else if (isHighlighted) {
      bgColor = isDark ? Colors.pinkAccent : Theme.of(context).primaryColor;
      fgColor = Colors.white;
    } else {
      bgColor = isDark ? Colors.white.withOpacity(0.1) : Colors.grey[100]!;
      fgColor = isDark ? Colors.grey[300]! : Colors.grey[700]!;
    }
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: fgColor),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: fgColor, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
