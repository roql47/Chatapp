import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart';
import 'package:firebase_core/firebase_core.dart';
import 'config/app_config.dart';
import 'config/theme.dart';
import 'config/router.dart';
import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/call_provider.dart';
import 'providers/theme_provider.dart';
import 'services/ad_service.dart';
import 'services/socket_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 시스템 UI 설정
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  
  // 화면 방향 설정
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // 카카오 SDK 초기화
  KakaoSdk.init(
    nativeAppKey: AppConfig.kakaoNativeAppKey,
    javaScriptAppKey: AppConfig.kakaoJavaScriptKey,
  );
  
  // Firebase 초기화
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase 초기화 실패: $e');
  }
  
  // AdMob 초기화
  try {
    await AdService().initialize();
  } catch (e) {
    debugPrint('AdMob 초기화 실패: $e');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final SocketService _socketService = SocketService();
  ChatProvider? _chatProvider;
  AuthProvider? _authProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.paused:
        // 앱이 백그라운드로 갈 때 - 세션 저장
        print('📱 앱 백그라운드 진입 - 세션 저장');
        _chatProvider?.saveSession();
        break;
        
      case AppLifecycleState.resumed:
        // 앱이 포그라운드로 돌아올 때 - 소켓 재연결
        print('📱 앱 포그라운드 복귀 - 소켓 재연결 시도');
        _reconnectSocket();
        break;
        
      case AppLifecycleState.inactive:
        // 앱이 비활성 상태 (전화 수신 등)
        print('📱 앱 비활성 상태');
        break;
        
      case AppLifecycleState.detached:
        // 앱이 종료될 때
        print('📱 앱 종료');
        _chatProvider?.saveSession();
        break;
        
      case AppLifecycleState.hidden:
        // 앱이 숨겨질 때
        break;
    }
  }
  
  void _reconnectSocket() {
    // 소켓이 연결되어 있지 않으면 재연결
    if (!_socketService.isConnected && _authProvider?.user != null) {
      final user = _authProvider!.user!;
      final token = _authProvider!.token;
      if (token != null) {
        print('🔌 소켓 재연결 시도: ${user.id}');
        _socketService.reconnect();
        
        // 채팅방에 다시 참여
        Future.delayed(const Duration(milliseconds: 500), () {
          _chatProvider?.onSocketReconnected();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => CallProvider()),
      ],
      child: Consumer3<ThemeProvider, ChatProvider, AuthProvider>(
        builder: (context, themeProvider, chatProvider, authProvider, child) {
          // Provider 참조 저장 (생명주기 콜백에서 사용)
          _chatProvider = chatProvider;
          _authProvider = authProvider;
          
          // 테마에 따라 시스템 UI 업데이트
          SystemChrome.setSystemUIOverlayStyle(
            SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: themeProvider.isDarkMode 
                  ? Brightness.light 
                  : Brightness.dark,
            ),
          );
          
          return MaterialApp.router(
            title: AppConfig.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            routerConfig: AppRouter.router,
          );
        },
      ),
    );
  }
}
