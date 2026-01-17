import 'package:flutter/material.dart';
import 'dart:math';

/// 선물 아이콘 매핑
IconData _getGiftIcon(String? iconName) {
  switch (iconName) {
    case 'favorite': return Icons.favorite;
    case 'local_florist': return Icons.local_florist;
    case 'star': return Icons.star;
    case 'diamond': return Icons.diamond;
    case 'workspace_premium': return Icons.workspace_premium;
    case 'rocket_launch': return Icons.rocket_launch;
    default: return Icons.card_giftcard;
  }
}

Color _getGiftColor(int? colorValue) {
  if (colorValue == null) return Colors.pink;
  return Color(colorValue);
}

/// 선물 애니메이션 오버레이
class GiftAnimation extends StatefulWidget {
  final IconData giftIcon;
  final Color giftColor;
  final String giftName;
  final String senderName;
  final int rewardPoints;
  final VoidCallback onComplete;

  const GiftAnimation({
    super.key,
    required this.giftIcon,
    required this.giftColor,
    required this.giftName,
    required this.senderName,
    required this.rewardPoints,
    required this.onComplete,
  });

  /// 선물 애니메이션 표시
  static void show(BuildContext context, Map<String, dynamic> giftData, VoidCallback onComplete) {
    final giftInfo = giftData['giftInfo'] as Map<String, dynamic>?;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (context) => GiftAnimation(
        giftIcon: _getGiftIcon(giftInfo?['icon']),
        giftColor: _getGiftColor(giftInfo?['color']),
        giftName: giftInfo?['name'] ?? '선물',
        senderName: giftData['senderNickname'] ?? '누군가',
        rewardPoints: giftData['rewardPoints'] ?? 0,
        onComplete: () {
          Navigator.of(context).pop();
          onComplete();
        },
      ),
    );
  }

  @override
  State<GiftAnimation> createState() => _GiftAnimationState();
}

class _GiftAnimationState extends State<GiftAnimation> with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _particleController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _bounceAnimation;
  
  final List<_Particle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    
    // 메인 애니메이션
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );
    
    // 파티클 애니메이션
    _particleController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.5), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.5, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(CurvedAnimation(parent: _mainController, curve: Curves.easeOut));
    
    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_mainController);
    
    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -30.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: -30.0, end: 0.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -15.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: -15.0, end: 0.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.0), weight: 40),
    ]).animate(CurvedAnimation(parent: _mainController, curve: Curves.easeOut));
    
    // 파티클 생성
    _generateParticles();
    
    _mainController.forward();
    _particleController.forward();
    
    _mainController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
      }
    });
  }
  
  void _generateParticles() {
    final icons = [Icons.auto_awesome, Icons.star, Icons.favorite, Icons.celebration];
    final colors = [Colors.amber, Colors.pink, Colors.cyan, Colors.purple, Colors.orange];
    for (int i = 0; i < 20; i++) {
      _particles.add(_Particle(
        icon: icons[_random.nextInt(icons.length)],
        color: colors[_random.nextInt(colors.length)],
        startX: _random.nextDouble() * 2 - 1, // -1 ~ 1
        startY: _random.nextDouble() * 0.5,
        endX: (_random.nextDouble() * 2 - 1) * 2, // -2 ~ 2
        endY: -1 - _random.nextDouble(), // -1 ~ -2
        rotationSpeed: _random.nextDouble() * 4 - 2,
        delay: _random.nextDouble() * 0.3,
      ));
    }
  }

  @override
  void dispose() {
    _mainController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_mainController, _particleController]),
      builder: (context, child) {
        return Stack(
          children: [
            // 파티클들
            ..._particles.map((particle) {
              final progress = (_particleController.value - particle.delay).clamp(0.0, 1.0) / (1 - particle.delay);
              if (progress <= 0) return const SizedBox.shrink();
              
              final x = particle.startX + (particle.endX - particle.startX) * progress;
              final y = particle.startY + (particle.endY - particle.startY) * progress;
              final opacity = (1 - progress).clamp(0.0, 1.0);
              
              return Positioned(
                left: MediaQuery.of(context).size.width / 2 + x * 150,
                top: MediaQuery.of(context).size.height / 2 + y * 200,
                child: Opacity(
                  opacity: opacity,
                  child: Transform.rotate(
                    angle: progress * particle.rotationSpeed * 3.14,
                    child: Icon(
                      particle.icon,
                      size: 24,
                      color: particle.color,
                    ),
                  ),
                ),
              );
            }),
            // 메인 선물 표시
            Center(
              child: Transform.translate(
                offset: Offset(0, _bounceAnimation.value),
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Opacity(
                    opacity: _opacityAnimation.value,
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.purple.shade400,
                            Colors.pink.shade400,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.purple.withOpacity(0.5),
                            blurRadius: 30,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: widget.giftColor.withOpacity(0.3),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              widget.giftIcon,
                              size: 64,
                              color: widget.giftColor,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            widget.giftName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${widget.senderName}님의 선물',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 18,
                            ),
                          ),
                          if (widget.rewardPoints > 0) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.monetization_on, color: Colors.amber, size: 20),
                                  const SizedBox(width: 6),
                                  Text(
                                    '+${widget.rewardPoints}P',
                                    style: const TextStyle(
                                      color: Colors.amber,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Particle {
  final IconData icon;
  final Color color;
  final double startX;
  final double startY;
  final double endX;
  final double endY;
  final double rotationSpeed;
  final double delay;

  _Particle({
    required this.icon,
    required this.color,
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
    required this.rotationSpeed,
    required this.delay,
  });
}
