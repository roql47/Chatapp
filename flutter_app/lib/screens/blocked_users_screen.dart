import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/theme.dart';
import '../services/api_service.dart';
import '../providers/theme_provider.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _blockedUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    setState(() => _isLoading = true);
    
    try {
      final response = await _apiService.get('/api/auth/blocked');
      setState(() {
        _blockedUsers = response['blockedUsers'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      print('차단 목록 로드 오류: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _unblockUser(String userId, String nickname, bool isDark) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
        title: Text('차단 해제', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
        content: Text(
          '$nickname님의 차단을 해제하시겠습니까?\n\n해제 후 다시 매칭될 수 있습니다.',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('해제', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _apiService.delete('/api/auth/block/$userId');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$nickname님의 차단이 해제되었습니다.')),
          );
        }
        
        _loadBlockedUsers();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('차단 해제 실패: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    
    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        elevation: isDark ? 0 : 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white70 : Colors.black54),
          onPressed: () => context.pop(),
        ),
        title: Text('차단된 사용자', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _blockedUsers.isEmpty
              ? _buildEmptyState(isDark)
              : _buildBlockedList(isDark),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.block, size: 64, color: isDark ? Colors.white24 : Colors.black26),
          const SizedBox(height: 16),
          Text(
            '차단된 사용자가 없습니다',
            style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            '채팅에서 불쾌한 상대를 차단하면\n여기에서 관리할 수 있어요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockedList(bool isDark) {
    return RefreshIndicator(
      onRefresh: _loadBlockedUsers,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _blockedUsers.length,
        itemBuilder: (context, index) {
          final user = _blockedUsers[index];
          return _buildBlockedUserTile(user, isDark);
        },
      ),
    );
  }

  Widget _buildBlockedUserTile(dynamic user, bool isDark) {
    final userId = user['_id']?.toString() ?? user['id']?.toString() ?? '';
    final nickname = user['nickname'] ?? '알 수 없음';
    final profileImage = user['profileImage'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isDark ? null : [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 프로필 이미지
          CircleAvatar(
            radius: 24,
            backgroundColor: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
            backgroundImage: profileImage != null
                ? CachedNetworkImageProvider(profileImage)
                : null,
            child: profileImage == null
                ? Icon(Icons.person, color: isDark ? Colors.white54 : Colors.black38)
                : null,
          ),
          const SizedBox(width: 16),
          // 닉네임
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nickname,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.block, size: 14, color: Colors.redAccent.shade200),
                    const SizedBox(width: 4),
                    Text(
                      '차단됨',
                      style: TextStyle(
                        color: Colors.redAccent.shade200,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 차단 해제 버튼
          OutlinedButton(
            onPressed: () => _unblockUser(userId, nickname, isDark),
            style: OutlinedButton.styleFrom(
              foregroundColor: isDark ? Colors.white70 : Colors.black54,
              side: BorderSide(color: isDark ? Colors.white24 : Colors.black26),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('해제'),
          ),
        ],
      ),
    );
  }
}
