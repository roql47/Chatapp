import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/theme.dart';
import '../services/api_service.dart';

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

  Future<void> _unblockUser(String userId, String nickname) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Text('차단 해제', style: TextStyle(color: Colors.white)),
        content: Text(
          '$nickname님의 차단을 해제하시겠습니까?\n\n해제 후 다시 매칭될 수 있습니다.',
          style: const TextStyle(color: Colors.white70),
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
            child: const Text('해제'),
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
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkSurface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => context.pop(),
        ),
        title: const Text('차단된 사용자', style: TextStyle(color: Colors.white)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _blockedUsers.isEmpty
              ? _buildEmptyState()
              : _buildBlockedList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.block, size: 64, color: Colors.white24),
          const SizedBox(height: 16),
          const Text(
            '차단된 사용자가 없습니다',
            style: TextStyle(color: Colors.white60, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            '채팅에서 불쾌한 상대를 차단하면\n여기에서 관리할 수 있어요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockedList() {
    return RefreshIndicator(
      onRefresh: _loadBlockedUsers,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _blockedUsers.length,
        itemBuilder: (context, index) {
          final user = _blockedUsers[index];
          return _buildBlockedUserTile(user);
        },
      ),
    );
  }

  Widget _buildBlockedUserTile(dynamic user) {
    final userId = user['_id']?.toString() ?? user['id']?.toString() ?? '';
    final nickname = user['nickname'] ?? '알 수 없음';
    final profileImage = user['profileImage'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // 프로필 이미지
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.grey.shade700,
            backgroundImage: profileImage != null
                ? CachedNetworkImageProvider(profileImage)
                : null,
            child: profileImage == null
                ? const Icon(Icons.person, color: Colors.white54)
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
                  style: const TextStyle(
                    color: Colors.white,
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
            onPressed: () => _unblockUser(userId, nickname),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Colors.white24),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('해제'),
          ),
        ],
      ),
    );
  }
}
