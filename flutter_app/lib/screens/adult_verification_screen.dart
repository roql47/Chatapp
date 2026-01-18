import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/theme.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart' as app_auth;

class AdultVerificationScreen extends StatefulWidget {
  const AdultVerificationScreen({super.key});

  @override
  State<AdultVerificationScreen> createState() => _AdultVerificationScreenState();
}

class _AdultVerificationScreenState extends State<AdultVerificationScreen> {
  final ApiService _apiService = ApiService();
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  
  bool _isLoading = false;
  bool _codeSent = false;
  bool _codeVerified = false;
  String? _error;
  String? _verificationId;
  int? _selectedBirthYear;
  int? _resendToken;
  
  // 인증 타이머
  int _remainingSeconds = 60;
  bool _canResend = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  // 전화번호 포맷팅 (+82 형식)
  String _formatPhoneNumber(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.startsWith('0')) {
      cleaned = cleaned.substring(1);
    }
    return '+82$cleaned';
  }

  // 인증번호 발송
  Future<void> _sendVerificationCode() async {
    final phone = _phoneController.text.trim();
    
    if (phone.isEmpty) {
      setState(() => _error = '전화번호를 입력해주세요.');
      return;
    }
    
    if (!RegExp(r'^01[0-9]{8,9}$').hasMatch(phone)) {
      setState(() => _error = '올바른 전화번호 형식이 아닙니다.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final formattedPhone = _formatPhoneNumber(phone);
      
      await _firebaseAuth.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        timeout: const Duration(seconds: 60),
        forceResendingToken: _resendToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Android에서 자동 인증 완료 시
          setState(() {
            _codeVerified = true;
            _isLoading = false;
          });
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() {
            _isLoading = false;
            if (e.code == 'invalid-phone-number') {
              _error = '유효하지 않은 전화번호입니다.';
            } else if (e.code == 'too-many-requests') {
              _error = '너무 많은 요청이 있었습니다. 잠시 후 다시 시도해주세요.';
            } else {
              _error = '인증번호 발송에 실패했습니다: ${e.message}';
            }
          });
        },
        codeSent: (String verificationId, int? resendToken) {
          print('🟢 인증번호 발송됨 - verificationId: ${verificationId.substring(0, 20)}...');
          setState(() {
            _verificationId = verificationId;
            _resendToken = resendToken;
            _codeSent = true;
            _isLoading = false;
            _remainingSeconds = 60;
            _canResend = false;
          });
          _startTimer();
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('인증번호가 발송되었습니다.'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = '인증번호 발송 중 오류가 발생했습니다: $e';
      });
    }
  }

  // 타이머 시작
  void _startTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
        return true;
      } else {
        setState(() => _canResend = true);
        return false;
      }
    });
  }

  // 인증번호 확인
  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    
    if (code.isEmpty) {
      setState(() => _error = '인증번호를 입력해주세요.');
      return;
    }
    
    if (code.length != 6) {
      setState(() => _error = '인증번호 6자리를 입력해주세요.');
      return;
    }

    if (_verificationId == null) {
      setState(() => _error = '인증 세션이 만료되었습니다. 다시 시도해주세요.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      print('🔵 인증 시도 - verificationId: ${_verificationId?.substring(0, 20)}..., code: $code');
      
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: code,
      );
      
      // Firebase 인증
      await _firebaseAuth.signInWithCredential(credential);
      print('🟢 Firebase 인증 성공!');
      
      setState(() {
        _codeVerified = true;
        _isLoading = false;
      });
    } on FirebaseAuthException catch (e) {
      print('🔴 Firebase 인증 실패 - code: ${e.code}, message: ${e.message}');
      setState(() {
        _isLoading = false;
        if (e.code == 'invalid-verification-code') {
          _error = '인증번호가 올바르지 않습니다. (코드: ${e.code})';
        } else if (e.code == 'session-expired') {
          _error = '인증 세션이 만료되었습니다. 다시 시도해주세요.';
        } else {
          _error = '인증에 실패했습니다: ${e.code} - ${e.message}';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = '인증 중 오류가 발생했습니다: $e';
      });
    }
  }

  // 성인인증 완료
  Future<void> _completeVerification() async {
    if (_selectedBirthYear == null) {
      setState(() => _error = '출생연도를 선택해주세요.');
      return;
    }

    // 만 19세 이상인지 확인 (클라이언트 측 1차 검증)
    final currentYear = DateTime.now().year;
    final age = currentYear - _selectedBirthYear!;
    
    if (age < 19) {
      setState(() => _error = '만 19세 이상만 이용 가능합니다. (현재 만 $age세)');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 서버에 성인인증 완료 요청
      final response = await _apiService.post('/api/auth/adult-verification/firebase', {
        'phone': _phoneController.text.trim(),
        'birthYear': _selectedBirthYear,
        'firebaseUid': _firebaseAuth.currentUser?.uid,
      });
      
      // 서버 응답 확인
      if (response['isVerified'] == true) {
        if (mounted) {
          Provider.of<app_auth.AuthProvider>(context, listen: false).onAdultVerificationComplete();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('성인인증이 완료되었습니다!'),
              backgroundColor: Colors.green,
            ),
          );
          context.go('/home');
        }
      } else {
        setState(() {
          _isLoading = false;
          _error = response['message'] ?? '성인인증에 실패했습니다.';
        });
      }
    } catch (e) {
      print('서버 인증 오류: $e');
      final errorMessage = e.toString();
      
      // 서버에서 명시적으로 거부한 경우 (19세 미만, 중복 전화번호 등)
      if (errorMessage.contains('403') || errorMessage.contains('19세')) {
        setState(() {
          _isLoading = false;
          _error = '만 19세 이상만 이용 가능합니다.';
        });
        return;
      }
      
      if (errorMessage.contains('409') || errorMessage.contains('다른 계정')) {
        setState(() {
          _isLoading = false;
          _error = '이미 다른 계정에서 인증된 전화번호입니다.';
        });
        return;
      }
      
      // 네트워크 오류 등 서버 연결 실패 시에만 에러 표시
      setState(() {
        _isLoading = false;
        _error = '서버 연결에 실패했습니다. 잠시 후 다시 시도해주세요.';
      });
    }
  }

  String _formatTime(int seconds) {
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () async {
            // 로그아웃하고 로그인 화면으로
            await Provider.of<app_auth.AuthProvider>(context, listen: false).logout();
            if (mounted) context.go('/login');
          },
        ),
        title: const Text('성인인증', style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 단계 표시
              _buildStepIndicator(),
              
              const SizedBox(height: 32),
              
              // 안내 문구
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.primaryColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '본 서비스는 만 19세 이상만 이용 가능합니다.\n휴대폰 인증을 통해 본인 확인을 진행합니다.',
                        style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // 에러 메시지
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // Step 1: 전화번호 입력
              if (!_codeVerified) ...[
                const Text(
                  '휴대폰 번호',
                  style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _phoneController,
                        enabled: !_codeSent || _canResend,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(color: Colors.white),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(11),
                        ],
                        decoration: InputDecoration(
                          hintText: '01012345678',
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: AppTheme.darkCard,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: const Icon(Icons.phone_android, color: Colors.white54),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading || (_codeSent && !_canResend) 
                            ? null 
                            : _sendVerificationCode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading && !_codeSent
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(_codeSent ? '재발송' : '인증요청'),
                      ),
                    ),
                  ],
                ),
                
                // Step 2: 인증번호 입력
                if (_codeSent) ...[
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '인증번호',
                        style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      if (!_canResend)
                        Text(
                          _formatTime(_remainingSeconds),
                          style: TextStyle(
                            color: _remainingSeconds < 30 ? Colors.red : AppTheme.primaryColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _codeController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white, letterSpacing: 8, fontSize: 20),
                          textAlign: TextAlign.center,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          decoration: InputDecoration(
                            hintText: '000000',
                            hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 8),
                            filled: true,
                            fillColor: AppTheme.darkCard,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _verifyCode,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('확인'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
              
              // Step 3: 출생연도 선택 (인증 완료 후)
              if (_codeVerified) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '휴대폰 인증 완료',
                              style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              _phoneController.text,
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                const Text(
                  '출생연도 선택',
                  style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.darkCard,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButton<int>(
                    value: _selectedBirthYear,
                    hint: const Text('출생연도를 선택하세요', style: TextStyle(color: Colors.white54)),
                    dropdownColor: AppTheme.darkCard,
                    isExpanded: true,
                    underline: const SizedBox(),
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
                    items: List.generate(80, (i) {
                      final year = DateTime.now().year - i - 14; // 14세부터 표시
                      return DropdownMenuItem(
                        value: year,
                        child: Text('$year년', style: const TextStyle(color: Colors.white)),
                      );
                    }),
                    onChanged: (value) => setState(() => _selectedBirthYear = value),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // 경고 문구
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '허위 정보 입력 시 서비스 이용이 제한되며,\n관련 법률에 따라 처벌받을 수 있습니다.',
                          style: TextStyle(color: Colors.orange.shade200, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // 인증 완료 버튼
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _completeVerification,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            '성인인증 완료',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      children: [
        _buildStep(1, '휴대폰 인증', !_codeVerified),
        Expanded(
          child: Container(
            height: 2,
            color: _codeVerified ? Colors.green : Colors.white24,
          ),
        ),
        _buildStep(2, '정보 입력', _codeVerified),
      ],
    );
  }

  Widget _buildStep(int step, String label, bool isActive) {
    final isCompleted = (step == 1 && _codeVerified);
    
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isCompleted 
                ? Colors.green 
                : isActive 
                    ? AppTheme.primaryColor 
                    : Colors.white24,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : Text(
                    '$step',
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.white54,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isActive || isCompleted ? Colors.white : Colors.white54,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
