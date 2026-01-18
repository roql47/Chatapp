// 앱 설정 파일
class AppConfig {
  // 서버 URL (프로덕션 - AWS Lightsail)
  static String get serverUrl {
    return 'http://52.79.154.253:3001'; // AWS Lightsail 서버 (포트 3001)
  }
  
  // 카카오 앱 키
  static const String kakaoNativeAppKey = '3773d0637803ebf39f211c860838fc32';
  static const String kakaoJavaScriptKey = 'f9be1b8ebbb3bac36393a20c006fdee6';
  
  // WebRTC STUN/TURN 서버 설정
  static const List<Map<String, dynamic>> iceServers = [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
    {'urls': 'stun:stun2.l.google.com:19302'},
    {'urls': 'stun:stun3.l.google.com:19302'},
    {'urls': 'stun:stun4.l.google.com:19302'},
    // 무료 TURN 서버 (OpenRelay)
    {
      'urls': 'turn:openrelay.metered.ca:80',
      'username': 'openrelayproject',
      'credential': 'openrelayproject',
    },
    {
      'urls': 'turn:openrelay.metered.ca:443',
      'username': 'openrelayproject',
      'credential': 'openrelayproject',
    },
    {
      'urls': 'turn:openrelay.metered.ca:443?transport=tcp',
      'username': 'openrelayproject',
      'credential': 'openrelayproject',
    },
  ];
  
  // 앱 정보
  static const String appName = '랜덤채팅';
  static const String appVersion = '1.0.0';
}
