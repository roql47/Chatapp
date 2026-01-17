import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdReady = false;

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
    print('🟢 AdMob 초기화 완료');
    _loadInterstitialAd();
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
