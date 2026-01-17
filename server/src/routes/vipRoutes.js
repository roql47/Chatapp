const express = require('express');
const router = express.Router();
const User = require('../models/User');
const authMiddleware = require('../middleware/auth');

// VIP 티어 정보
const VIP_TIERS = {
  bronze: {
    name: '브론즈',
    price: 5000,      // 포인트
    duration: 30,     // 일
    benefits: [
      '광고 제거',
      '성별 필터 무료 (하루 5회)',
    ],
  },
  silver: {
    name: '실버',
    price: 10000,
    duration: 30,
    benefits: [
      '광고 제거',
      '성별 필터 무료 (하루 10회)',
      'VIP 전용 이모티콘',
      '프로필 테두리 효과',
    ],
  },
  gold: {
    name: '골드',
    price: 20000,
    duration: 30,
    benefits: [
      '광고 제거',
      '성별 필터 무제한 무료',
      'VIP 전용 이모티콘',
      '프로필 테두리 효과',
      '매칭 우선순위 상승',
      '월간 500 포인트 보너스',
    ],
  },
};

// VIP 티어 목록 조회
router.get('/tiers', (req, res) => {
  const tiers = Object.entries(VIP_TIERS).map(([id, info]) => ({
    id,
    ...info,
  }));
  res.json({ tiers });
});

// 내 VIP 상태 조회
router.get('/status', authMiddleware, async (req, res) => {
  try {
    const user = await User.findById(req.userId).select('vip points');
    
    if (!user) {
      return res.status(404).json({ message: '사용자를 찾을 수 없습니다.' });
    }

    // VIP 만료 체크
    if (user.vip.isVip && user.vip.expiresAt && new Date() > user.vip.expiresAt) {
      user.vip.isVip = false;
      user.vip.tier = 'none';
      user.vip.expiresAt = null;
      await user.save();
    }

    const tierInfo = user.vip.tier !== 'none' ? VIP_TIERS[user.vip.tier] : null;

    res.json({
      isVip: user.vip.isVip,
      tier: user.vip.tier,
      tierInfo,
      expiresAt: user.vip.expiresAt,
      daysRemaining: user.vip.expiresAt 
        ? Math.ceil((new Date(user.vip.expiresAt) - new Date()) / (1000 * 60 * 60 * 24))
        : 0,
      points: user.points,
    });
  } catch (error) {
    console.error('VIP 상태 조회 오류:', error);
    res.status(500).json({ message: 'VIP 상태를 가져오는데 실패했습니다.' });
  }
});

// VIP 구매
router.post('/purchase', authMiddleware, async (req, res) => {
  try {
    const { tier } = req.body;

    if (!tier || !VIP_TIERS[tier]) {
      return res.status(400).json({ message: '유효하지 않은 VIP 티어입니다.' });
    }

    const tierInfo = VIP_TIERS[tier];
    const user = await User.findById(req.userId);

    if (!user) {
      return res.status(404).json({ message: '사용자를 찾을 수 없습니다.' });
    }

    // 포인트 확인
    if (user.points < tierInfo.price) {
      return res.status(400).json({
        message: '포인트가 부족합니다.',
        required: tierInfo.price,
        current: user.points,
      });
    }

    // 포인트 차감
    user.points -= tierInfo.price;
    user.pointHistory.push({
      type: 'use',
      amount: -tierInfo.price,
      description: `VIP ${tierInfo.name} 구매`,
    });

    // VIP 설정
    const expiresAt = new Date();
    if (user.vip.isVip && user.vip.expiresAt > new Date()) {
      // 기존 VIP 연장
      expiresAt.setTime(user.vip.expiresAt.getTime());
    }
    expiresAt.setDate(expiresAt.getDate() + tierInfo.duration);

    user.vip.isVip = true;
    user.vip.tier = tier;
    user.vip.expiresAt = expiresAt;

    await user.save();

    res.json({
      message: `VIP ${tierInfo.name}이(가) 활성화되었습니다!`,
      vip: user.vip,
      remainingPoints: user.points,
    });
  } catch (error) {
    console.error('VIP 구매 오류:', error);
    res.status(500).json({ message: 'VIP 구매에 실패했습니다.' });
  }
});

module.exports = router;
