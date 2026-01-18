import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../config/theme.dart';
import '../services/ad_service.dart';

class PointShopScreen extends StatefulWidget {
  const PointShopScreen({super.key});

  @override
  State<PointShopScreen> createState() => _PointShopScreenState();
}

class _PointShopScreenState extends State<PointShopScreen> {
  bool _isLoading = false;

  // 포인트 패키지 정의
  final List<Map<String, dynamic>> _packages = [
    {
      'id': 'points_100',
      'points': 100,
      'price': '₩1,100',
      'priceValue': 1100,
      'bonus': 0,
    },
    {
      'id': 'points_400',
      'points': 400,
      'price': '₩4,400',
      'priceValue': 4400,
      'bonus': 50,
    },
    {
      'id': 'points_700',
      'points': 700,
      'price': '₩7,700',
      'priceValue': 7700,
      'bonus': 80,
    },
    {
      'id': 'points_1000',
      'points': 1000,
      'price': '₩11,000',
      'priceValue': 11000,
      'bonus': 150,
    },
    {
      'id': 'points_1500',
      'points': 1500,
      'price': '₩16,500',
      'priceValue': 16500,
      'bonus': 250,
    },
    {
      'id': 'points_3000',
      'points': 3000,
      'price': '₩33,000',
      'priceValue': 33000,
      'bonus': 600,
    },
  ];

  Future<void> _purchasePoints(Map<String, dynamic> package) async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final totalPoints = package['points'] + package['bonus'];
      
      // TODO: 실제 인앱결제 연동
      // 지금은 테스트용으로 바로 충전
      final success = await authProvider.chargePoints(
        totalPoints,
        package['id'],
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${totalPoints}P 충전 완료!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('충전에 실패했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

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
              // 앱바
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back, color: Colors.white70),
                    ),
                    const Expanded(
                      child: Text(
                        '포인트 충전',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // 현재 포인트 표시
                      _buildCurrentPoints(user?.points ?? 0),
                      const SizedBox(height: 24),
                      
                      // 포인트 패키지
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '포인트 패키지',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      ..._packages.map((pkg) => _buildPackageCard(pkg)),
                      
                      const SizedBox(height: 32),
                      
                      // 광고 제거 패키지
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '광고 제거',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      _buildAdRemovalCard(),
                      
                      const SizedBox(height: 24),
                      
                      // 포인트 사용 안내
                      _buildPointsInfo(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentPoints(int points) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withOpacity(0.3),
            AppTheme.secondaryColor.withOpacity(0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '보유 포인트',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.monetization_on,
                    color: Colors.amber,
                    size: 32,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$points P',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Icon(Icons.history, color: Colors.white, size: 16),
                SizedBox(width: 4),
                Text(
                  '내역',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageCard(Map<String, dynamic> package) {
    final hasBonus = package['bonus'] > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // 포인트 아이콘
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.monetization_on,
                color: Colors.amber,
                size: 36,
              ),
            ),
            const SizedBox(width: 16),
            
            // 포인트 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${package['points']}P',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (hasBonus) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '+${package['bonus']}P',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasBonus
                        ? '총 ${package['points'] + package['bonus']}P'
                        : '',
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            
            // 가격 버튼
            ElevatedButton(
              onPressed: _isLoading ? null : () => _purchasePoints(package),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.darkSurface,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      package['price'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdRemovalCard() {
    final adService = AdService();
    final isAdRemoved = adService.isAdRemoved;
    
    return Container(
      decoration: BoxDecoration(
        gradient: isAdRemoved
            ? null
            : LinearGradient(
                colors: [
                  Colors.purple.withOpacity(0.3),
                  Colors.blue.withOpacity(0.3),
                ],
              ),
        color: isAdRemoved ? AppTheme.darkCard : null,
        borderRadius: BorderRadius.circular(16),
        border: isAdRemoved
            ? null
            : Border.all(color: Colors.purple.withOpacity(0.5), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // 아이콘
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: isAdRemoved
                    ? Colors.green.withOpacity(0.2)
                    : Colors.purple.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isAdRemoved ? Icons.check_circle : Icons.block,
                color: isAdRemoved ? Colors.green : Colors.purple,
                size: 36,
              ),
            ),
            const SizedBox(width: 16),
            
            // 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAdRemoved ? '광고 제거됨' : '광고 제거',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isAdRemoved
                        ? '모든 광고가 제거되었습니다'
                        : '영구적으로 모든 광고 제거',
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            
            // 버튼
            if (!isAdRemoved)
              ElevatedButton(
                onPressed: _isLoading ? null : _purchaseAdRemoval,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        '₩4,400',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check, color: Colors.green, size: 18),
                    SizedBox(width: 4),
                    Text(
                      '구매 완료',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _purchaseAdRemoval() async {
    setState(() => _isLoading = true);
    
    try {
      final adService = AdService();
      final success = await adService.purchaseAdRemoval();
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('광고가 제거되었습니다! 🎉'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {}); // UI 새로고침
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('구매에 실패했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildPointsInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            '포인트 사용 안내',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12),
          _InfoRow(icon: Icons.filter_alt, text: '성별 필터 매칭: 10P'),
          SizedBox(height: 8),
          _InfoRow(icon: Icons.card_giftcard, text: '신규 가입 보너스: 100P'),
          SizedBox(height: 8),
          _InfoRow(icon: Icons.info_outline, text: '포인트는 환불되지 않습니다'),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white38, size: 18),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
