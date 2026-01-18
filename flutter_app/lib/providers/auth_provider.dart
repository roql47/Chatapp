import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/socket_service.dart';

enum AuthState {
  initial,
  loading,
  authenticated,
  unauthenticated,
  needsProfile,
  needsAdultVerification,
}

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final SocketService _socketService = SocketService();

  AuthState _state = AuthState.initial;
  UserModel? _user;
  String? _error;

  AuthState get state => _state;
  UserModel? get user => _user;
  String? get error => _error;
  bool get isLoggedIn => _state == AuthState.authenticated;
  String? get token => _authService.authToken; // JWT 토큰

  // 자동 로그인 확인
  Future<void> checkAuth() async {
    _state = AuthState.loading;
    notifyListeners();

    final success = await _authService.autoLogin();
    
    if (success) {
      _user = _authService.currentUser;
      
      // 프로필 설정 완료 여부 확인
      if (_user!.gender.isEmpty || _user!.interests.isEmpty) {
        _state = AuthState.needsProfile;
      }
      // 성인인증 완료 여부 확인
      else if (!_user!.isAdultVerified) {
        _state = AuthState.needsAdultVerification;
      } else {
        _state = AuthState.authenticated;
        _connectSocket();
      }
    } else {
      _state = AuthState.unauthenticated;
    }
    
    notifyListeners();
  }

  // 카카오 로그인
  Future<bool> loginWithKakao() async {
    _state = AuthState.loading;
    _error = null;
    notifyListeners();

    final success = await _authService.loginWithKakao();
    
    if (success) {
      _user = _authService.currentUser;
      
      // 프로필 설정 완료 여부 확인
      if (_user!.gender.isEmpty || _user!.interests.isEmpty) {
        _state = AuthState.needsProfile;
      }
      // 성인인증 완료 여부 확인
      else if (!_user!.isAdultVerified) {
        _state = AuthState.needsAdultVerification;
      } else {
        _state = AuthState.authenticated;
        _connectSocket();
      }
    } else {
      _state = AuthState.unauthenticated;
      _error = '로그인에 실패했습니다.';
    }
    
    notifyListeners();
    return success;
  }

  // 프로필 설정
  Future<bool> setupProfile({
    required String nickname,
    required String gender,
    required List<String> interests,
    String? mbti,
  }) async {
    _error = null;
    
    final success = await _authService.updateProfile(
      nickname: nickname,
      gender: gender,
      interests: interests,
      mbti: mbti,
    );
    
    if (success) {
      _user = _authService.currentUser;
      
      // 성인인증 완료 여부 확인
      if (!_user!.isAdultVerified) {
        _state = AuthState.needsAdultVerification;
      } else {
        _state = AuthState.authenticated;
        _connectSocket();
      }
    } else {
      _error = '프로필 설정에 실패했습니다.';
    }
    
    notifyListeners();
    return success;
  }

  // 프로필 업데이트
  Future<bool> updateProfile({
    String? nickname,
    String? gender,
    List<String>? interests,
    String? mbti,
    String? profileImage,
  }) async {
    _error = null;
    
    final success = await _authService.updateProfile(
      nickname: nickname,
      gender: gender,
      interests: interests,
      mbti: mbti,
      profileImage: profileImage,
    );
    
    if (success) {
      _user = _authService.currentUser;
    } else {
      _error = '프로필 업데이트에 실패했습니다.';
    }
    
    notifyListeners();
    return success;
  }

  // 로그아웃
  Future<void> logout() async {
    _socketService.disconnect();
    await _authService.logout();
    _user = null;
    _state = AuthState.unauthenticated;
    notifyListeners();
  }

  // 회원 탈퇴
  Future<bool> deleteAccount() async {
    _socketService.disconnect();
    final success = await _authService.deleteAccount();
    
    if (success) {
      _user = null;
      _state = AuthState.unauthenticated;
      notifyListeners();
    }
    
    return success;
  }

  // 소켓 연결
  void _connectSocket() {
    if (_user != null && _authService.authToken != null) {
      _socketService.connect(_user!.id, _authService.authToken!);
    }
  }

  // ============================================
  // 포인트 관련 메서드
  // ============================================

  // 포인트 조회
  Future<int> getPoints() async {
    final points = await _authService.getPoints();
    _user = _authService.currentUser;
    notifyListeners();
    return points;
  }

  // 포인트 사용
  Future<bool> usePoints(int amount, String description) async {
    final success = await _authService.usePoints(amount, description);
    if (success) {
      _user = _authService.currentUser;
      notifyListeners();
    }
    return success;
  }

  // 포인트 충전
  Future<bool> chargePoints(int amount, String productId) async {
    final success = await _authService.chargePoints(amount, productId);
    if (success) {
      _user = _authService.currentUser;
      notifyListeners();
    }
    return success;
  }

  // 포인트 충분한지 확인
  Future<bool> hasEnoughPoints(int amount) async {
    return await _authService.hasEnoughPoints(amount);
  }

  // 성인인증 완료 처리
  void onAdultVerificationComplete() {
    if (_user != null) {
      _user = _user!.copyWith(isAdultVerified: true);
      _state = AuthState.authenticated;
      _connectSocket();
      notifyListeners();
    }
  }

  // 사용자 정보 새로고침
  Future<void> refreshUser() async {
    final points = await _authService.getPoints();
    _user = _authService.currentUser;
    notifyListeners();
  }
}
