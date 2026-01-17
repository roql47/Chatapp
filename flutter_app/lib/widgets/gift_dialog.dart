import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';

class GiftDialog extends StatefulWidget {
  final String partnerName;
  final String partnerId;
  final String? roomId;

  const GiftDialog({
    super.key,
    required this.partnerName,
    required this.partnerId,
    this.roomId,
  });

  @override
  State<GiftDialog> createState() => _GiftDialogState();
}

class _GiftDialogState extends State<GiftDialog> {
  String? _selectedGift;
  bool _isSending = false;

  final List<Map<String, dynamic>> _gifts = [
    {'id': 'heart', 'name': '하트', 'price': 10, 'icon': Icons.favorite, 'color': Colors.pink},
    {'id': 'rose', 'name': '장미', 'price': 30, 'icon': Icons.local_florist, 'color': Colors.red},
    {'id': 'star', 'name': '별', 'price': 50, 'icon': Icons.star, 'color': Colors.amber},
    {'id': 'diamond', 'name': '다이아몬드', 'price': 100, 'icon': Icons.diamond, 'color': Colors.cyan},
    {'id': 'crown', 'name': '왕관', 'price': 200, 'icon': Icons.workspace_premium, 'color': Colors.orange},
    {'id': 'rocket', 'name': '로켓', 'price': 500, 'icon': Icons.rocket_launch, 'color': Colors.deepOrange},
  ];

  Future<void> _sendGift() async {
    if (_selectedGift == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('선물을 선택해주세요')),
      );
      return;
    }

    final gift = _gifts.firstWhere((g) => g['id'] == _selectedGift);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userPoints = authProvider.user?.points ?? 0;

    if (userPoints < gift['price']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('포인트가 부족합니다')),
      );
      return;
    }

    setState(() => _isSending = true);

    // 메시지 미리 준비
    final successMessage = '${widget.partnerName}님에게 ${gift['name']}을(를) 선물했어요!';

    try {
      final apiService = ApiService();
      await apiService.post('/api/gifts/send', {
        'receiverId': widget.partnerId,
        'giftType': _selectedGift,
        'roomId': widget.roomId,
      });

      // 포인트 갱신
      await authProvider.usePoints(gift['price'], '선물: ${gift['name']}');

      if (mounted) {
        // Navigator.pop 전에 먼저 닫고
        Navigator.pop(context, true);
      }
      
      // 부모 context 사용 - WidgetsBinding.addPostFrameCallback 사용
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(successMessage)),
          );
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('선물 실패: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userPoints = authProvider.user?.points ?? 0;

    return Dialog(
      backgroundColor: AppTheme.darkCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${widget.partnerName}님에게 선물하기',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.monetization_on, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '$userPoints P',
                        style: const TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 선물 목록
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: _gifts.length,
              itemBuilder: (context, index) {
                final gift = _gifts[index];
                final isSelected = _selectedGift == gift['id'];
                final canAfford = userPoints >= gift['price'];

                return GestureDetector(
                  onTap: canAfford
                      ? () => setState(() => _selectedGift = gift['id'])
                      : null,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryColor.withOpacity(0.3)
                          : Colors.white.withOpacity(canAfford ? 0.1 : 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          gift['icon'] as IconData,
                          size: 32,
                          color: canAfford ? gift['color'] as Color : Colors.grey,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          gift['name'],
                          style: TextStyle(
                            color: canAfford ? Colors.white : Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${gift['price']}P',
                          style: TextStyle(
                            color: canAfford ? Colors.amber : Colors.grey,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // 버튼
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('취소', style: TextStyle(color: Colors.white60)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isSending || _selectedGift == null ? null : _sendGift,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _isSending
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('선물하기 🎁'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
