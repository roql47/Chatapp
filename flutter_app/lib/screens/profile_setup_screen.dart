import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/matching_filter.dart';
import '../config/theme.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nicknameController = TextEditingController();
  String? _selectedGender;
  String? _selectedMbti;
  final List<String> _selectedInterests = [];
  int _currentStep = 0;
  bool _isLoading = false;

  // MBTI 목록
  static const List<String> _mbtiTypes = [
    'INTJ', 'INTP', 'ENTJ', 'ENTP',
    'INFJ', 'INFP', 'ENFJ', 'ENFP',
    'ISTJ', 'ISFJ', 'ESTJ', 'ESFJ',
    'ISTP', 'ISFP', 'ESTP', 'ESFP',
  ];

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user != null) {
      _nicknameController.text = authProvider.user!.nickname;
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep == 0 && _nicknameController.text.trim().isEmpty) {
      _showError('닉네임을 입력해주세요.');
      return;
    }
    if (_currentStep == 1 && _selectedGender == null) {
      _showError('성별을 선택해주세요.');
      return;
    }
    // MBTI는 선택 안 해도 넘어갈 수 있음 (선택 사항)
    if (_currentStep == 3 && _selectedInterests.isEmpty) {
      _showError('관심사를 1개 이상 선택해주세요.');
      return;
    }

    if (_currentStep < 3) {
      setState(() => _currentStep++);
    } else {
      _saveProfile();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.setupProfile(
      nickname: _nicknameController.text.trim(),
      gender: _selectedGender!,
      interests: _selectedInterests,
      mbti: _selectedMbti,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (success) {
      context.go('/home');
    } else {
      _showError(authProvider.error ?? '프로필 설정에 실패했습니다.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.darkBackground,
              AppTheme.darkSurface,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // 진행 표시
                _buildProgressIndicator(),
                const SizedBox(height: 40),
                // 단계별 컨텐츠
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _buildStepContent(),
                  ),
                ),
                // 버튼들
                _buildButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Row(
      children: List.generate(4, (index) {
        final isActive = index <= _currentStep;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: index < 3 ? 8 : 0),
            height: 4,
            decoration: BoxDecoration(
              color: isActive ? AppTheme.primaryColor : AppTheme.darkCard,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildNicknameStep();
      case 1:
        return _buildGenderStep();
      case 2:
        return _buildMbtiStep();
      case 3:
        return _buildInterestsStep();
      default:
        return const SizedBox();
    }
  }

  Widget _buildNicknameStep() {
    return Column(
      key: const ValueKey('nickname'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '닉네임을 입력해주세요',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '채팅에서 사용할 닉네임입니다.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white60,
          ),
        ),
        const SizedBox(height: 40),
        TextField(
          controller: _nicknameController,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          maxLength: 10,
          cursorColor: AppTheme.primaryColor,
          decoration: InputDecoration(
            hintText: '닉네임 (최대 10자)',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
            prefixIcon: const Icon(Icons.person, color: AppTheme.primaryColor),
            counterStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: AppTheme.darkCard,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderStep() {
    return Column(
      key: const ValueKey('gender'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '성별을 선택해주세요',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '매칭 필터에 사용됩니다.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white60,
          ),
        ),
        const SizedBox(height: 40),
        Row(
          children: [
            Expanded(
              child: _buildGenderOption('male', '남성', Icons.male),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildGenderOption('female', '여성', Icons.female),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGenderOption(String value, String label, IconData icon) {
    final isSelected = _selectedGender == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedGender = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 40),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withOpacity(0.2) : AppTheme.darkCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 48,
              color: isSelected ? AppTheme.primaryColor : Colors.white60,
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppTheme.primaryColor : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMbtiStep() {
    return Column(
      key: const ValueKey('mbti'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MBTI를 선택해주세요',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '선택하지 않아도 됩니다. (선택 사항)',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white60,
          ),
        ),
        const SizedBox(height: 30),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 1.2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: _mbtiTypes.length,
            itemBuilder: (context, index) {
              final mbti = _mbtiTypes[index];
              final isSelected = _selectedMbti == mbti;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (_selectedMbti == mbti) {
                      _selectedMbti = null; // 다시 누르면 해제
                    } else {
                      _selectedMbti = mbti;
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? AppTheme.primaryColor 
                        : AppTheme.darkCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected 
                          ? AppTheme.primaryColor 
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      mbti,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : Colors.white70,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInterestsStep() {
    return Column(
      key: const ValueKey('interests'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '관심사를 선택해주세요',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '비슷한 관심사를 가진 사람과 매칭됩니다. (최대 5개)',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white60,
          ),
        ),
        const SizedBox(height: 30),
        Expanded(
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: InterestCategories.categories.map((category) {
                final isSelected = _selectedInterests.contains(category['id']);
                return _buildInterestChip(category, isSelected);
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInterestChip(Map<String, dynamic> category, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedInterests.remove(category['id']);
          } else if (_selectedInterests.length < 5) {
            _selectedInterests.add(category['id']);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : AppTheme.darkCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.transparent,
            width: 2,
          ),
        ),
        child: Text(
          category['name'],
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : Colors.white70,
          ),
        ),
      ),
    );
  }

  Widget _buildButtons() {
    return Row(
      children: [
        if (_currentStep > 0)
          Expanded(
            child: OutlinedButton(
              onPressed: _previousStep,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white38),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('이전'),
            ),
          ),
        if (_currentStep > 0) const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _nextStep,
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(_currentStep == 3 ? '시작하기' : '다음'),
          ),
        ),
      ],
    );
  }
}
