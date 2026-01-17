import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';

class VipShopScreen extends StatefulWidget {
  const VipShopScreen({super.key});

  @override
  State<VipShopScreen> createState() => _VipShopScreenState();
}

class _VipShopScreenState extends State<VipShopScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _vipStatus;
  List<Map<String, dynamic>> _tiers = [];
  bool _isLoading = true;
  bool _isPurchasing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final statusResponse = await _apiService.get('/api/vip/status');
      final tiersResponse = await _apiService.get('/api/vip/tiers');

      setState(() {
        _vipStatus = statusResponse;
        _tiers = List<Map<String, dynamic>>.from(tiersResponse['tiers'] ?? []);
      });
    } catch (e) {
      print('VIP 데이터 로드 오류: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _purchaseVip(String tier) async {
    final tierInfo = _tiers.firstWhere((t) => t['id'] == tier);
    final userPoints = _vipStatus?['points'] ?? 0;

    if (userPoints < tierInfo['price']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('포인트가 부족합니다. 충전 후 다시 시도해주세요.')),
      );
      context.push('/point-shop');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: Text('VIP ${tierInfo['name']} 구매', style: const TextStyle(color: Colors.white)),
        content: Text(
          '${tierInfo['price']}P를 사용하여 VIP ${tierInfo['name']}을(를) 구매하시겠습니까?\n\n유효기간: ${tierInfo['duration']}일',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: _getTierColor(tier)),
            child: const Text('구매'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isPurchasing = true);
    try {
      await _apiService.post('/api/vip/purchase', {'tier': tier});
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('VIP ${tierInfo['name']}이(가) 활성화되었습니다! 🎉')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('구매 실패: ${e.toString()}')),
        );
      }
    } finally {
      setState(() => _isPurchasing = false);
    }
  }

  Color _getTierColor(String tier) {
    switch (tier) {
      case 'gold':
        return Colors.amber;
      case 'silver':
        return Colors.blueGrey;
      case 'bronze':
        return Colors.brown;
      default:
        return AppTheme.primaryColor;
    }
  }

  IconData _getTierIcon(String tier) {
    switch (tier) {
      case 'gold':
        return Icons.workspace_premium;
      case 'silver':
        return Icons.star;
      case 'bronze':
        return Icons.grade;
      default:
        return Icons.card_membership;
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
        title: const Text('VIP 멤버십', style: TextStyle(color: Colors.white)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 현재 VIP 상태
                  _buildCurrentStatus(),
                  const SizedBox(height: 24),

                  // VIP 티어 목록
                  const Text(
                    'VIP 멤버십',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._tiers.map((tier) => _buildTierCard(tier)),
                ],
              ),
            ),
    );
  }

  Widget _buildCurrentStatus() {
    final isVip = _vipStatus?['isVip'] ?? false;
    final tier = _vipStatus?['tier'] ?? 'none';
    final daysRemaining = _vipStatus?['daysRemaining'] ?? 0;
    final points = _vipStatus?['points'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isVip
            ? LinearGradient(
                colors: [
                  _getTierColor(tier).withOpacity(0.3),
                  AppTheme.darkCard,
                ],
              )
            : null,
        color: isVip ? null : AppTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: isVip ? Border.all(color: _getTierColor(tier), width: 2) : null,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                isVip ? _getTierIcon(tier) : Icons.person,
                color: isVip ? _getTierColor(tier) : Colors.white60,
                size: 40,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isVip ? 'VIP ${_vipStatus?['tierInfo']?['name'] ?? tier.toUpperCase()}' : '일반 회원',
                      style: TextStyle(
                        color: isVip ? _getTierColor(tier) : Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isVip)
                      Text(
                        '$daysRemaining일 남음',
                        style: const TextStyle(color: Colors.white60, fontSize: 14),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.monetization_on, color: Colors.amber, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      '$points P',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!isVip) ...[
            const SizedBox(height: 16),
            const Text(
              'VIP가 되어 더 많은 혜택을 누려보세요!',
              style: TextStyle(color: Colors.white60, fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTierCard(Map<String, dynamic> tier) {
    final tierId = tier['id'] as String;
    final name = tier['name'] as String;
    final price = tier['price'] as int;
    final duration = tier['duration'] as int;
    final benefits = List<String>.from(tier['benefits'] ?? []);
    final isCurrentTier = _vipStatus?['tier'] == tierId;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: isCurrentTier
            ? Border.all(color: _getTierColor(tierId), width: 2)
            : null,
      ),
      child: Column(
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getTierColor(tierId).withOpacity(0.2),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Icon(_getTierIcon(tierId), color: _getTierColor(tierId), size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          color: _getTierColor(tierId),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '$duration일',
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$price P',
                  style: TextStyle(
                    color: _getTierColor(tierId),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // 혜택 목록
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ...benefits.map((benefit) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: _getTierColor(tierId), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              benefit,
                              style: const TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 12),

                // 구매 버튼
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isPurchasing || isCurrentTier
                        ? null
                        : () => _purchaseVip(tierId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _getTierColor(tierId),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      isCurrentTier ? '현재 사용 중' : '구매하기',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
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
