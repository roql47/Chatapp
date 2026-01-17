import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/api_service.dart';

class RatingDialog extends StatefulWidget {
  final String partnerName;
  final String partnerId;
  final String roomId;

  const RatingDialog({
    super.key,
    required this.partnerName,
    required this.partnerId,
    required this.roomId,
  });

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  int _rating = 0;
  final Map<String, bool> _selectedTags = {
    'friendly': false,
    'funny': false,
    'interesting': false,
    'respectful': false,
    'goodListener': false,
  };
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _tags = [
    {'id': 'friendly', 'name': '친절해요', 'emoji': '😊'},
    {'id': 'funny', 'name': '유머있어요', 'emoji': '😂'},
    {'id': 'interesting', 'name': '대화가 재미있어요', 'emoji': '💬'},
    {'id': 'respectful', 'name': '예의바르다', 'emoji': '🎩'},
    {'id': 'goodListener', 'name': '경청을 잘해요', 'emoji': '👂'},
  ];

  Future<void> _submitRating() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('별점을 선택해주세요')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final apiService = ApiService();
      await apiService.post('/api/ratings', {
        'ratedUserId': widget.partnerId,
        'roomId': widget.roomId,
        'score': _rating,
        'tags': _selectedTags,
      });

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('평가해 주셔서 감사합니다!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('평가 실패: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.darkCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${widget.partnerName}님과의 대화는 어땠나요?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // 별점
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starIndex = index + 1;
                return GestureDetector(
                  onTap: () => setState(() => _rating = starIndex),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      _rating >= starIndex ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 40,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
            Text(
              _getRatingText(),
              style: const TextStyle(color: Colors.white60, fontSize: 14),
            ),
            const SizedBox(height: 20),

            // 태그 선택
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '어떤 점이 좋았나요? (선택)',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _tags.map((tag) {
                final isSelected = _selectedTags[tag['id']] ?? false;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedTags[tag['id']] = !isSelected;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryColor.withOpacity(0.3)
                          : Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(tag['emoji'], style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 4),
                        Text(
                          tag['name'],
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // 버튼
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('건너뛰기', style: TextStyle(color: Colors.white60)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitRating,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('평가하기'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getRatingText() {
    switch (_rating) {
      case 1:
        return '별로였어요 😞';
      case 2:
        return '아쉬워요 😐';
      case 3:
        return '보통이에요 🙂';
      case 4:
        return '좋았어요 😊';
      case 5:
        return '최고였어요! 🤩';
      default:
        return '별점을 선택해주세요';
    }
  }
}
