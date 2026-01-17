import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/theme.dart';

/// 전체 화면 프로필 이미지 뷰어
/// 핀치 줌을 지원하고, 배경 탭이나 닫기 버튼으로 닫을 수 있습니다.
class ProfileImageViewer extends StatelessWidget {
  final String? imageUrl;
  final String nickname;
  final String? heroTag;
  final String? mbti;
  final List<String>? interests;
  final String? gender;
  final DateTime? createdAt;

  const ProfileImageViewer({
    super.key,
    this.imageUrl,
    required this.nickname,
    this.heroTag,
    this.mbti,
    this.interests,
    this.gender,
    this.createdAt,
  });

  /// 프로필 이미지 뷰어를 다이얼로그로 표시
  static void show(BuildContext context, {
    String? imageUrl,
    required String nickname,
    String? heroTag,
    String? mbti,
    List<String>? interests,
    String? gender,
    DateTime? createdAt,
  }) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black87,
        pageBuilder: (context, animation, secondaryAnimation) {
          return ProfileImageViewer(
            imageUrl: imageUrl,
            nickname: nickname,
            heroTag: heroTag,
            mbti: mbti,
            interests: interests,
            gender: gender,
            createdAt: createdAt,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 배경 탭으로 닫기
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(color: Colors.transparent),
          ),
          // 이미지 뷰어
          Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 닉네임 표시
                  Text(
                    nickname,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 성별 표시
                  if (gender != null && gender!.isNotEmpty)
                    Text(
                      gender == 'male' ? '👨 남성' : gender == 'female' ? '👩 여성' : '🧑 기타',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 16,
                      ),
                    ),
                  const SizedBox(height: 20),
                  // 이미지
                  _buildImageContent(context),
                  const SizedBox(height: 24),
                  // MBTI 표시
                  if (mbti != null && mbti!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('📊 MBTI: ', style: TextStyle(color: Colors.white70, fontSize: 16)),
                          Text(
                            mbti!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  // 관심사 표시
                  if (interests != null && interests!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.favorite, color: Colors.white70, size: 16),
                              SizedBox(width: 6),
                              Text(
                                '관심사',
                                style: TextStyle(color: Colors.white70, fontSize: 14),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: interests!.map((interest) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.secondaryColor.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppTheme.secondaryColor.withOpacity(0.5)),
                              ),
                              child: Text(
                                interest,
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                              ),
                            )).toList(),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  // 가입일 표시
                  if (createdAt != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.calendar_today, color: Colors.white70, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            '가입일: ${_formatJoinDate(createdAt!)}',
                            style: const TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          // 닫기 버튼
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageContent(BuildContext context) {
    final size = MediaQuery.of(context).size.width * 0.85;

    Widget imageWidget;

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      imageWidget = ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: CachedNetworkImage(
            imageUrl: imageUrl!,
            width: size,
            height: size,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: AppTheme.darkCard,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor),
              ),
            ),
            errorWidget: (context, url, error) => _buildDefaultAvatar(size),
          ),
        ),
      );
    } else {
      imageWidget = _buildDefaultAvatar(size);
    }

    // Hero 애니메이션 적용
    if (heroTag != null) {
      return Hero(
        tag: heroTag!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  String _formatJoinDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return '오늘 가입';
    } else if (difference.inDays == 1) {
      return '어제 가입';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전 가입';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}주 전 가입';
    } else if (difference.inDays < 365) {
      return '${(difference.inDays / 30).floor()}개월 전 가입';
    } else {
      return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
    }
  }

  Widget _buildDefaultAvatar(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor,
            AppTheme.secondaryColor,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person,
            size: size * 0.4,
            color: Colors.white.withOpacity(0.8),
          ),
          const SizedBox(height: 16),
          Text(
            '프로필 사진 없음',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
