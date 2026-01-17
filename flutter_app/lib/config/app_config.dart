import 'dart:io';

// 앱 설정 파일
class AppConfig {
  // 서버 URL (개발 환경)
  // Android 에뮬레이터: 10.0.2.2, iOS 시뮬레이터: localhost, 실제 기기: 실제 IP
  static String get serverUrl {
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:3000'; // Android 에뮬레이터
    }
    return 'http://localhost:3000'; // iOS 또는 기타
  }
  
  // 카카오 앱 키
  static const String kakaoNativeAppKey = '3773d0637803ebf39f211c860838fc32';
  static const String kakaoJavaScriptKey = 'f9be1b8ebbb3bac36393a20c006fdee6';
  
  // WebRTC STUN/TURN 서버 설정
  static const List<Map<String, String>> iceServers = [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
  ];
  
  // 앱 정보
  static const String appName = '랜덤채팅';
  static const String appVersion = '1.0.0';
}
