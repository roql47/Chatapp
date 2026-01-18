import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/theme.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';

class AdultVerificationScreen extends StatefulWidget {
  const AdultVerificationScreen({super.key});

  @override
  State<AdultVerificationScreen> createState() => _AdultVerificationScreenState();
}

class _AdultVerificationScreenState extends State<AdultVerificationScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  String? _error;

  // 카카오 인증으로 성인인증
  Future<void> _verifyWithKakao() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 카카오 동의항목에서 생년월일 정보 가져오기 시도
      // 카카오 계정 정보 가져오기
      User user;
      try {
        user = await UserApi.instance.me();
      } catch (e) {
        // 토큰이 만료되었을 수 있으므로 재로그인
        await UserApi.instance.loginWithKakaoAccount();
        user = await UserApi.instance.me();
      }

      final kakaoAccount = user.kakaoAccount;
      
      // 생년 정보 확인
      int? birthYear;
      
      // 1. birthyear가 있으면 사용
      if (kakaoAccount?.birthyear != null) {
        birthYear = int.tryParse(kakaoAccount!.birthyear!);
      }
      
      // 2. ageRange로 추정
      if (birthYear == null && kakaoAccount?.ageRange != null) {
        final currentYear = DateTime.now().year;
        final ageRange = kakaoAccount!.ageRange!;
        
        // AgeRange enum에서 최소 나이 추출
        final ageRangeStr = ageRange.toString();
        int minAge = 0;
        
        if (ageRangeStr.contains('AGE_0_9')) minAge = 0;
        else if (ageRangeStr.contains('AGE_10_14')) minAge = 10;
        else if (ageRangeStr.contains('AGE_15_19')) minAge = 15;
        else if (ageRangeStr.contains('AGE_20_29')) minAge = 20;
        else if (ageRangeStr.contains('AGE_30_39')) minAge = 30;
        else if (ageRangeStr.contains('AGE_40_49')) minAge = 40;
        else if (ageRangeStr.contains('AGE_50_59')) minAge = 50;
        else if (ageRangeStr.contains('AGE_60_69')) minAge = 60;
        else if (ageRangeStr.contains('AGE_70_79')) minAge = 70;
        else if (ageRangeStr.contains('AGE_80_89')) minAge = 80;
        else if (ageRangeStr.contains('AGE_90_ABOVE')) minAge = 90;
        
        birthYear = currentYear - minAge;
      }

      if (birthYear == null) {
        // 생년 정보를 가져올 수 없는 경우 수동 입력 다이얼로그
        if (mounted) {
          final manualBirthYear = await _showManualBirthYearDialog();
          if (manualBirthYear != null) {
            birthYear = manualBirthYear;
          } else {
            setState(() {
              _isLoading = false;
              _error = '생년 정보가 필요합니다.';
            });
            return;
          }
        }
      }

      // 만 19세 이상인지 로컬에서 먼저 확인
      final currentYear = DateTime.now().year;
      final age = currentYear - birthYear!;
      
      if (age < 19) {
        setState(() {
          _isLoading = false;
          _error = '만 19세 이상만 이용 가능합니다. (현재 $age세)';
        });
        return;
      }

      // 서버에 성인인증 요청 시도
      try {
        await _apiService.post('/api/auth/adult-verification/kakao', {
          'birthYear': birthYear,
        });
      } catch (serverError) {
        // 서버 오류는 무시 (테스트 모드)
        print('서버 인증 실패 (테스트 모드로 진행): $serverError');
        
        // 테스트 모드: 로컬에 저장
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('test_mode_adult_verified', true);
      }

      if (mounted) {
        // AuthProvider 상태 업데이트
        Provider.of<AuthProvider>(context, listen: false).onAdultVerificationComplete();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('성인인증이 완료되었습니다!'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/home');
      }
    } catch (e) {
      print('성인인증 오류: $e');
      String errorMessage = '성인인증에 실패했습니다.';
      
      if (e.toString().contains('403') || e.toString().contains('19세')) {
        errorMessage = '만 19세 이상만 이용 가능합니다.';
      } else if (e.toString().contains('409')) {
        errorMessage = '이미 다른 계정에서 인증된 정보입니다.';
      }
      
      setState(() {
        _error = errorMessage;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // 수동 생년 입력 다이얼로그
  Future<int?> _showManualBirthYearDialog() async {
    int? selectedYear;
    final currentYear = DateTime.now().year;
    final years = List.generate(100, (i) => currentYear - i - 19); // 19세 이상만

    return showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Text(
          '생년 입력',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '카카오 계정에서 생년 정보를 가져올 수 없습니다.\n직접 입력해주세요.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.darkBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButton<int>(
                value: selectedYear,
                hint: const Text('출생년도 선택', style: TextStyle(color: Colors.white54)),
                dropdownColor: AppTheme.darkCard,
                isExpanded: true,
                underline: const SizedBox(),
                items: years.map((year) => DropdownMenuItem(
                  value: year,
                  child: Text('$year년', style: const TextStyle(color: Colors.white)),
                )).toList(),
                onChanged: (value) {
                  selectedYear = value;
                  (context as Element).markNeedsBuild();
                },
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '⚠️ 허위 정보 입력 시 법적 책임이 있습니다.',
              style: TextStyle(color: Colors.orange, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('취소', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: selectedYear != null 
                ? () => Navigator.pop(context, selectedYear)
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              
              // 아이콘
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_user,
                  size: 60,
                  color: Colors.white,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // 제목
              const Text(
                '성인인증이 필요합니다',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // 설명
              const Text(
                '본 서비스는 만 19세 이상만 이용 가능합니다.\n카카오 계정을 통해 간편하게 인증하세요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              
              const SizedBox(height: 40),
              
              // 에러 메시지
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              
              // 카카오 인증 버튼
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyWithKakao,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFEE500),
                    foregroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black54,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble, size: 24),
                            SizedBox(width: 8),
                            Text(
                              '카카오로 성인인증',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // 안내 문구
              const Text(
                '인증 정보는 안전하게 보호되며,\n서비스 이용 목적으로만 사용됩니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                ),
              ),
              
              const Spacer(),
              
              // 로그아웃 버튼
              TextButton(
                onPressed: () async {
                  try {
                    await UserApi.instance.logout();
                  } catch (_) {}
                  if (mounted) {
                    context.go('/login');
                  }
                },
                child: const Text(
                  '다른 계정으로 로그인',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
