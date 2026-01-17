import 'package:flutter/material.dart';
import '../config/theme.dart';

class MatchingPreviewDialog extends StatelessWidget {
  final Map<String, dynamic> partnerPreview;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const MatchingPreviewDialog({
    super.key,
    required this.partnerPreview,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final nickname = partnerPreview['nickname'] ?? '상대방';
    final profileImage = partnerPreview['profileImage'];
    final interests = List<String>.from(partnerPreview['interests'] ?? []);
    final rating = partnerPreview['rating'] ?? {};
    final averageScore = (rating['averageScore'] ?? 0).toDouble();
    final totalRatings = rating['totalRatings'] ?? 0;
    final isVip = partnerPreview['isVip'] ?? false;
    final vipTier = partnerPreview['vipTier'] ?? 'none';
    final interestMatch = partnerPreview['interestMatch'] ?? {};
    final matchRate = interestMatch['matchRate'] ?? 0;
    final commonInterests = List<String>.from(interestMatch['commonInterests'] ?? []);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.darkCard,
          borderRadius: BorderRadius.circular(24),
          border: isVip
              ? Border.all(color: _getVipColor(vipTier), width: 2)
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 매칭 발견 텍스트
            Text(
              '🎉 상대를 찾았어요!',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // 프로필 이미지
            Stack(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: AppTheme.primaryColor,
                  backgroundImage:
                      profileImage != null ? NetworkImage(profileImage) : null,
                  child: profileImage == null
                      ? const Icon(Icons.person, size: 50, color: Colors.white)
                      : null,
                ),
                if (isVip)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: _getVipColor(vipTier),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.star, color: Colors.white, size: 16),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // 닉네임
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  nickname,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isVip) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getVipColor(vipTier),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _getVipName(vipTier),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),

            // 평점
            if (totalRatings > 0)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ...List.generate(5, (index) {
                    return Icon(
                      index < averageScore.round()
                          ? Icons.star
                          : Icons.star_border,
                      color: Colors.amber,
                      size: 18,
                    );
                  }),
                  const SizedBox(width: 4),
                  Text(
                    '${averageScore.toStringAsFixed(1)} ($totalRatings)',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            const SizedBox(height: 16),

            // 관심사 일치율
            if (matchRate > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.favorite, color: AppTheme.primaryColor, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '관심사 $matchRate% 일치!',
                      style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),

            // 공통 관심사
            if (commonInterests.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: commonInterests.take(4).map((interest) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      interest,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 24),

            // 버튼들
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white60,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('다음에'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: onAccept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('대화하기', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getVipColor(String tier) {
    switch (tier) {
      case 'gold':
        return Colors.amber;
      case 'silver':
        return Colors.blueGrey;
      case 'bronze':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }

  String _getVipName(String tier) {
    switch (tier) {
      case 'gold':
        return 'GOLD';
      case 'silver':
        return 'SILVER';
      case 'bronze':
        return 'BRONZE';
      default:
        return '';
    }
  }
}
