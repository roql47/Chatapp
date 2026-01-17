# 랜덤채팅 앱

가가채팅과 유사한 실시간 랜덤채팅 앱입니다. Flutter와 Node.js로 개발되었습니다.

## 주요 기능

- 🔐 **카카오톡 로그인** - 간편한 소셜 로그인
- 🎯 **스마트 매칭** - 성별, 관심사 기반 필터링
- 💬 **실시간 채팅** - Socket.io 기반 텍스트 채팅
- 📷 **이미지 전송** - Firebase Storage 연동
- 📹 **영상/음성 통화** - WebRTC 기반 실시간 통화
- 🚫 **신고/차단** - 안전한 채팅 환경

## 기술 스택

### Frontend (Flutter)
- Flutter 3.x
- Provider (상태관리)
- kakao_flutter_sdk (카카오 로그인)
- socket_io_client (실시간 통신)
- flutter_webrtc (영상통화)
- firebase_storage (이미지 저장)

### Backend (Node.js)
- Express.js
- Socket.io
- MongoDB + Mongoose
- JWT 인증

## 프로젝트 구조

```
Chatapp/
├── flutter_app/           # Flutter 앱
│   ├── lib/
│   │   ├── main.dart
│   │   ├── config/        # 설정 파일
│   │   ├── models/        # 데이터 모델
│   │   ├── providers/     # 상태관리
│   │   ├── screens/       # 화면들
│   │   ├── services/      # API, Socket, WebRTC
│   │   └── widgets/       # 재사용 위젯
│   └── pubspec.yaml
│
├── server/                # Node.js 백엔드
│   ├── src/
│   │   ├── index.js       # 진입점
│   │   ├── config/        # DB, 환경설정
│   │   ├── models/        # MongoDB 스키마
│   │   ├── routes/        # REST API
│   │   ├── socket/        # Socket.io 핸들러
│   │   └── services/      # 매칭, 인증 로직
│   └── package.json
│
└── README.md
```

## 설치 및 실행

### 사전 요구사항

- Flutter SDK 3.x
- Node.js 18+
- MongoDB
- Firebase 프로젝트

### 1. 카카오 개발자 설정

1. [카카오 개발자 콘솔](https://developers.kakao.com/)에서 앱 생성
2. 네이티브 앱 키, JavaScript 키 발급
3. 플랫폼 등록 (Android, iOS)

### 2. Firebase 설정

1. [Firebase 콘솔](https://console.firebase.google.com/)에서 프로젝트 생성
2. Android/iOS 앱 등록
3. `google-services.json` (Android) 다운로드 → `flutter_app/android/app/`
4. `GoogleService-Info.plist` (iOS) 다운로드 → `flutter_app/ios/Runner/`
5. Firebase Storage 활성화

### 3. Flutter 앱 설정

```bash
cd flutter_app

# 패키지 설치
flutter pub get

# 카카오 앱 키 설정
# lib/config/app_config.dart 파일 수정
```

`lib/config/app_config.dart`:
```dart
static const String kakaoNativeAppKey = 'YOUR_KAKAO_NATIVE_APP_KEY';
static const String kakaoJavaScriptKey = 'YOUR_KAKAO_JAVASCRIPT_KEY';
```

Android 설정 (`android/app/src/main/AndroidManifest.xml`):
```xml
<data android:scheme="kakao{YOUR_KAKAO_NATIVE_APP_KEY}" android:host="oauth"/>
```

### 4. 백엔드 설정

```bash
cd server

# 패키지 설치
npm install

# 환경변수 설정 (선택사항)
# 기본값은 src/config/env.js에 정의되어 있습니다.
```

환경변수 (선택):
```
PORT=3000
MONGODB_URI=mongodb://localhost:27017/randomchat
JWT_SECRET=your_jwt_secret_key
KAKAO_REST_API_KEY=your_kakao_rest_api_key
```

### 5. 실행

**MongoDB 시작:**
```bash
mongod
```

**백엔드 서버 시작:**
```bash
cd server
npm run dev  # 개발 모드 (nodemon)
# 또는
npm start    # 프로덕션 모드
```

**Flutter 앱 실행:**
```bash
cd flutter_app
flutter run
```

## API 엔드포인트

### 인증 API
| Method | Endpoint | 설명 |
|--------|----------|------|
| POST | /api/auth/kakao | 카카오 로그인 |
| GET | /api/auth/me | 내 정보 조회 |
| PUT | /api/auth/profile | 프로필 수정 |
| POST | /api/auth/block/:userId | 사용자 차단 |
| DELETE | /api/auth/block/:userId | 차단 해제 |
| GET | /api/auth/blocked | 차단 목록 |
| DELETE | /api/auth/account | 회원 탈퇴 |

### 신고 API
| Method | Endpoint | 설명 |
|--------|----------|------|
| POST | /api/reports | 신고하기 |
| GET | /api/reports/my | 내 신고 목록 |

### Socket.io 이벤트

**클라이언트 → 서버:**
- `start_matching` - 매칭 시작
- `cancel_matching` - 매칭 취소
- `join_room` - 채팅방 참가
- `leave_room` - 채팅방 나가기
- `send_message` - 메시지 전송
- `typing` - 타이핑 상태
- `call_offer` - 통화 요청
- `call_answer` - 통화 응답
- `ice_candidate` - ICE 후보 전송
- `end_call` - 통화 종료

**서버 → 클라이언트:**
- `match_found` - 매칭 완료
- `match_cancelled` - 매칭 취소됨
- `message` - 메시지 수신
- `typing` - 상대방 타이핑
- `partner_disconnected` - 상대방 연결 해제
- `call_offer` - 통화 요청 수신
- `call_answer` - 통화 응답 수신
- `ice_candidate` - ICE 후보 수신
- `call_ended` - 통화 종료됨

## 스크린샷

*(앱 실행 후 스크린샷 추가)*

## 라이선스

MIT License
