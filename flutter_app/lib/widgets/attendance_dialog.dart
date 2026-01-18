import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../config/theme.dart';

class AttendanceDialog extends StatefulWidget {
  final VoidCallback? onCheckInComplete;
  
  const AttendanceDialog({super.key, this.onCheckInComplete});

  @override
  State<AttendanceDialog> createState() => _AttendanceDialogState();
}

class _AttendanceDialogState extends State<AttendanceDialog> {
  final ApiService _apiService = ApiService();
  
  bool _isLoading = true;
  bool _isCheckingIn = false;
  int _currentStreak = 0;
  bool _checkedInToday = false;
  List<int> _rewards = [30, 30, 50, 30, 30, 30, 100];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAttendanceStatus();
  }

  Future<void> _loadAttendanceStatus() async {
    try {
      final response = await _apiService.get('/api/auth/attendance');
      setState(() {
        _currentStreak = response['currentStreak'] ?? 0;
        _checkedInToday = response['checkedInToday'] ?? false;
        if (response['rewards'] != null) {
          _rewards = List<int>.from(response['rewards']);
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '출석체크 정보를 불러올 수 없습니다.';
        _isLoading = false;
      });
    }
  }

  Future<void> _checkIn() async {
    setState(() => _isCheckingIn = true);
    
    try {
      final response = await _apiService.post('/api/auth/attendance/check-in', {});
      
      if (mounted) {
        setState(() {
          _currentStreak = response['currentStreak'] ?? _currentStreak + 1;
          _checkedInToday = true;
          _isCheckingIn = false;
        });
        
        // 보상 획득 알림
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 ${response['rewardPoints']}P 획득! (${_currentStreak}일차)'),
            backgroundColor: Colors.green,
          ),
        );
        
        widget.onCheckInComplete?.call();
      }
    } catch (e) {
      setState(() => _isCheckingIn = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().contains('이미 출석') 
                ? '오늘 이미 출석체크를 완료했습니다.' 
                : '출석체크에 실패했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 제목
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '📅 출석체크',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black54),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              )
            else ...[
              // 7일 출석 현황
              _buildWeeklyProgress(),
              const SizedBox(height: 24),
              
              // 출석체크 버튼
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _checkedInToday || _isCheckingIn ? null : _checkIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _checkedInToday 
                        ? Colors.grey 
                        : AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isCheckingIn
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _checkedInToday ? '✓ 오늘 출석 완료!' : '출석하기',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              
              const SizedBox(height: 12),
              Text(
                _checkedInToday 
                    ? '내일 다시 출석해주세요!' 
                    : '출석하고 포인트를 받아가세요!',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyProgress() {
    final days = ['1일', '2일', '3일', '4일', '5일', '6일', '7일'];
    
    return Column(
      children: [
        // 보상 표시
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(7, (index) {
            final isCompleted = index < _currentStreak;
            final isToday = index == _currentStreak && !_checkedInToday;
            final isTodayCompleted = index == _currentStreak - 1 && _checkedInToday;
            
            return _buildDayItem(
              day: days[index],
              reward: _rewards[index],
              isCompleted: isCompleted || isTodayCompleted,
              isToday: isToday,
              isSpecial: index == 2 || index == 6, // 3일차(50p), 7일차(100p)
            );
          }),
        ),
      ],
    );
  }

  Widget _buildDayItem({
    required String day,
    required int reward,
    required bool isCompleted,
    required bool isToday,
    required bool isSpecial,
  }) {
    return Column(
      children: [
        // 포인트
        Text(
          '${reward}P',
          style: TextStyle(
            fontSize: isSpecial ? 12 : 11,
            fontWeight: isSpecial ? FontWeight.bold : FontWeight.normal,
            color: isSpecial ? Colors.orange : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        // 원형 아이콘
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted 
                ? AppTheme.primaryColor 
                : isToday 
                    ? Colors.orange.shade100
                    : Colors.grey.shade200,
            border: isToday 
                ? Border.all(color: Colors.orange, width: 2)
                : null,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : isSpecial
                    ? const Icon(Icons.card_giftcard, color: Colors.orange, size: 18)
                    : Icon(Icons.circle, color: Colors.grey.shade400, size: 8),
          ),
        ),
        const SizedBox(height: 4),
        // 일차
        Text(
          day,
          style: TextStyle(
            fontSize: 11,
            color: isCompleted || isToday ? Colors.black87 : Colors.grey.shade500,
            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
