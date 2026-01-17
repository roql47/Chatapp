import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/theme_provider.dart';
import '../models/matching_filter.dart';
import '../config/theme.dart';
import '../services/ad_service.dart';
import '../services/storage_service.dart';
import '../widgets/profile_image_viewer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _startMatching() async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final adService = AdService();
    
    // 매칭 전 전면 광고 표시
    if (adService.isInterstitialAdReady) {
      await adService.showInterstitialAd();
      // 광고 닫힐 때까지 잠시 대기
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    if (!mounted) return;
    
    // 성별 필터가 있으면 포인트 확인 및 차감
    if (chatProvider.hasGenderFilter) {
      final success = await chatProvider.startMatchingWithPoints();
      
      if (!success && mounted) {
        // 포인트 부족 - 충전 화면으로 이동 제안
        _showPointsNeededDialog(chatProvider.matchingError ?? '포인트가 부족합니다.');
        return;
      }
    } else {
      chatProvider.startMatching();
    }
    
    if (mounted) {
      context.push('/matching');
    }
  }

  void _showPointsNeededDialog(String message) {
    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
        title: Text(
          '포인트 부족',
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        ),
        content: Text(
          message,
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/point-shop');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('충전하기'),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const FilterBottomSheet(),
    );
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final chatProvider = Provider.of<ChatProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final user = authProvider.user;
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(user, isDark),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [AppTheme.darkBackground, AppTheme.darkSurface]
                : [AppTheme.lightBackground, Colors.white],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // 상단 바
                _buildTopBar(user?.nickname ?? '사용자', user?.points ?? 0, isDark),
                const Spacer(),
                // 매칭 버튼
                _buildMatchButton(isDark),
                const SizedBox(height: 24),
                // 필터 표시
                _buildFilterInfo(chatProvider.filter, isDark),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 프로필 사진 변경 옵션 표시
  void _showProfileImageOptions(BuildContext drawerContext, bool isDark) {
    final storageService = StorageService();
    
    showModalBottomSheet(
      context: drawerContext,
      backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '프로필 사진 변경',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_library, color: AppTheme.primaryColor),
                ),
                title: Text(
                  '갤러리에서 선택',
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final file = await storageService.pickImageFromGallery();
                  if (file != null) {
                    await _uploadProfileImage(file);
                  }
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.camera_alt, color: Colors.blue),
                ),
                title: Text(
                  '카메라로 촬영',
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final file = await storageService.pickImageFromCamera();
                  if (file != null) {
                    await _uploadProfileImage(file);
                  }
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.image, color: isDark ? Colors.white54 : Colors.grey),
                ),
                title: Text(
                  '현재 사진 보기',
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                ),
                onTap: () {
                  Navigator.pop(context);
                  final authProvider = Provider.of<AuthProvider>(drawerContext, listen: false);
                  final user = authProvider.user;
                  if (user != null) {
                    ProfileImageViewer.show(
                      drawerContext,
                      imageUrl: user.profileImage,
                      nickname: user.nickname,
                      heroTag: 'my_profile_image',
                    );
                  }
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _uploadProfileImage(dynamic file) async {
    final storageService = StorageService();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    
    if (user == null) return;

    // 로딩 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      ),
    );

    try {
      // 이미지 업로드
      final imageUrl = await storageService.uploadProfileImage(file, user.id);
      
      if (imageUrl != null) {
        // 프로필 업데이트
        await authProvider.updateProfile(profileImage: imageUrl);
        
        if (mounted) {
          Navigator.pop(context); // 로딩 닫기
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('프로필 사진이 변경되었습니다.')),
          );
        }
      } else {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('이미지 업로드에 실패했습니다.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e')),
        );
      }
    }
  }

  // 사이드 메뉴 (Drawer)
  Widget _buildDrawer(user, bool isDark) {
    return Drawer(
      backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // 프로필 헤더
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : AppTheme.lightBackground,
                border: Border(
                  bottom: BorderSide(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1)),
                ),
              ),
              child: Row(
                children: [
                  // 프로필 사진 (클릭 시 변경 옵션)
                  GestureDetector(
                    onTap: () => _showProfileImageOptions(context, isDark),
                    child: Stack(
                      children: [
                        Hero(
                          tag: 'my_profile_image',
                          child: CircleAvatar(
                            radius: 30,
                            backgroundColor: AppTheme.primaryColor,
                            backgroundImage: user?.profileImage != null
                                ? NetworkImage(user!.profileImage!)
                                : null,
                            child: user?.profileImage == null
                                ? const Icon(Icons.person, color: Colors.white, size: 30)
                                : null,
                          ),
                        ),
                        // 카메라 아이콘 오버레이
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark ? AppTheme.darkCard : Colors.white,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.nickname ?? '사용자',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.monetization_on, color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '${user?.points ?? 0}P',
                              style: const TextStyle(color: Colors.amber, fontSize: 14),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // 메뉴 목록
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildDrawerItem(
                    icon: Icons.people,
                    title: '친구 목록',
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/friends');
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.history,
                    title: '채팅 기록',
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/chat-history');
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.block,
                    title: '차단 목록',
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(context);
                      _showBlockList(isDark);
                    },
                  ),
                  Divider(color: isDark ? Colors.white12 : Colors.black12, height: 32),
                  _buildDrawerItem(
                    icon: Icons.workspace_premium,
                    title: 'VIP 멤버십',
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/vip-shop');
                    },
                    textColor: Colors.amber,
                  ),
                  _buildDrawerItem(
                    icon: Icons.shopping_bag,
                    title: '포인트 충전',
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/point-shop');
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.settings,
                    title: '설정',
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/settings');
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.help_outline,
                    title: '도움말',
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(context);
                      _showHelp(isDark);
                    },
                  ),
                ],
              ),
            ),
            
            // 하단 로그아웃
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1)),
                ),
              ),
              child: _buildDrawerItem(
                icon: Icons.logout,
                title: '로그아웃',
                isDark: isDark,
                onTap: () async {
                  Navigator.pop(context);
                  await Provider.of<AuthProvider>(context, listen: false).logout();
                  if (mounted) context.go('/login');
                },
                textColor: Colors.redAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required bool isDark,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: textColor ?? (isDark ? Colors.white70 : Colors.black54)),
      title: Text(
        title,
        style: TextStyle(
          color: textColor ?? (isDark ? Colors.white : Colors.black87),
          fontSize: 15,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
    );
  }

  Widget _buildTopBar(String nickname, int points, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // 햄버거 메뉴 버튼
        Row(
          children: [
            GestureDetector(
              onTap: () => _scaffoldKey.currentState?.openDrawer(),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isDark ? null : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(Icons.menu, color: isDark ? Colors.white70 : Colors.black54),
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '안녕하세요!',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.white60 : Colors.black45,
                  ),
                ),
                Text(
                  nickname,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        // 포인트 표시
        GestureDetector(
          onTap: () => context.push('/point-shop'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.amber.withOpacity(0.3),
                width: 1,
              ),
              boxShadow: isDark ? null : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.monetization_on,
                  color: Colors.amber,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  '$points',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.add_circle,
                  color: Colors.amber,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMatchButton(bool isDark) {
    return Column(
      children: [
        ScaleTransition(
          scale: _pulseAnimation,
          child: GestureDetector(
            onTap: _startMatching,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primaryColor,
                    AppTheme.secondaryColor,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.4),
                    blurRadius: 30,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shuffle,
                    size: 60,
                    color: Colors.white,
                  ),
                  SizedBox(height: 8),
                  Text(
                    '매칭 시작',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          '버튼을 눌러 새로운 인연을 만나보세요',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: isDark ? Colors.white60 : Colors.black45,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterInfo(MatchingFilter filter, bool isDark) {
    final hasGenderFilter = filter.preferredGender != null && 
                            filter.preferredGender != 'any';
    String genderText = filter.preferredGender == 'any' || filter.preferredGender == null
        ? '상관없음'
        : filter.preferredGender == 'male'
            ? '남성'
            : '여성';

    return GestureDetector(
      onTap: _showFilterSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: hasGenderFilter ? Border.all(
            color: Colors.amber.withOpacity(0.5),
            width: 1,
          ) : null,
          boxShadow: isDark ? null : [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.tune, color: AppTheme.primaryColor),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '매칭 필터',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (hasGenderFilter) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.monetization_on,
                                  color: Colors.amber,
                                  size: 12,
                                ),
                                SizedBox(width: 2),
                                Text(
                                  '10P',
                                  style: TextStyle(
                                    color: Colors.amber,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '성별: $genderText | 관심사: ${filter.interests.isEmpty ? "전체" : "${filter.interests.length}개"}',
                      style: TextStyle(
                        color: isDark ? Colors.white60 : Colors.black45,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Icon(Icons.chevron_right, color: isDark ? Colors.white38 : Colors.black38),
          ],
        ),
      ),
    );
  }

  void _showChatHistory(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '채팅 기록',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 60, color: isDark ? Colors.white24 : Colors.black12),
                    const SizedBox(height: 16),
                    Text(
                      '아직 채팅 기록이 없어요',
                      style: TextStyle(color: isDark ? Colors.white60 : Colors.black45, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '새로운 대화를 시작해보세요!',
                      style: TextStyle(color: isDark ? Colors.white38 : Colors.black26, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBlockList(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '차단 목록',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.block, size: 60, color: isDark ? Colors.white24 : Colors.black12),
                    const SizedBox(height: 16),
                    Text(
                      '차단한 사용자가 없어요',
                      style: TextStyle(color: isDark ? Colors.white60 : Colors.black45, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '불쾌한 사용자를 차단하면\n여기에 표시됩니다',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: isDark ? Colors.white38 : Colors.black26, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHelp(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '도움말',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHelpItem(
                      '매칭 시작',
                      '홈 화면의 큰 버튼을 눌러 랜덤 매칭을 시작하세요. 필터를 설정하면 원하는 조건의 상대를 만날 수 있어요.',
                      isDark,
                    ),
                    _buildHelpItem(
                      '채팅하기',
                      '매칭이 되면 텍스트, 이미지, 음성/영상 통화로 대화할 수 있어요.',
                      isDark,
                    ),
                    _buildHelpItem(
                      '신고 및 차단',
                      '불쾌한 사용자는 채팅방에서 신고하거나 차단할 수 있어요. 차단된 사용자와는 다시 매칭되지 않아요.',
                      isDark,
                    ),
                    _buildHelpItem(
                      '설정',
                      '우측 상단 설정 버튼에서 프로필 수정, 알림 설정 등을 변경할 수 있어요.',
                      isDark,
                    ),
                    _buildHelpItem(
                      '개인정보 보호',
                      '상대방에게는 닉네임과 관심사만 표시돼요. 개인정보는 안전하게 보호됩니다.',
                      isDark,
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.mail_outline, color: AppTheme.primaryColor),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '문의하기',
                                  style: TextStyle(
                                    color: isDark ? Colors.white : Colors.black87,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'support@randomchat.com',
                                  style: TextStyle(
                                    color: isDark ? Colors.white60 : Colors.black45,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpItem(String title, String content, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              color: isDark ? Colors.white60 : Colors.black45,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

}

// 필터 바텀 시트
class FilterBottomSheet extends StatefulWidget {
  const FilterBottomSheet({super.key});

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late String _selectedGender;
  late String _selectedMbti;
  late List<String> _selectedInterests;

  @override
  void initState() {
    super.initState();
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    _selectedGender = chatProvider.filter.preferredGender ?? 'any';
    _selectedMbti = chatProvider.filter.preferredMbti ?? 'any';
    _selectedInterests = List.from(chatProvider.filter.interests);
  }

  void _saveFilter() {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    chatProvider.updateFilter(MatchingFilter(
      preferredGender: _selectedGender,
      preferredMbti: _selectedMbti,
      interests: _selectedInterests,
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 핸들
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // 제목
          Text(
            '매칭 필터 설정',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          // 성별 필터
          Row(
            children: [
              Text(
                '상대방 성별',
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.monetization_on, color: Colors.amber, size: 14),
                    SizedBox(width: 4),
                    Text(
                      '성별 지정 시 10P',
                      style: TextStyle(
                        color: Colors.amber,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildGenderChip('any', '무료', isDark, isAny: true),
              const SizedBox(width: 8),
              _buildGenderChip('male', '남성', isDark, isAny: false),
              const SizedBox(width: 8),
              _buildGenderChip('female', '여성', isDark, isAny: false),
            ],
          ),
          const SizedBox(height: 24),
          // MBTI 필터
          Text(
            '상대방 MBTI',
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildMbtiChip('any', '상관없음', isDark),
                  const SizedBox(width: 8),
                  ...MbtiTypes.types.map((mbti) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildMbtiChip(mbti, mbti, isDark),
                  )).toList(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // 관심사 필터
          Text(
            '관심사',
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: InterestCategories.categories.map((category) {
                  final isSelected = _selectedInterests.contains(category['id']);
                  return _buildInterestChip(category, isSelected, isDark);
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // 저장 버튼
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveFilter,
              child: const Text('저장'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildGenderChip(String value, String label, bool isDark, {bool isAny = false}) {
    final isSelected = _selectedGender == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedGender = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppTheme.primaryColor 
              : (isDark ? AppTheme.darkCard : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(24),
          border: !isAny && !isSelected ? Border.all(
            color: Colors.amber.withOpacity(0.3),
            width: 1,
          ) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected 
                    ? Colors.white 
                    : (isDark ? Colors.white70 : Colors.black54),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (!isAny && !isSelected) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.monetization_on,
                color: Colors.amber.withOpacity(0.7),
                size: 14,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMbtiChip(String value, String label, bool isDark) {
    final isSelected = _selectedMbti == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedMbti = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppTheme.primaryColor 
              : (isDark ? AppTheme.darkCard : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected 
                ? Colors.white 
                : (isDark ? Colors.white70 : Colors.black54),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildInterestChip(Map<String, dynamic> category, bool isSelected, bool isDark) {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedInterests.remove(category['id']);
          } else {
            _selectedInterests.add(category['id']);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppTheme.primaryColor.withOpacity(0.3) 
              : (isDark ? AppTheme.darkCard : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.transparent,
          ),
        ),
        child: Text(
          category['name'],
          style: TextStyle(
            color: isSelected 
                ? (isDark ? Colors.white : AppTheme.primaryColor)
                : (isDark ? Colors.white70 : Colors.black54),
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
