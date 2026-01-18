import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/profile_setup_screen.dart';
import '../screens/adult_verification_screen.dart';
import '../screens/home_screen.dart';
import '../screens/matching_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/dm_chat_screen.dart';
import '../screens/video_call_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/point_shop_screen.dart';
import '../screens/friends_screen.dart';
import '../screens/chat_history_screen.dart';
import '../screens/blocked_users_screen.dart';
import '../screens/gift_ranking_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    routes: [
      GoRoute(
        path: '/',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/profile-setup',
        name: 'profile-setup',
        builder: (context, state) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: '/adult-verification',
        name: 'adult-verification',
        builder: (context, state) => const AdultVerificationScreen(),
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/matching',
        name: 'matching',
        builder: (context, state) => const MatchingScreen(),
      ),
      GoRoute(
        path: '/chat',
        name: 'chat',
        builder: (context, state) => const ChatScreen(),
      ),
      GoRoute(
        path: '/video-call',
        name: 'video-call',
        builder: (context, state) {
          final callType = state.extra as String? ?? 'video';
          return VideoCallScreen(callType: callType);
        },
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/point-shop',
        name: 'point-shop',
        builder: (context, state) => const PointShopScreen(),
      ),
      GoRoute(
        path: '/friends',
        name: 'friends',
        builder: (context, state) => const FriendsScreen(),
      ),
      GoRoute(
        path: '/chat-history',
        name: 'chat-history',
        builder: (context, state) => const ChatHistoryScreen(),
      ),
      GoRoute(
        path: '/dm-chat',
        name: 'dm-chat',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          if (extra == null) {
            return const Scaffold(
              body: Center(child: Text('잘못된 접근입니다.')),
            );
          }
          return DMChatScreen(
            roomId: extra['roomId'] ?? '',
            partner: extra['partner'] ?? {},
          );
        },
      ),
      GoRoute(
        path: '/blocked-users',
        name: 'blocked-users',
        builder: (context, state) => const BlockedUsersScreen(),
      ),
      GoRoute(
        path: '/gift-ranking',
        name: 'gift-ranking',
        builder: (context, state) => const GiftRankingScreen(),
      ),
    ],
    redirect: (context, state) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final isLoggedIn = authProvider.isLoggedIn;
      final needsProfile = authProvider.state == AuthState.needsProfile;
      final needsAdultVerification = authProvider.state == AuthState.needsAdultVerification;
      final isOnSplash = state.matchedLocation == '/';
      final isOnLogin = state.matchedLocation == '/login';
      final isOnProfileSetup = state.matchedLocation == '/profile-setup';
      final isOnAdultVerification = state.matchedLocation == '/adult-verification';

      // 스플래시 화면에서는 리다이렉트 하지 않음
      if (isOnSplash) return null;

      // 프로필 설정이 필요한 경우
      if (needsProfile && !isOnProfileSetup) {
        return '/profile-setup';
      }

      // 성인인증이 필요한 경우
      if (needsAdultVerification && !isOnAdultVerification) {
        return '/adult-verification';
      }

      // 로그인이 필요한 경우
      if (!isLoggedIn && !isOnLogin && !isOnProfileSetup && !isOnAdultVerification) {
        return '/login';
      }

      // 이미 로그인된 경우 로그인 페이지 접근 방지
      if (isLoggedIn && isOnLogin) {
        // 성인인증이 필요하면 성인인증 페이지로
        if (needsAdultVerification) {
          return '/adult-verification';
        }
        return '/home';
      }

      return null;
    },
  );
}
