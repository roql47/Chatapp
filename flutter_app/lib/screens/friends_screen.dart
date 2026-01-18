import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../services/api_service.dart';
import '../models/friend_model.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();
  
  List<FriendModel> _friends = [];
  List<FriendModel> _receivedRequests = [];
  List<FriendModel> _sentRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      // 친구 목록 로드
      final friendsResponse = await _apiService.get('/api/friends/list');
      _friends = (friendsResponse['friends'] as List? ?? [])
          .map((f) => FriendModel.fromJson(f))
          .toList();

      // 받은 요청 로드
      final receivedResponse = await _apiService.get('/api/friends/requests/received');
      _receivedRequests = (receivedResponse['requests'] as List? ?? [])
          .map((r) => FriendModel.fromJson(r))
          .toList();

      // 보낸 요청 로드
      final sentResponse = await _apiService.get('/api/friends/requests/sent');
      _sentRequests = (sentResponse['requests'] as List? ?? [])
          .map((r) => FriendModel.fromJson(r))
          .toList();
    } catch (e) {
      print('친구 데이터 로드 오류: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _acceptRequest(String requestId) async {
    try {
      await _apiService.post('/api/friends/accept/$requestId', {});
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('친구 요청을 수락했습니다.')),
        );
      }
    } catch (e) {
      print('친구 수락 오류: $e');
    }
  }

  Future<void> _rejectRequest(String requestId) async {
    try {
      await _apiService.post('/api/friends/reject/$requestId', {});
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('친구 요청을 거절했습니다.')),
        );
      }
    } catch (e) {
      print('친구 거절 오류: $e');
    }
  }

  Future<void> _deleteFriend(String friendId, bool isDark) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
        title: Text('친구 삭제', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
        content: Text('정말 친구를 삭제하시겠습니까?',
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('삭제', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _apiService.delete('/api/friends/$friendId');
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('친구가 삭제되었습니다.')),
          );
        }
      } catch (e) {
        print('친구 삭제 오류: $e');
      }
    }
  }

  // 친구와 DM 시작
  Future<void> _startDM(FriendModel friend) async {
    try {
      // 로딩 표시
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // DM 채팅방 생성/조회
      final response = await _apiService.post('/api/friends/dm/${friend.friendUserId}', {});
      
      if (!mounted) return;
      Navigator.pop(context); // 로딩 닫기

      // 채팅 화면으로 이동
      context.push('/dm-chat', extra: {
        'roomId': response['room']['id'],
        'partner': response['partner'],
        'isDM': true,
      });
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // 로딩 닫기
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('DM 시작 오류: $e')),
        );
      }
      print('DM 시작 오류: $e');
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
        title: Text('친구', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: isDark ? Colors.white60 : Colors.black45,
          tabs: [
            Tab(text: '친구 ${_friends.length}'),
            Tab(text: '받은 요청 ${_receivedRequests.length}'),
            Tab(text: '보낸 요청 ${_sentRequests.length}'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildFriendsList(isDark),
                _buildReceivedRequestsList(isDark),
                _buildSentRequestsList(isDark),
              ],
            ),
    );
  }

  Widget _buildFriendsList(bool isDark) {
    if (_friends.isEmpty) {
      return _buildEmptyState(
        icon: Icons.people_outline,
        title: '아직 친구가 없어요',
        subtitle: '채팅에서 마음이 맞는 상대에게\n친구 요청을 보내보세요!',
        isDark: isDark,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _friends.length,
        itemBuilder: (context, index) => _buildFriendTile(_friends[index], isDark),
      ),
    );
  }

  Widget _buildReceivedRequestsList(bool isDark) {
    if (_receivedRequests.isEmpty) {
      return _buildEmptyState(
        icon: Icons.mail_outline,
        title: '받은 친구 요청이 없어요',
        subtitle: '새로운 친구 요청이 오면 여기에 표시됩니다.',
        isDark: isDark,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _receivedRequests.length,
        itemBuilder: (context, index) =>
            _buildReceivedRequestTile(_receivedRequests[index], isDark),
      ),
    );
  }

  Widget _buildSentRequestsList(bool isDark) {
    if (_sentRequests.isEmpty) {
      return _buildEmptyState(
        icon: Icons.send,
        title: '보낸 친구 요청이 없어요',
        subtitle: '채팅에서 친구 요청을 보내면\n여기에 표시됩니다.',
        isDark: isDark,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _sentRequests.length,
        itemBuilder: (context, index) =>
            _buildSentRequestTile(_sentRequests[index], isDark),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: isDark ? Colors.white24 : Colors.black26),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendTile(FriendModel friend, bool isDark) {
    return GestureDetector(
      onTap: () => _startDM(friend),
      child: Container(
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
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppTheme.primaryColor,
                  backgroundImage: friend.profileImage != null
                      ? NetworkImage(friend.profileImage!)
                      : null,
                  child: friend.profileImage == null
                      ? const Icon(Icons.person, color: Colors.white, size: 28)
                      : null,
                ),
                if (friend.isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? AppTheme.darkCard : Colors.white, 
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            // 닉네임 및 최신 메시지
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          friend.nickname,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // 최신 메시지 시간
                      if (friend.lastMessageTime != null)
                        Text(
                          _formatMessageTime(friend.lastMessageTime!),
                          style: TextStyle(
                            color: isDark ? Colors.white38 : Colors.black38,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          friend.lastMessage ?? (friend.isOnline ? '온라인' : '오프라인'),
                          style: TextStyle(
                            color: friend.lastMessage != null 
                                ? (isDark ? Colors.white60 : Colors.black54)
                                : (friend.isOnline ? Colors.green : (isDark ? Colors.white38 : Colors.black38)),
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // 읽지 않은 메시지 배지
                      if (friend.unreadCount > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            friend.unreadCount > 99 ? '99+' : '${friend.unreadCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            // 더보기 버튼
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: isDark ? Colors.white38 : Colors.black38),
              color: isDark ? AppTheme.darkCard : Colors.white,
              onSelected: (value) {
                if (value == 'delete') {
                  _deleteFriend(friend.id, isDark);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.person_remove, color: Colors.redAccent, size: 20),
                      SizedBox(width: 8),
                      Text('친구 삭제', style: TextStyle(color: Colors.redAccent)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  // 메시지 시간 포맷팅 (카카오톡 스타일)
  String _formatMessageTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inDays == 0) {
      // 오늘
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      // 어제
      return '어제';
    } else if (diff.inDays < 7) {
      // 이번 주
      const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
      return '${weekdays[time.weekday - 1]}요일';
    } else {
      // 그 이전
      return '${time.month}/${time.day}';
    }
  }

  Widget _buildReceivedRequestTile(FriendModel request, bool isDark) {
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
          CircleAvatar(
            radius: 24,
            backgroundColor: AppTheme.primaryColor,
            backgroundImage: request.profileImage != null
                ? NetworkImage(request.profileImage!)
                : null,
            child: request.profileImage == null
                ? const Icon(Icons.person, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              request.nickname,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // 수락/거절 버튼
          Row(
            children: [
              IconButton(
                onPressed: () => _acceptRequest(request.id),
                icon: const Icon(Icons.check_circle, color: Colors.green),
              ),
              IconButton(
                onPressed: () => _rejectRequest(request.id),
                icon: const Icon(Icons.cancel, color: Colors.redAccent),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSentRequestTile(FriendModel request, bool isDark) {
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
          CircleAvatar(
            radius: 24,
            backgroundColor: AppTheme.primaryColor,
            backgroundImage: request.profileImage != null
                ? NetworkImage(request.profileImage!)
                : null,
            child: request.profileImage == null
                ? const Icon(Icons.person, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.nickname,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Text(
                  '대기 중',
                  style: TextStyle(color: Colors.amber, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
