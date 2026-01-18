import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../models/matching_filter.dart';
import '../config/theme.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationEnabled = true;
  bool _locationEnabled = false;
  bool _isLoadingLocation = false;
  final LocationService _locationService = LocationService();
  
  @override
  void initState() {
    super.initState();
    _loadLocationSettings();
  }
  
  Future<void> _loadLocationSettings() async {
    await _locationService.loadSettings();
    if (mounted) {
      setState(() {
        _locationEnabled = _locationService.isLocationEnabled;
      });
    }
  }
  
  Future<void> _toggleLocationSharing(bool value) async {
    setState(() => _isLoadingLocation = true);
    
    try {
      final success = await _locationService.toggleLocationSharing(value);
      
      if (success) {
        setState(() => _locationEnabled = value);
        
        // 서버에 위치 정보 업데이트 (실패해도 로컬은 정상 작동)
        try {
          if (value && _locationService.latitude != null) {
            await ApiService().put('/api/auth/location', {
              'latitude': _locationService.latitude,
              'longitude': _locationService.longitude,
              'enabled': true,
            });
          } else {
            await ApiService().put('/api/auth/location/toggle', {
              'enabled': false,
            });
          }
        } catch (serverError) {
          // 서버 오류는 무시 (로컬에서는 정상 작동)
          print('서버 위치 업데이트 실패 (무시됨): $serverError');
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(value 
                ? '위치 공유가 활성화되었습니다. 매칭 시 거리가 표시됩니다.' 
                : '위치 공유가 비활성화되었습니다.'),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('위치 권한이 필요합니다. 설정에서 위치 권한을 허용해주세요.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('위치 설정 변경 실패: $e')),
        );
      }
    }
    
    setState(() => _isLoadingLocation = false);
  }
  
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final user = authProvider.user;
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [AppTheme.darkBackground, AppTheme.darkSurface]
                : [AppTheme.lightBackground, AppTheme.lightSurface],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 앱바
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: Icon(Icons.arrow_back, color: isDark ? Colors.white70 : Colors.black54),
                    ),
                    Expanded(
                      child: Text(
                        '설정',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 프로필 섹션
                      _buildProfileSection(context, user, isDark),
                      const SizedBox(height: 24),
                      // 계정 섹션
                      _buildSectionTitle('계정', isDark),
                      _buildSettingItem(
                        icon: Icons.person,
                        title: '프로필 수정',
                        isDark: isDark,
                        onTap: () => _showEditProfileDialog(context),
                      ),
                      _buildSettingItem(
                        icon: Icons.block,
                        title: '차단 목록',
                        isDark: isDark,
                        onTap: () => context.push('/blocked-users'),
                      ),
                      _buildSettingItem(
                        icon: Icons.star,
                        title: '내 평가 보기',
                        isDark: isDark,
                        onTap: () => _showMyRatingsDialog(context),
                      ),
                      const SizedBox(height: 24),
                      // 앱 설정 섹션
                      _buildSectionTitle('앱 설정', isDark),
                      _buildSettingItem(
                        icon: Icons.notifications,
                        title: '알림 설정',
                        isDark: isDark,
                        trailing: Switch(
                          value: _notificationEnabled,
                          onChanged: (value) {
                            setState(() => _notificationEnabled = value);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(value ? '알림이 켜졌습니다' : '알림이 꺼졌습니다'),
                              ),
                            );
                          },
                          activeColor: AppTheme.primaryColor,
                        ),
                      ),
                      Consumer<ThemeProvider>(
                        builder: (context, themeProvider, child) {
                          return _buildSettingItem(
                            icon: themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                            title: themeProvider.isDarkMode ? '다크 모드' : '라이트 모드',
                            isDark: isDark,
                            trailing: Switch(
                              value: themeProvider.isDarkMode,
                              onChanged: (value) {
                                themeProvider.toggleTheme();
                              },
                              activeColor: AppTheme.primaryColor,
                            ),
                          );
                        },
                      ),
                      _buildSettingItem(
                        icon: Icons.location_on,
                        title: '위치 공유',
                        isDark: isDark,
                        trailing: _isLoadingLocation
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Switch(
                                value: _locationEnabled,
                                onChanged: _toggleLocationSharing,
                                activeColor: AppTheme.primaryColor,
                              ),
                      ),
                      if (_locationEnabled)
                        Padding(
                          padding: const EdgeInsets.only(left: 16, bottom: 8),
                          child: Text(
                            '매칭 시 상대방과의 대략적인 거리가 표시됩니다.\n정확한 위치는 공유되지 않습니다.',
                            style: TextStyle(
                              color: isDark ? Colors.white38 : Colors.black38,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                      // 정보 섹션
                      _buildSectionTitle('정보', isDark),
                      _buildSettingItem(
                        icon: Icons.info,
                        title: '앱 버전',
                        isDark: isDark,
                        trailing: Text(
                          '1.0.0',
                          style: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                        ),
                      ),
                      _buildSettingItem(
                        icon: Icons.description,
                        title: '이용약관',
                        isDark: isDark,
                        onTap: () => _showTermsDialog(context),
                      ),
                      _buildSettingItem(
                        icon: Icons.privacy_tip,
                        title: '개인정보 처리방침',
                        isDark: isDark,
                        onTap: () => _showPrivacyDialog(context),
                      ),
                      _buildSettingItem(
                        icon: Icons.help,
                        title: '문의하기',
                        isDark: isDark,
                        onTap: () => _showContactDialog(context),
                      ),
                      const SizedBox(height: 24),
                      // 로그아웃 버튼
                      _buildLogoutButton(context),
                      const SizedBox(height: 16),
                      // 회원 탈퇴
                      Center(
                        child: TextButton(
                          onPressed: () => _showDeleteAccountDialog(context),
                          child: Text(
                            '회원 탈퇴',
                            style: TextStyle(
                              color: isDark ? Colors.white38 : Colors.black38,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSection(BuildContext context, user, bool isDark) {
    if (user == null) return const SizedBox();
    
    List<String> interestNames = user.interests.map<String>((id) {
      final category = InterestCategories.categories.firstWhere(
        (c) => c['id'] == id,
        orElse: () => {'name': id},
      );
      return category['name'] as String;
    }).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
              ),
            ),
            child: user.profileImage != null
                ? ClipOval(
                    child: Image.network(
                      user.profileImage!,
                      fit: BoxFit.cover,
                    ),
                  )
                : const Icon(
                    Icons.person,
                    size: 40,
                    color: Colors.white,
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.nickname,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.gender == 'male' ? '남성' : '여성',
                  style: TextStyle(
                    color: isDark ? Colors.white60 : Colors.black54,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: interestNames.take(3).map((name) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 11,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          color: isDark ? Colors.white38 : Colors.black45,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required bool isDark,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: isDark ? Colors.white70 : Colors.black54),
        title: Text(
          title,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        ),
        trailing: trailing ?? Icon(Icons.chevron_right, color: isDark ? Colors.white38 : Colors.black38),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () => _showLogoutDialog(context),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.errorColor,
          side: const BorderSide(color: AppTheme.errorColor),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text('로그아웃'),
      ),
    );
  }

  // 차단 목록 다이얼로그
  void _showBlockedUsersDialog(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Text('차단 목록', style: TextStyle(color: Colors.white)),
        content: FutureBuilder(
          future: ApiService().get('/api/auth/blocked'),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            
            final blockedUsers = snapshot.data?['blockedUsers'] as List? ?? [];
            
            if (blockedUsers.isEmpty) {
              return const SizedBox(
                height: 100,
                child: Center(
                  child: Text(
                    '차단한 사용자가 없습니다',
                    style: TextStyle(color: Colors.white60),
                  ),
                ),
              );
            }
            
            return SizedBox(
              height: 300,
              width: double.maxFinite,
              child: ListView.builder(
                itemCount: blockedUsers.length,
                itemBuilder: (context, index) {
                  final user = blockedUsers[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primaryColor,
                      backgroundImage: user['profileImage'] != null
                          ? NetworkImage(user['profileImage'])
                          : null,
                      child: user['profileImage'] == null
                          ? const Icon(Icons.person, color: Colors.white)
                          : null,
                    ),
                    title: Text(
                      user['nickname'] ?? '알 수 없음',
                      style: const TextStyle(color: Colors.white),
                    ),
                    trailing: TextButton(
                      onPressed: () async {
                        try {
                          await ApiService().delete('/api/auth/block/${user['_id']}');
                          Navigator.pop(context);
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(content: Text('차단이 해제되었습니다')),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(content: Text('오류: $e')),
                          );
                        }
                      },
                      child: const Text('해제'),
                    ),
                  );
                },
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  // 내 평가 보기
  void _showMyRatingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Text('내 평가', style: TextStyle(color: Colors.white)),
        content: FutureBuilder(
          future: ApiService().get('/api/ratings/received'),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final stats = snapshot.data?['stats'];
            final ratings = snapshot.data?['ratings'] as List? ?? [];

            return SizedBox(
              height: 350,
              width: double.maxFinite,
              child: Column(
                children: [
                  // 평균 점수
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.darkSurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${(stats?['averageScore'] ?? 0).toStringAsFixed(1)}',
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: List.generate(5, (i) => Icon(
                                i < (stats?['averageScore'] ?? 0).round()
                                    ? Icons.star
                                    : Icons.star_border,
                                color: Colors.amber,
                                size: 16,
                              )),
                            ),
                            Text(
                              '${stats?['totalRatings'] ?? 0}개의 평가',
                              style: const TextStyle(color: Colors.white60, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 평가 태그
                  if (stats?['tags'] != null)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if ((stats['tags']['friendly'] ?? 0) > 0)
                          _buildTagChip('😊 친절해요', stats['tags']['friendly']),
                        if ((stats['tags']['funny'] ?? 0) > 0)
                          _buildTagChip('😂 유머있어요', stats['tags']['funny']),
                        if ((stats['tags']['interesting'] ?? 0) > 0)
                          _buildTagChip('💬 재미있어요', stats['tags']['interesting']),
                        if ((stats['tags']['respectful'] ?? 0) > 0)
                          _buildTagChip('🎩 예의바름', stats['tags']['respectful']),
                        if ((stats['tags']['goodListener'] ?? 0) > 0)
                          _buildTagChip('👂 경청 잘함', stats['tags']['goodListener']),
                      ],
                    ),
                  const SizedBox(height: 16),
                  if (ratings.isEmpty)
                    const Text(
                      '아직 받은 평가가 없습니다',
                      style: TextStyle(color: Colors.white60),
                    ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  Widget _buildTagChip(String label, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '$label ($count)',
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
    );
  }

  // 이용약관
  void _showTermsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Text('이용약관', style: TextStyle(color: Colors.white)),
        content: const SingleChildScrollView(
          child: Text(
            '''제1조 (목적)
이 약관은 랜덤채팅 서비스 이용에 관한 조건 및 절차를 규정함을 목적으로 합니다.

제2조 (서비스 이용)
1. 서비스는 만 19세 이상만 이용 가능합니다.
2. 타인에게 불쾌감을 주는 행위는 금지됩니다.
3. 불법적인 콘텐츠 공유는 금지됩니다.

제3조 (개인정보)
1. 회원의 개인정보는 서비스 제공 목적으로만 사용됩니다.
2. 개인정보는 관련 법률에 따라 보호됩니다.

제4조 (서비스 중단)
1. 서비스는 사전 통지 없이 변경되거나 중단될 수 있습니다.
2. 약관 위반 시 서비스 이용이 제한될 수 있습니다.

제5조 (면책)
1. 회원 간 분쟁에 대해 회사는 책임지지 않습니다.
2. 천재지변 등 불가항력으로 인한 서비스 중단은 면책됩니다.''',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  // 개인정보 처리방침
  void _showPrivacyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Text('개인정보 처리방침', style: TextStyle(color: Colors.white)),
        content: const SingleChildScrollView(
          child: Text(
            '''1. 수집하는 개인정보
- 카카오 계정 정보 (닉네임, 프로필 사진)
- 서비스 이용 기록

2. 개인정보 이용 목적
- 서비스 제공 및 회원 관리
- 서비스 개선 및 신규 서비스 개발

3. 개인정보 보유 기간
- 회원 탈퇴 시까지
- 법령에 따른 보존 기간

4. 개인정보 제3자 제공
- 원칙적으로 제3자에게 제공하지 않습니다.
- 법률에 의한 경우 예외

5. 개인정보 파기
- 목적 달성 시 지체 없이 파기
- 전자적 파일: 복구 불가능한 방법으로 삭제

6. 이용자 권리
- 개인정보 열람, 정정, 삭제 요청 가능
- 동의 철회 가능

7. 문의
- 앱 내 문의하기를 통해 연락 바랍니다.''',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  // 문의하기
  void _showContactDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Text('문의하기', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.email, color: Colors.white70),
              title: const Text('이메일 문의', style: TextStyle(color: Colors.white)),
              subtitle: const Text('support@randomchat.com', style: TextStyle(color: Colors.white60)),
              onTap: () async {
                final uri = Uri.parse('mailto:support@randomchat.com?subject=랜덤채팅 문의');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
            ),
            const Divider(color: Colors.white24),
            ListTile(
              leading: const Icon(Icons.bug_report, color: Colors.white70),
              title: const Text('버그 신고', style: TextStyle(color: Colors.white)),
              subtitle: const Text('오류를 발견하셨나요?', style: TextStyle(color: Colors.white60)),
              onTap: () {
                Navigator.pop(context);
                _showBugReportDialog(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  // 버그 신고
  void _showBugReportDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Text('버그 신고', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          maxLines: 5,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: '발견하신 버그에 대해 설명해주세요',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: AppTheme.darkSurface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(this.context).showSnackBar(
                const SnackBar(content: Text('버그 신고가 접수되었습니다. 감사합니다!')),
              );
            },
            child: const Text('제출'),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user!;
    final nicknameController = TextEditingController(text: user.nickname);
    String selectedGender = user.gender;
    String? selectedMbti = user.mbti.isEmpty ? null : user.mbti;
    List<String> selectedInterests = List.from(user.interests);
    final bool isGenderLocked = user.genderLocked;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: AppTheme.darkSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                '프로필 수정',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: nicknameController,
                style: const TextStyle(color: Colors.white),
                maxLength: 10,
                decoration: InputDecoration(
                  labelText: '닉네임',
                  labelStyle: const TextStyle(color: Colors.white60),
                  counterStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: AppTheme.darkCard,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('성별', style: TextStyle(color: Colors.white60)),
                  if (isGenderLocked) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock, color: Colors.grey, size: 12),
                          SizedBox(width: 4),
                          Text('변경불가', style: TextStyle(color: Colors.grey, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildGenderOption(
                    'male',
                    '남성',
                    selectedGender,
                    isGenderLocked ? null : (value) => setState(() => selectedGender = value),
                    isLocked: isGenderLocked,
                  ),
                  const SizedBox(width: 12),
                  _buildGenderOption(
                    'female',
                    '여성',
                    selectedGender,
                    isGenderLocked ? null : (value) => setState(() => selectedGender = value),
                    isLocked: isGenderLocked,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text('MBTI', style: TextStyle(color: Colors.white60)),
              const SizedBox(height: 8),
              SizedBox(
                height: 80,
                child: GridView.builder(
                  scrollDirection: Axis.horizontal,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.6,
                  ),
                  itemCount: MbtiTypes.types.length,
                  itemBuilder: (context, index) {
                    final mbti = MbtiTypes.types[index];
                    final isSelected = selectedMbti == mbti;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (selectedMbti == mbti) {
                            selectedMbti = null;
                          } else {
                            selectedMbti = mbti;
                          }
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primaryColor : AppTheme.darkCard,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            mbti,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              const Text('관심사', style: TextStyle(color: Colors.white60)),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: InterestCategories.categories.map((category) {
                      final isSelected = selectedInterests.contains(category['id']);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              selectedInterests.remove(category['id']);
                            } else if (selectedInterests.length < 5) {
                              selectedInterests.add(category['id']);
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.primaryColor : AppTheme.darkCard,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            category['name'],
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await authProvider.updateProfile(
                      nickname: nicknameController.text.trim(),
                      gender: isGenderLocked ? null : selectedGender,
                      interests: selectedInterests,
                      mbti: selectedMbti,
                    );
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('저장'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenderOption(String value, String label, String selected, Function(String)? onTap, {bool isLocked = false}) {
    final isSelected = selected == value;
    return Expanded(
      child: GestureDetector(
        onTap: onTap != null ? () => onTap(value) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected 
                ? (isLocked ? Colors.grey.shade700 : AppTheme.primaryColor) 
                : AppTheme.darkCard,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : (isLocked ? Colors.white38 : Colors.white70),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: const Text('로그아웃', style: TextStyle(color: Colors.white)),
        content: const Text(
          '로그아웃 하시겠습니까?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              await authProvider.logout();
              if (mounted) context.go('/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: const Text('회원 탈퇴', style: TextStyle(color: Colors.white)),
        content: const Text(
          '정말 탈퇴하시겠습니까?\n모든 데이터가 삭제되며 복구할 수 없습니다.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              final success = await authProvider.deleteAccount();
              if (success && mounted) {
                context.go('/login');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('탈퇴'),
          ),
        ],
      ),
    );
  }
}
