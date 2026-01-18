const express = require('express');
const router = express.Router();
const authService = require('../services/authService');
const authMiddleware = require('../middleware/auth');

// 카카오 로그인
router.post('/kakao', async (req, res) => {
  try {
    const { kakaoId, nickname, profileImage, accessToken } = req.body;

    if (!kakaoId) {
      return res.status(400).json({ message: '카카오 ID가 필요합니다.' });
    }

    const result = await authService.loginWithKakao(
      kakaoId,
      nickname,
      profileImage,
      accessToken
    );

    res.json({
      message: '로그인 성공',
      user: result.user,
      token: result.token,
    });
  } catch (error) {
    console.error('카카오 로그인 오류:', error);
    res.status(500).json({ message: '로그인에 실패했습니다.' });
  }
});

// 현재 사용자 정보 조회
router.get('/me', authMiddleware, async (req, res) => {
  try {
    const user = await authService.getUserById(req.userId);
    
    if (!user) {
      return res.status(404).json({ message: '사용자를 찾을 수 없습니다.' });
    }

    res.json({ user });
  } catch (error) {
    console.error('사용자 정보 조회 오류:', error);
    res.status(500).json({ message: '사용자 정보를 가져오는데 실패했습니다.' });
  }
});

// 프로필 업데이트
router.put('/profile', authMiddleware, async (req, res) => {
  try {
    const { nickname, gender, interests, profileImage } = req.body;

    const user = await authService.updateProfile(req.userId, {
      nickname,
      gender,
      interests,
      profileImage,
    });

    if (!user) {
      return res.status(404).json({ message: '사용자를 찾을 수 없습니다.' });
    }

    res.json({
      message: '프로필이 업데이트되었습니다.',
      user,
    });
  } catch (error) {
    console.error('프로필 업데이트 오류:', error);
    res.status(500).json({ message: '프로필 업데이트에 실패했습니다.' });
  }
});

// 차단하기
router.post('/block/:userId', authMiddleware, async (req, res) => {
  try {
    const blockedUserId = req.params.userId;
    
    const success = await authService.blockUser(req.userId, blockedUserId);
    
    if (success) {
      res.json({ message: '차단되었습니다.' });
    } else {
      res.status(400).json({ message: '차단에 실패했습니다.' });
    }
  } catch (error) {
    console.error('차단 오류:', error);
    res.status(500).json({ message: '차단에 실패했습니다.' });
  }
});

// 차단 해제
router.delete('/block/:userId', authMiddleware, async (req, res) => {
  try {
    const blockedUserId = req.params.userId;
    
    const success = await authService.unblockUser(req.userId, blockedUserId);
    
    if (success) {
      res.json({ message: '차단이 해제되었습니다.' });
    } else {
      res.status(400).json({ message: '차단 해제에 실패했습니다.' });
    }
  } catch (error) {
    console.error('차단 해제 오류:', error);
    res.status(500).json({ message: '차단 해제에 실패했습니다.' });
  }
});

// 차단 목록 조회
router.get('/blocked', authMiddleware, async (req, res) => {
  try {
    const blockedUsers = await authService.getBlockedUsers(req.userId);
    res.json({ blockedUsers });
  } catch (error) {
    console.error('차단 목록 조회 오류:', error);
    res.status(500).json({ message: '차단 목록을 가져오는데 실패했습니다.' });
  }
});

// 계정 삭제
router.delete('/account', authMiddleware, async (req, res) => {
  try {
    const success = await authService.deleteAccount(req.userId);
    
    if (success) {
      res.json({ message: '계정이 삭제되었습니다.' });
    } else {
      res.status(400).json({ message: '계정 삭제에 실패했습니다.' });
    }
  } catch (error) {
    console.error('계정 삭제 오류:', error);
    res.status(500).json({ message: '계정 삭제에 실패했습니다.' });
  }
});

// ============================================
// 포인트 관련 API
// ============================================

// 포인트 조회
router.get('/points', authMiddleware, async (req, res) => {
  try {
    const user = await authService.getUserById(req.userId);
    if (!user) {
      return res.status(404).json({ message: '사용자를 찾을 수 없습니다.' });
    }
    
    res.json({
      points: user.points,
      history: user.pointHistory?.slice(-20) || [], // 최근 20개
    });
  } catch (error) {
    console.error('포인트 조회 오류:', error);
    res.status(500).json({ message: '포인트 조회에 실패했습니다.' });
  }
});

// 포인트 사용 (매칭 등)
router.post('/points/use', authMiddleware, async (req, res) => {
  try {
    const { amount, description } = req.body;
    
    if (!amount || amount <= 0) {
      return res.status(400).json({ message: '올바른 포인트 수량이 필요합니다.' });
    }
    
    const result = await authService.usePoints(req.userId, amount, description || '포인트 사용');
    
    if (result.success) {
      res.json({
        message: '포인트가 사용되었습니다.',
        points: result.points,
      });
    } else {
      res.status(400).json({ message: result.message || '포인트 사용에 실패했습니다.' });
    }
  } catch (error) {
    console.error('포인트 사용 오류:', error);
    res.status(500).json({ message: '포인트 사용에 실패했습니다.' });
  }
});

// 포인트 충전 (인앱결제 검증 후)
router.post('/points/charge', authMiddleware, async (req, res) => {
  try {
    const { amount, purchaseToken, productId, platform } = req.body;
    
    if (!amount || amount <= 0) {
      return res.status(400).json({ message: '올바른 포인트 수량이 필요합니다.' });
    }
    
    // TODO: 실제 결제 검증 로직 추가
    // Google Play / Apple 결제 검증 API 호출
    // 여기서는 테스트용으로 바로 충전
    
    const result = await authService.chargePoints(
      req.userId, 
      amount, 
      `포인트 충전 (${productId || '직접충전'})`
    );
    
    if (result.success) {
      res.json({
        message: '포인트가 충전되었습니다.',
        points: result.points,
      });
    } else {
      res.status(400).json({ message: '포인트 충전에 실패했습니다.' });
    }
  } catch (error) {
    console.error('포인트 충전 오류:', error);
    res.status(500).json({ message: '포인트 충전에 실패했습니다.' });
  }
});

// 포인트 확인 (충분한지 체크)
router.post('/points/check', authMiddleware, async (req, res) => {
  try {
    const { amount } = req.body;
    
    const user = await authService.getUserById(req.userId);
    if (!user) {
      return res.status(404).json({ message: '사용자를 찾을 수 없습니다.' });
    }
    
    const hasEnough = user.points >= amount;
    
    res.json({
      hasEnough,
      currentPoints: user.points,
      requiredPoints: amount,
    });
  } catch (error) {
    console.error('포인트 확인 오류:', error);
    res.status(500).json({ message: '포인트 확인에 실패했습니다.' });
  }
});

// ============================================
// 위치 관련 API
// ============================================

// 위치 업데이트
router.put('/location', authMiddleware, async (req, res) => {
  try {
    const { latitude, longitude, enabled } = req.body;
    
    const user = await authService.getUserById(req.userId);
    if (!user) {
      return res.status(404).json({ message: '사용자를 찾을 수 없습니다.' });
    }
    
    user.location = {
      enabled: enabled !== undefined ? enabled : true,
      latitude: latitude || null,
      longitude: longitude || null,
      updatedAt: new Date(),
    };
    
    await user.save();
    
    res.json({
      message: '위치가 업데이트되었습니다.',
      location: user.location,
    });
  } catch (error) {
    console.error('위치 업데이트 오류:', error);
    res.status(500).json({ message: '위치 업데이트에 실패했습니다.' });
  }
});

// 위치 공유 설정 토글
router.put('/location/toggle', authMiddleware, async (req, res) => {
  try {
    const { enabled } = req.body;
    
    const user = await authService.getUserById(req.userId);
    if (!user) {
      return res.status(404).json({ message: '사용자를 찾을 수 없습니다.' });
    }
    
    if (!user.location) {
      user.location = {};
    }
    
    user.location.enabled = enabled;
    if (!enabled) {
      user.location.latitude = null;
      user.location.longitude = null;
    }
    user.location.updatedAt = new Date();
    
    await user.save();
    
    res.json({
      message: enabled ? '위치 공유가 활성화되었습니다.' : '위치 공유가 비활성화되었습니다.',
      enabled: user.location.enabled,
    });
  } catch (error) {
    console.error('위치 설정 오류:', error);
    res.status(500).json({ message: '위치 설정에 실패했습니다.' });
  }
});

// ============================================
// 테스트용 API (개발 환경에서만 사용)
// ============================================

// 테스트 계정 생성 (터미널 테스트 클라이언트용)
router.post('/test/create', async (req, res) => {
  try {
    const { nickname, gender, interests } = req.body;
    
    // 테스트 계정 ID 생성
    const testId = `test_user_${Date.now()}`;
    const testNickname = nickname || `테스트유저_${Math.floor(Math.random() * 1000)}`;
    
    // 랜덤 프로필 사진 URL 생성 (ui-avatars.com 사용)
    const profileImage = `https://ui-avatars.com/api/?name=${encodeURIComponent(testNickname)}&background=random&color=fff&size=200`;
    
    const result = await authService.loginWithKakao(
      testId,
      testNickname,
      profileImage,
      'test_access_token'
    );
    
    // 프로필 설정
    if (gender || interests) {
      await authService.updateProfile(result.user._id, {
        gender: gender || 'other',
        interests: interests || ['테스트', '개발'],
      });
    }
    
    // 업데이트된 유저 정보 다시 가져오기
    const updatedUser = await authService.getUserById(result.user._id);
    
    res.json({
      message: '테스트 계정 생성 완료',
      user: updatedUser,
      token: result.token,
      userId: updatedUser._id.toString(),
    });
  } catch (error) {
    console.error('테스트 계정 생성 오류:', error);
    res.status(500).json({ message: '테스트 계정 생성에 실패했습니다.' });
  }
});

// ============================================
// 성인인증 API
// ============================================

// 성인인증 상태 확인
router.get('/adult-verification/status', authMiddleware, async (req, res) => {
  try {
    const user = await authService.getUserById(req.userId);
    if (!user) {
      return res.status(404).json({ message: '사용자를 찾을 수 없습니다.' });
    }
    
    res.json({
      isVerified: user.adultVerification?.isVerified || false,
      verifiedAt: user.adultVerification?.verifiedAt,
    });
  } catch (error) {
    console.error('성인인증 상태 확인 오류:', error);
    res.status(500).json({ message: '성인인증 상태 확인에 실패했습니다.' });
  }
});

// 카카오 인증으로 성인인증 처리
router.post('/adult-verification/kakao', authMiddleware, async (req, res) => {
  try {
    const { birthYear, ci } = req.body;
    
    if (!birthYear) {
      return res.status(400).json({ message: '생년 정보가 필요합니다.' });
    }
    
    // 만 19세 이상인지 확인
    const currentYear = new Date().getFullYear();
    const age = currentYear - birthYear;
    
    if (age < 19) {
      return res.status(403).json({ 
        message: '만 19세 이상만 이용 가능합니다.',
        age: age,
      });
    }
    
    // CI로 중복 인증 확인 (선택적)
    if (ci) {
      const User = require('../models/User');
      const existingUser = await User.findOne({ 
        'adultVerification.ci': ci,
        _id: { $ne: req.userId }
      });
      
      if (existingUser) {
        return res.status(409).json({ 
          message: '이미 다른 계정에서 인증된 정보입니다.' 
        });
      }
    }
    
    // 성인인증 정보 업데이트
    const User = require('../models/User');
    const user = await User.findByIdAndUpdate(
      req.userId,
      {
        'adultVerification.isVerified': true,
        'adultVerification.verifiedAt': new Date(),
        'adultVerification.birthYear': birthYear,
        'adultVerification.ci': ci || null,
      },
      { new: true }
    );
    
    res.json({
      message: '성인인증이 완료되었습니다.',
      isVerified: true,
      verifiedAt: user.adultVerification.verifiedAt,
    });
  } catch (error) {
    console.error('성인인증 처리 오류:', error);
    res.status(500).json({ message: '성인인증 처리에 실패했습니다.' });
  }
});

// Firebase Phone Auth 기반 성인인증 처리
router.post('/adult-verification/firebase', authMiddleware, async (req, res) => {
  try {
    const { phone, birthYear, firebaseUid } = req.body;
    
    if (!phone || !birthYear) {
      return res.status(400).json({ message: '전화번호와 생년 정보가 필요합니다.' });
    }
    
    // 만 19세 이상인지 확인
    const currentYear = new Date().getFullYear();
    const age = currentYear - birthYear;
    
    if (age < 19) {
      return res.status(403).json({ 
        message: '만 19세 이상만 이용 가능합니다.',
        age: age,
      });
    }
    
    // 동일 전화번호로 다른 계정 인증 확인
    const User = require('../models/User');
    const existingUser = await User.findOne({ 
      'adultVerification.phone': phone,
      _id: { $ne: req.userId }
    });
    
    if (existingUser) {
      return res.status(409).json({ 
        message: '이미 다른 계정에서 인증된 전화번호입니다.' 
      });
    }
    
    // 성인인증 정보 업데이트
    const user = await User.findByIdAndUpdate(
      req.userId,
      {
        'adultVerification.isVerified': true,
        'adultVerification.verifiedAt': new Date(),
        'adultVerification.birthYear': birthYear,
        'adultVerification.phone': phone,
        'adultVerification.firebaseUid': firebaseUid || null,
      },
      { new: true }
    );
    
    res.json({
      message: '성인인증이 완료되었습니다.',
      isVerified: true,
      verifiedAt: user.adultVerification.verifiedAt,
    });
  } catch (error) {
    console.error('Firebase 성인인증 처리 오류:', error);
    res.status(500).json({ message: '성인인증 처리에 실패했습니다.' });
  }
});

// 성인인증 우회 (테스트용 - 프로덕션에서는 비활성화)
router.post('/adult-verification/bypass', authMiddleware, async (req, res) => {
  try {
    // 테스트 환경에서만 허용
    if (process.env.NODE_ENV === 'production') {
      return res.status(403).json({ message: '프로덕션 환경에서는 사용할 수 없습니다.' });
    }
    
    const User = require('../models/User');
    const user = await User.findByIdAndUpdate(
      req.userId,
      {
        'adultVerification.isVerified': true,
        'adultVerification.verifiedAt': new Date(),
        'adultVerification.birthYear': 1990, // 테스트용
      },
      { new: true }
    );
    
    res.json({
      message: '테스트 성인인증이 완료되었습니다.',
      isVerified: true,
    });
  } catch (error) {
    console.error('테스트 성인인증 오류:', error);
    res.status(500).json({ message: '테스트 성인인증에 실패했습니다.' });
  }
});

// ============================================
// 출석체크 API
// ============================================

// 출석체크 보상 (일~토: 1~7일차)
const ATTENDANCE_REWARDS = [30, 30, 50, 30, 30, 30, 100];

// 출석체크 상태 조회
router.get('/attendance', authMiddleware, async (req, res) => {
  try {
    const User = require('../models/User');
    const user = await User.findById(req.userId);
    
    if (!user) {
      return res.status(404).json({ message: '사용자를 찾을 수 없습니다.' });
    }
    
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    
    // 오늘 이미 출석했는지 확인
    let checkedInToday = false;
    if (user.attendance?.lastCheckIn) {
      const lastCheckIn = new Date(user.attendance.lastCheckIn);
      const lastCheckInDate = new Date(lastCheckIn.getFullYear(), lastCheckIn.getMonth(), lastCheckIn.getDate());
      checkedInToday = lastCheckInDate.getTime() === today.getTime();
    }
    
    // 현재 연속 출석일 (0-6 인덱스, 표시는 1-7일차)
    let currentStreak = user.attendance?.currentStreak || 0;
    
    // 어제 출석하지 않았으면 스트릭 리셋 (오늘 첫 출석 전 확인)
    if (!checkedInToday && user.attendance?.lastCheckIn) {
      const lastCheckIn = new Date(user.attendance.lastCheckIn);
      const yesterday = new Date(today);
      yesterday.setDate(yesterday.getDate() - 1);
      const lastCheckInDate = new Date(lastCheckIn.getFullYear(), lastCheckIn.getMonth(), lastCheckIn.getDate());
      
      if (lastCheckInDate.getTime() < yesterday.getTime()) {
        currentStreak = 0; // 연속 출석 끊김
      }
    }
    
    res.json({
      currentStreak: currentStreak,
      checkedInToday: checkedInToday,
      rewards: ATTENDANCE_REWARDS,
      todayReward: currentStreak < 7 ? ATTENDANCE_REWARDS[currentStreak] : ATTENDANCE_REWARDS[0],
    });
  } catch (error) {
    console.error('출석체크 상태 조회 오류:', error);
    res.status(500).json({ message: '출석체크 상태 조회에 실패했습니다.' });
  }
});

// 출석체크 수행
router.post('/attendance/check-in', authMiddleware, async (req, res) => {
  try {
    const User = require('../models/User');
    const user = await User.findById(req.userId);
    
    if (!user) {
      return res.status(404).json({ message: '사용자를 찾을 수 없습니다.' });
    }
    
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    
    // 오늘 이미 출석했는지 확인
    if (user.attendance?.lastCheckIn) {
      const lastCheckIn = new Date(user.attendance.lastCheckIn);
      const lastCheckInDate = new Date(lastCheckIn.getFullYear(), lastCheckIn.getMonth(), lastCheckIn.getDate());
      
      if (lastCheckInDate.getTime() === today.getTime()) {
        return res.status(400).json({ message: '오늘 이미 출석체크를 완료했습니다.' });
      }
    }
    
    // 현재 스트릭 계산
    let currentStreak = user.attendance?.currentStreak || 0;
    
    // 어제 출석했는지 확인 (연속 출석 여부)
    if (user.attendance?.lastCheckIn) {
      const lastCheckIn = new Date(user.attendance.lastCheckIn);
      const yesterday = new Date(today);
      yesterday.setDate(yesterday.getDate() - 1);
      const lastCheckInDate = new Date(lastCheckIn.getFullYear(), lastCheckIn.getMonth(), lastCheckIn.getDate());
      
      if (lastCheckInDate.getTime() === yesterday.getTime()) {
        // 연속 출석
        currentStreak = (currentStreak % 7) + 1; // 1-7 순환
      } else {
        // 연속 출석 끊김, 1일차부터 시작
        currentStreak = 1;
      }
    } else {
      // 첫 출석
      currentStreak = 1;
    }
    
    // 보상 포인트 계산 (인덱스는 0-6)
    const rewardIndex = currentStreak - 1;
    const rewardPoints = ATTENDANCE_REWARDS[rewardIndex];
    
    // 포인트 지급 및 출석 정보 업데이트
    user.points += rewardPoints;
    user.pointHistory.push({
      type: 'bonus',
      amount: rewardPoints,
      description: `출석체크 ${currentStreak}일차 보상`,
      createdAt: now,
    });
    
    user.attendance = {
      lastCheckIn: now,
      currentStreak: currentStreak,
      weekStartDate: currentStreak === 1 ? today : (user.attendance?.weekStartDate || today),
    };
    
    await user.save();
    
    res.json({
      message: `출석체크 완료! ${rewardPoints}P 획득!`,
      currentStreak: currentStreak,
      rewardPoints: rewardPoints,
      totalPoints: user.points,
      isWeekComplete: currentStreak === 7,
    });
  } catch (error) {
    console.error('출석체크 오류:', error);
    res.status(500).json({ message: '출석체크에 실패했습니다.' });
  }
});

// ===== 광고 제거 API =====

// 광고 제거 상태 조회
router.get('/ad-removal', authMiddleware, async (req, res) => {
  try {
    const user = await User.findById(req.userId);
    if (!user) {
      return res.status(404).json({ message: '사용자를 찾을 수 없습니다.' });
    }
    
    res.json({
      adRemoved: user.adRemoved || false,
      adRemovedAt: user.adRemovedAt,
    });
  } catch (error) {
    console.error('광고 제거 상태 조회 오류:', error);
    res.status(500).json({ message: '광고 제거 상태를 가져오는데 실패했습니다.' });
  }
});

// 광고 제거 설정 (인앱결제 완료 후 호출)
router.post('/ad-removal', authMiddleware, async (req, res) => {
  try {
    const { purchaseToken, productId } = req.body;
    
    // TODO: Google Play / App Store에서 purchaseToken 검증
    // 실제 배포 시 서버 사이드 영수증 검증 필수!
    
    const user = await User.findById(req.userId);
    if (!user) {
      return res.status(404).json({ message: '사용자를 찾을 수 없습니다.' });
    }
    
    // 이미 광고 제거됨
    if (user.adRemoved) {
      return res.json({
        message: '이미 광고가 제거되어 있습니다.',
        adRemoved: true,
        adRemovedAt: user.adRemovedAt,
      });
    }
    
    // 광고 제거 설정
    user.adRemoved = true;
    user.adRemovedAt = new Date();
    await user.save();
    
    console.log(`🟢 광고 제거 완료: ${user.nickname} (${req.userId})`);
    
    res.json({
      message: '광고가 제거되었습니다!',
      adRemoved: true,
      adRemovedAt: user.adRemovedAt,
    });
  } catch (error) {
    console.error('광고 제거 설정 오류:', error);
    res.status(500).json({ message: '광고 제거에 실패했습니다.' });
  }
});

// 광고 제거 복원 (재설치 시 호출)
router.post('/ad-removal/restore', authMiddleware, async (req, res) => {
  try {
    const user = await User.findById(req.userId);
    if (!user) {
      return res.status(404).json({ message: '사용자를 찾을 수 없습니다.' });
    }
    
    res.json({
      message: user.adRemoved ? '광고 제거가 복원되었습니다!' : '복원할 구매 내역이 없습니다.',
      adRemoved: user.adRemoved || false,
      adRemovedAt: user.adRemovedAt,
    });
  } catch (error) {
    console.error('광고 제거 복원 오류:', error);
    res.status(500).json({ message: '광고 제거 복원에 실패했습니다.' });
  }
});

module.exports = router;
