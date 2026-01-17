import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/theme.dart';
import '../services/api_service.dart';

/// 배지 아이콘 매핑
IconData _getBadgeIcon(String? iconName) {
  switch (iconName) {
    case 'eco': return Icons.eco;
    case 'military_tech': return Icons.military_tech;
    case 'diamond': return Icons.diamond;
    case 'workspace_premium': return Icons.workspace_premium;
    case 'auto_awesome': return Icons.auto_awesome;
    case 'local_fire_department': return Icons.local_fire_department;
    default: return Icons.card_giftcard;
  }
}

Color _getBadgeColor(int? colorValue) {
  if (colorValue == null) return Colors.grey;
  return Color(colorValue);
}

class GiftRankingScreen extends StatefulWidget {
  const GiftRankingScreen({super.key});

  @override
  State<GiftRankingScreen> createState() => _GiftRankingScreenState();
}

class _GiftRankingScreenState extends State<GiftRankingScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _ranking = [];
  Map<String, dynamic>? _myStats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final results = await Future.wait([
        _apiService.get('/api/gifts/ranking?limit=50'),
        _apiService.get('/api/gifts/my-stats'),
      ]);
      
      setState(() {
        _ranking = results[0]['ranking'] ?? [];
        _myStats = results[1]['stats'];
        _isLoading = false;
      });
    } catch (e) {
      print('랭킹 로드 오류: $e');
      setState(() => _isLoading = false);
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
        title: Row(
          children: const [
            Icon(Icons.card_giftcard, color: Colors.pink),
            SizedBox(width: 8),
            Text('인기 랭킹', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                slivers: [
                  // 내 통계
                  if (_myStats != null) SliverToBoxAdapter(child: _buildMyStats()),
                  
                  // 랭킹 헤더
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: const [
                          Icon(Icons.emoji_events, color: Colors.amber),
                          SizedBox(width: 8),
                          Text(
                            '선물 랭킹 TOP 50',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // 랭킹 리스트
                  _ranking.isEmpty
                      ? SliverFillRemaining(child: _buildEmptyState())
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _buildRankingTile(_ranking[index]),
                            childCount: _ranking.length,
                          ),
                        ),
                ],
              ),
            ),
    );
  }

  Widget _buildMyStats() {
    final badge = _myStats!['badge'] as Map<String, dynamic>?;
    final nextBadge = _myStats!['nextBadge'] as Map<String, dynamic>?;
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade700, Colors.pink.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('내 선물 통계', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (badge != null && badge['icon'] != null && badge['icon'] != '')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(_getBadgeIcon(badge['icon']), size: 18, color: _getBadgeColor(badge['color'])),
                      const SizedBox(width: 6),
                      Text(badge['name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildStatItem('받은 선물', '${_myStats!['totalReceived'] ?? 0}개', Icons.card_giftcard),
              _buildStatItem('보낸 선물', '${_myStats!['totalSent'] ?? 0}개', Icons.send),
              _buildStatItem('획득 포인트', '${_myStats!['totalPointsEarned'] ?? 0}P', Icons.monetization_on),
            ],
          ),
          if (nextBadge != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _getBadgeIcon(nextBadge['icon']),
                    size: 24,
                    color: _getBadgeColor(nextBadge['color']),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '다음 등급: ${nextBadge['name']}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '선물 ${nextBadge['giftsNeeded']}개 더 받으면 달성!',
                          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white70, size: 24),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.card_giftcard, size: 64, color: Colors.white24),
          const SizedBox(height: 16),
          const Text(
            '아직 랭킹 데이터가 없습니다',
            style: TextStyle(color: Colors.white60, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            '선물을 주고받으면 랭킹에 등록됩니다!',
            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildRankingTile(dynamic user) {
    final rank = user['rank'] as int;
    final badge = user['badge'] as Map<String, dynamic>?;
    
    Color? rankColor;
    IconData? rankIcon;
    
    if (rank == 1) {
      rankColor = Colors.amber;
      rankIcon = Icons.emoji_events;
    } else if (rank == 2) {
      rankColor = Colors.grey.shade300;
      rankIcon = Icons.emoji_events;
    } else if (rank == 3) {
      rankColor = Colors.brown.shade300;
      rankIcon = Icons.emoji_events;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: rank <= 3 ? rankColor?.withOpacity(0.1) : AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: rank <= 3 ? Border.all(color: rankColor!.withOpacity(0.5)) : null,
      ),
      child: Row(
        children: [
          // 순위
          SizedBox(
            width: 40,
            child: rank <= 3
                ? Icon(rankIcon, color: rankColor, size: 28)
                : Text(
                    '$rank',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
          ),
          const SizedBox(width: 12),
          // 프로필 이미지
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.grey.shade700,
            backgroundImage: user['profileImage'] != null
                ? CachedNetworkImageProvider(user['profileImage'])
                : null,
            child: user['profileImage'] == null
                ? const Icon(Icons.person, color: Colors.white54)
                : null,
          ),
          const SizedBox(width: 16),
          // 닉네임 및 배지
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      user['nickname'] ?? '알 수 없음',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (badge != null && badge['icon'] != null && badge['icon'] != '') ...[
                      const SizedBox(width: 8),
                      Icon(
                        _getBadgeIcon(badge['icon']),
                        size: 16,
                        color: _getBadgeColor(badge['color']),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '받은 선물 ${user['totalReceived']}개 · +${user['totalPointsEarned'] ?? 0}P',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
