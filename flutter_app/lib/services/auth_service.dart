import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'api_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final ApiService _apiService = ApiService();
  UserModel? _currentUser;
  String? _authToken;

  UserModel? get currentUser => _currentUser;
  String? get authToken => _authToken;
  bool get isLoggedIn => _currentUser != null && _authToken != null;

  // 카카오 로그인
  Future<bool> loginWithKakao() async {
    try {
      print('🔵 카카오 로그인 시작...');
      OAuthToken token;
      
      // 카카오톡 설치 여부 확인
      bool kakaoInstalled = await isKakaoTalkInstalled();
      print('🔵 카카오톡 설치 여부: $kakaoInstalled');
      
      if (kakaoInstalled) {
        try {
          print('🔵 카카오톡으로 로그인 시도...');
          token = await UserApi.instance.loginWithKakaoTalk();
          print('🟢 카카오톡 로그인 성공!');
        } catch (e) {
          print('🟡 카카오톡 로그인 실패, 카카오 계정으로 시도: $e');
          token = await UserApi.instance.loginWithKakaoAccount();
          print('🟢 카카오 계정 로그인 성공!');
        }
      } else {
        print('🔵 카카오 계정으로 로그인 시도 (카카오톡 미설치)...');
        token = await UserApi.instance.loginWithKakaoAccount();
        print('🟢 카카오 계정 로그인 성공!');
      }

      print('🟢 카카오 토큰 획득 성공!');
      print('🔵 토큰 앞 20자: ${token.accessToken.substring(0, 20)}...');

      // 카카오 사용자 정보 가져오기
      print('🔵 카카오 사용자 정보 가져오는 중...');
      User kakaoUser = await UserApi.instance.me();
      final nickname = kakaoUser.kakaoAccount?.profile?.nickname ?? '익명';
      // 프로필 이미지는 가져오지 않음 (사용자가 직접 설정하도록)
      const String? profileImage = null;
      print('🟢 카카오 사용자 ID: ${kakaoUser.id}');
      print('🟢 카카오 닉네임: $nickname');
      
      // 서버에 로그인/회원가입 요청
      print('🔵 서버에 로그인 요청 중...');
      try {
        final response = await _apiService.post('/api/auth/kakao', {
          'kakaoId': kakaoUser.id.toString(),
          'nickname': nickname,
          'profileImage': profileImage, // null로 전송
          'accessToken': token.accessToken,
        });
        print('🟢 서버 응답 성공!');

        _authToken = response['token'];
        _currentUser = UserModel.fromJson(response['user']);
        _apiService.setAuthToken(_authToken!);

        // 토큰 저장
        await _saveToken(_authToken!);
        print('🟢 로그인 완료!');
      } catch (serverError) {
        print('🟡 서버 연결 실패 (테스트 모드로 진행): $serverError');
        // 서버 연결 실패 시 테스트 모드로 임시 유저 생성
        _authToken = 'test_token_${kakaoUser.id}';
        
        // 저장된 테스트 모드 포인트 불러오기
        final savedPoints = await _loadTestModePoints();
        
        _currentUser = UserModel(
          id: kakaoUser.id.toString(),
          kakaoId: kakaoUser.id.toString(),
          nickname: nickname,
          profileImage: null, // 프로필 이미지 가져오지 않음
          gender: 'other',
          interests: [],
          createdAt: DateTime.now(),
          points: savedPoints, // 저장된 포인트 사용
        );
        await _saveToken(_authToken!);
        print('🟢 테스트 모드 로그인 완료! (포인트: $savedPoints)');
      }

      return true;
    } catch (e, stackTrace) {
      print('🔴 카카오 로그인 오류: $e');
      print('🔴 스택트레이스: $stackTrace');
      return false;
    }
  }

  // 자동 로그인
  Future<bool> autoLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString('auth_token');

      if (savedToken == null) return false;

      _apiService.setAuthToken(savedToken);
      
      // 서버에서 사용자 정보 가져오기
      try {
        final response = await _apiService.get('/api/auth/me');
        _authToken = savedToken;
        _currentUser = UserModel.fromJson(response['user']);
      } catch (serverError) {
        // 서버 연결 실패 시 테스트 모드
        if (savedToken.startsWith('test_token_')) {
          print('🟡 테스트 모드 자동 로그인');
          final savedPoints = await _loadTestModePoints();
          final savedNickname = prefs.getString('test_mode_nickname') ?? '테스트 유저';
          final savedGender = prefs.getString('test_mode_gender') ?? 'other';
          final savedInterests = prefs.getStringList('test_mode_interests') ?? [];
          
          _authToken = savedToken;
          _currentUser = UserModel(
            id: savedToken.replaceFirst('test_token_', ''),
            kakaoId: savedToken.replaceFirst('test_token_', ''),
            nickname: savedNickname,
            profileImage: null,
            gender: savedGender,
            interests: savedInterests,
            createdAt: DateTime.now(),
            points: savedPoints,
          );
        } else {
          rethrow;
        }
      }

      return true;
    } catch (e) {
      print('자동 로그인 오류: $e');
      await logout();
      return false;
    }
  }

  // 프로필 업데이트
  Future<bool> updateProfile({
    String? nickname,
    String? gender,
    List<String>? interests,
    String? mbti,
    String? profileImage,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (nickname != null) data['nickname'] = nickname;
      if (gender != null) data['gender'] = gender;
      if (interests != null) data['interests'] = interests;
      if (mbti != null) data['mbti'] = mbti;
      if (profileImage != null) data['profileImage'] = profileImage;

      final response = await _apiService.put('/api/auth/profile', data);
      _currentUser = UserModel.fromJson(response['user']);
      
      return true;
    } catch (e) {
      print('프로필 업데이트 오류: $e');
      // 테스트 모드에서는 로컬 저장
      if (_authToken?.startsWith('test_token_') == true && _currentUser != null) {
        final prefs = await SharedPreferences.getInstance();
        if (nickname != null) {
          await prefs.setString('test_mode_nickname', nickname);
          _currentUser = _currentUser!.copyWith(nickname: nickname);
        }
        if (gender != null) {
          await prefs.setString('test_mode_gender', gender);
          _currentUser = _currentUser!.copyWith(gender: gender);
        }
        if (interests != null) {
          await prefs.setStringList('test_mode_interests', interests);
          _currentUser = _currentUser!.copyWith(interests: interests);
        }
        if (mbti != null) {
          await prefs.setString('test_mode_mbti', mbti);
          _currentUser = _currentUser!.copyWith(mbti: mbti);
        }
        if (profileImage != null) {
          await prefs.setString('test_mode_profileImage', profileImage);
          _currentUser = _currentUser!.copyWith(profileImage: profileImage);
        }
        return true;
      }
      return false;
    }
  }

  // 로그아웃
  Future<void> logout() async {
    try {
      await UserApi.instance.logout();
    } catch (_) {}
    
    _currentUser = null;
    _authToken = null;
    _apiService.clearAuthToken();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  // 회원 탈퇴
  Future<bool> deleteAccount() async {
    try {
      await _apiService.delete('/api/auth/account');
      await UserApi.instance.unlink();
      await logout();
      return true;
    } catch (e) {
      print('회원 탈퇴 오류: $e');
      return false;
    }
  }

  // 토큰 저장
  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  // ============================================
  // 포인트 관련 메서드
  // ============================================

  // 포인트 조회
  Future<int> getPoints() async {
    try {
      final response = await _apiService.get('/api/auth/points');
      final points = response['points'] ?? 0;
      
      // 현재 유저 정보 업데이트
      if (_currentUser != null) {
        _currentUser = _currentUser!.copyWith(points: points);
      }
      
      return points;
    } catch (e) {
      print('포인트 조회 오류: $e');
      return _currentUser?.points ?? 0;
    }
  }

  // 포인트 사용
  Future<bool> usePoints(int amount, String description) async {
    try {
      final response = await _apiService.post('/api/auth/points/use', {
        'amount': amount,
        'description': description,
      });
      
      final newPoints = response['points'] ?? 0;
      if (_currentUser != null) {
        _currentUser = _currentUser!.copyWith(points: newPoints);
      }
      
      return true;
    } catch (e) {
      print('포인트 사용 오류: $e');
      // 테스트 모드에서는 로컬에서 차감
      if (_currentUser != null && _currentUser!.points >= amount) {
        final newPoints = _currentUser!.points - amount;
        _currentUser = _currentUser!.copyWith(points: newPoints);
        await _saveTestModePoints(newPoints);
        return true;
      }
      return false;
    }
  }

  // 포인트 충전
  Future<bool> chargePoints(int amount, String productId) async {
    try {
      final response = await _apiService.post('/api/auth/points/charge', {
        'amount': amount,
        'productId': productId,
      });
      
      final newPoints = response['points'] ?? 0;
      if (_currentUser != null) {
        _currentUser = _currentUser!.copyWith(points: newPoints);
      }
      
      return true;
    } catch (e) {
      print('포인트 충전 오류: $e');
      // 테스트 모드에서는 로컬에서 충전
      if (_currentUser != null) {
        final newPoints = _currentUser!.points + amount;
        _currentUser = _currentUser!.copyWith(points: newPoints);
        await _saveTestModePoints(newPoints);
        return true;
      }
      return false;
    }
  }
  
  // 테스트 모드 포인트 저장
  Future<void> _saveTestModePoints(int points) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('test_mode_points', points);
  }
  
  // 테스트 모드 포인트 불러오기
  Future<int> _loadTestModePoints() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('test_mode_points') ?? 100; // 기본 100P
  }

  // 포인트 충분한지 확인
  Future<bool> hasEnoughPoints(int amount) async {
    try {
      final response = await _apiService.post('/api/auth/points/check', {
        'amount': amount,
      });
      return response['hasEnough'] ?? false;
    } catch (e) {
      // 테스트 모드
      return (_currentUser?.points ?? 0) >= amount;
    }
  }

  // 현재 유저 업데이트 (외부에서 호출용)
  void updateCurrentUser(UserModel user) {
    _currentUser = user;
  }
}
