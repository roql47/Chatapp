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

module.exports = router;
