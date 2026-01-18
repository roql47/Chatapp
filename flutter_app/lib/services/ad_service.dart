import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'purchase_service.dart';
import 'api_service.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdReady = false;
  bool _isAdRemoved = false; // 광고 제거 상태
  final PurchaseService _purchaseService = PurchaseService();
  final ApiService _apiService = ApiService();
  
  // 광고 제거 상태 getter
  bool get isAdRemoved => _isAdRemoved;

  // 테스트 광고 ID (실제 배포 시 AdMob 콘솔에서 발급받은 ID로 교체)
  // Android 테스트 전면 광고 ID: ca-app-pub-3940256099942544/1033173712
  // iOS 테스트 전면 광고 ID: ca-app-pub-3940256099942544/4411468910
  String get _interstitialAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/1033173712'; // Android 테스트 ID
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/4411468910'; // iOS 테스트 ID
    }
    throw UnsupportedError('지원되지 않는 플랫폼');
  }

  // AdMob 초기화
  Future<void> initialize() async {
    await MobileAds.instance.initialize();
    await _loadAdRemovalStatus();
    print('🟢 AdMob 초기화 완료');
    
    // 광고 제거가 안 된 경우에만 광고 로드
    if (!_isAdRemoved) {
      _loadInterstitialAd();
    }
  }
  
  // 광고 제거 상태 로드 (로컬 + 서버)
  Future<void> _loadAdRemovalStatus() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. 로컬에서 먼저 확인
    _isAdRemoved = prefs.getBool('ad_removed') ?? false;
    print('🔵 로컬 광고 제거 상태: $_isAdRemoved');
    
    // 2. 서버에서도 확인 (로그인 상태일 때만)
    try {
      final response = await _apiService.get('/auth/ad-removal');
      if (response != null && response['adRemoved'] == true) {
        _isAdRemoved = true;
        await prefs.setBool('ad_removed', true);
        print('🟢 서버에서 광고 제거 상태 복원됨');
      }
    } catch (e) {
      print('🟡 서버 광고 제거 상태 조회 실패 (오프라인 또는 미로그인): $e');
    }
    
    print('🔵 최종 광고 제거 상태: $_isAdRemoved');
  }
  
  // 광고 제거 구매 (실제 인앱결제)
  Future<bool> purchaseAdRemoval() async {
    try {
      // 인앱결제 콜백 설정
      _purchaseService.onAdRemovalSuccess = () async {
        await _setAdRemoved(true);
      };
      
      _purchaseService.onPurchaseError = (error) {
        print('🔴 광고 제거 구매 실패: $error');
      };
      
      // 실제 인앱결제 시작
      final success = await _purchaseService.buyProduct(kAdRemovalProductId);
      return success;
    } catch (e) {
      print('🔴 광고 제거 실패: $e');
      return false;
    }
  }
  
  // 광고 제거 상태 설정 (내부용, 로컬 + 서버)
  Future<void> _setAdRemoved(bool removed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ad_removed', removed);
    _isAdRemoved = removed;
    
    if (removed) {
      // 로드된 광고 정리
      _interstitialAd?.dispose();
      _interstitialAd = null;
      _isInterstitialAdReady = false;
      print('🟢 광고 제거 완료 (로컬)');
      
      // 서버에도 저장 (재설치 시 복원용)
      try {
        await _apiService.post('/auth/ad-removal', {
          'productId': kAdRemovalProductId,
        });
        print('🟢 서버에 광고 제거 상태 저장 완료');
      } catch (e) {
        print('🟡 서버 저장 실패 (로컬에는 저장됨): $e');
      }
    }
  }
  
  // 광고 제거 상태 복원 (구매 복원용, 서버 + 스토어)
  Future<bool> restoreAdRemoval() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 1. 서버에서 먼저 확인 (계정에 저장된 상태)
      try {
        final response = await _apiService.post('/auth/ad-removal/restore', {});
        if (response != null && response['adRemoved'] == true) {
          await prefs.setBool('ad_removed', true);
          _isAdRemoved = true;
          print('🟢 서버에서 광고 제거 복원 성공');
          return true;
        }
      } catch (e) {
        print('🟡 서버 복원 실패, 스토어에서 시도: $e');
      }
      
      // 2. 서버에 없으면 스토어에서 복원 시도 (Google Play / App Store)
      _purchaseService.onAdRemovalSuccess = () async {
        await _setAdRemoved(true);
      };
      
      await _purchaseService.restorePurchases();
      
      // 잠시 대기 (비동기 콜백 처리)
      await Future.delayed(const Duration(seconds: 2));
      
      final restored = prefs.getBool('ad_removed') ?? false;
      _isAdRemoved = restored;
      return restored;
    } catch (e) {
      print('🔴 구매 복원 실패: $e');
      return false;
    }
  }

  // 전면 광고 로드
  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          print('🟢 전면 광고 로드 완료');
          _interstitialAd = ad;
          _isInterstitialAdReady = true;

          _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              print('🔵 전면 광고 닫힘');
              ad.dispose();
              _isInterstitialAdReady = false;
              _loadInterstitialAd(); // 다음 광고 미리 로드
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              print('🔴 전면 광고 표시 실패: $error');
              ad.dispose();
              _isInterstitialAdReady = false;
              _loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          print('🔴 전면 광고 로드 실패: $error');
          _isInterstitialAdReady = false;
          // 3초 후 재시도
          Future.delayed(const Duration(seconds: 3), _loadInterstitialAd);
        },
      ),
    );
  }

  // 전면 광고 표시
  Future<bool> showInterstitialAd() async {
    // 광고 제거 상태면 광고 표시 안 함
    if (_isAdRemoved) {
      print('🟢 광고 제거됨 - 광고 스킵');
      return true; // 성공으로 처리
    }
    
    if (_isInterstitialAdReady && _interstitialAd != null) {
      await _interstitialAd!.show();
      return true;
    } else {
      print('🟡 전면 광고가 준비되지 않음');
      return false;
    }
  }

  // 광고 준비 상태 확인
  bool get isInterstitialAdReady => _isInterstitialAdReady;

  // 리소스 정리
  void dispose() {
    _interstitialAd?.dispose();
  }
}
