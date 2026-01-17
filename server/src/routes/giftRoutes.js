const express = require('express');
const router = express.Router();
const Gift = require('../models/Gift');
const User = require('../models/User');
const authMiddleware = require('../middleware/auth');

// 배지 등급 정의 (icon: Material Design Icon 이름)
const GIFT_BADGES = [
  { minGifts: 0, badge: 'none', name: '없음', icon: '', color: 0xFF9E9E9E },
  { minGifts: 1, badge: 'newcomer', name: '새싹', icon: 'eco', color: 0xFF4CAF50 },
  { minGifts: 5, badge: 'bronze', name: '브론즈', icon: 'military_tech', color: 0xFFCD7F32 },
  { minGifts: 15, badge: 'silver', name: '실버', icon: 'military_tech', color: 0xFFC0C0C0 },
  { minGifts: 30, badge: 'gold', name: '골드', icon: 'military_tech', color: 0xFFFFD700 },
  { minGifts: 50, badge: 'platinum', name: '플래티넘', icon: 'diamond', color: 0xFF00BCD4 },
  { minGifts: 100, badge: 'diamond', name: '다이아몬드', icon: 'workspace_premium', color: 0xFFE040FB },
  { minGifts: 200, badge: 'master', name: '마스터', icon: 'auto_awesome', color: 0xFFFF9800 },
  { minGifts: 500, badge: 'legend', name: '레전드', icon: 'local_fire_department', color: 0xFFF44336 },
];

// 받은 선물 수에 따른 배지 결정
function getGiftBadge(totalReceived) {
  let badge = GIFT_BADGES[0];
  for (const b of GIFT_BADGES) {
    if (totalReceived >= b.minGifts) {
      badge = b;
    }
  }
  return badge;
}

// 선물 종류 목록 조회
router.get('/types', (req, res) => {
  const giftTypes = Gift.getGiftTypes();
  const types = Object.entries(giftTypes).map(([id, info]) => ({
    id,
    ...info,
  }));
  res.json({ types });
});

// 선물 보내기
router.post('/send', authMiddleware, async (req, res) => {
  try {
    const { receiverId, giftType, message, roomId } = req.body;

    if (!receiverId || !giftType) {
      return res.status(400).json({ message: '필수 정보가 누락되었습니다.' });
    }

    // 자기 자신에게 선물 불가
    if (req.userId === receiverId) {
      return res.status(400).json({ message: '자기 자신에게는 선물할 수 없습니다.' });
    }

    // 선물 정보 확인
    const giftInfo = Gift.getGiftInfo(giftType);
    if (!giftInfo) {
      return res.status(400).json({ message: '유효하지 않은 선물 종류입니다.' });
    }

    // 보내는 사람 포인트 확인
    const sender = await User.findById(req.userId);
    if (!sender) {
      return res.status(404).json({ message: '사용자를 찾을 수 없습니다.' });
    }

    if (sender.points < giftInfo.price) {
      return res.status(400).json({ 
        message: '포인트가 부족합니다.',
        required: giftInfo.price,
        current: sender.points,
      });
    }

    // 받는 사람 확인
    const receiver = await User.findById(receiverId);
    if (!receiver) {
      return res.status(404).json({ message: '받는 사람을 찾을 수 없습니다.' });
    }

    // 선물 생성
    const gift = await Gift.create({
      sender: req.userId,
      receiver: receiverId,
      giftType,
      price: giftInfo.price,
      message: message || '',
      roomId,
    });

    // 포인트 차감 및 기록
    sender.points -= giftInfo.price;
    sender.pointHistory.push({
      type: 'gift_sent',
      amount: -giftInfo.price,
      description: `${receiver.nickname}님에게 ${giftInfo.name} 선물`,
    });
    sender.giftStats.totalSent += 1;
    await sender.save();

    // 받는 사람에게 선물 가격의 50% 포인트 지급
    const rewardPoints = Math.floor(giftInfo.price * 0.5);
    receiver.points += rewardPoints;
    receiver.giftStats.totalReceived += 1;
    receiver.giftStats.totalPointsEarned = (receiver.giftStats.totalPointsEarned || 0) + rewardPoints;
    receiver.pointHistory.push({
      type: 'gift_received',
      amount: rewardPoints,
      description: `${sender.nickname}님에게 ${giftInfo.name} 받음 (+${rewardPoints}P)`,
    });
    
    // 배지 업데이트
    receiver.giftStats.badge = getGiftBadge(receiver.giftStats.totalReceived);
    
    await receiver.save();

    // 채팅방에 선물 애니메이션 이벤트 전송
    if (roomId) {
      const io = req.app.get('io');
      if (io) {
        io.to(roomId).emit('gift_received', {
          senderId: req.userId,
          senderNickname: sender.nickname,
          receiverId,
          receiverNickname: receiver.nickname,
          giftType,
          giftInfo,
          rewardPoints,
          badge: receiver.giftStats.badge,
        });
        console.log(`🎁 선물 이벤트 전송: ${roomId}`);
      }
    }

    res.status(201).json({
      message: `${giftInfo.name}을(를) 선물했습니다!`,
      gift: {
        ...gift.toObject(),
        giftInfo,
      },
      remainingPoints: sender.points,
      receiverReward: rewardPoints,
      receiverBadge: receiver.giftStats.badge,
    });
  } catch (error) {
    console.error('선물 보내기 오류:', error);
    res.status(500).json({ message: '선물 보내기에 실패했습니다.' });
  }
});

// 받은 선물 목록
router.get('/received', authMiddleware, async (req, res) => {
  try {
    const gifts = await Gift.find({ receiver: req.userId })
      .populate('sender', 'nickname profileImage')
      .sort({ createdAt: -1 })
      .limit(50);

    const giftsWithInfo = gifts.map(gift => ({
      ...gift.toObject(),
      giftInfo: Gift.getGiftInfo(gift.giftType),
    }));

    res.json({ gifts: giftsWithInfo });
  } catch (error) {
    console.error('받은 선물 조회 오류:', error);
    res.status(500).json({ message: '선물 목록을 가져오는데 실패했습니다.' });
  }
});

// 보낸 선물 목록
router.get('/sent', authMiddleware, async (req, res) => {
  try {
    const gifts = await Gift.find({ sender: req.userId })
      .populate('receiver', 'nickname profileImage')
      .sort({ createdAt: -1 })
      .limit(50);

    const giftsWithInfo = gifts.map(gift => ({
      ...gift.toObject(),
      giftInfo: Gift.getGiftInfo(gift.giftType),
    }));

    res.json({ gifts: giftsWithInfo });
  } catch (error) {
    console.error('보낸 선물 조회 오류:', error);
    res.status(500).json({ message: '선물 목록을 가져오는데 실패했습니다.' });
  }
});

// 배지 등급 목록 조회
router.get('/badges', (req, res) => {
  res.json({ badges: GIFT_BADGES });
});

// 인기 유저 랭킹 (많이 받은 사람)
router.get('/ranking', async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 20;
    
    const topUsers = await User.find({
      'giftStats.totalReceived': { $gt: 0 }
    })
      .select('nickname profileImage giftStats.totalReceived giftStats.badge giftStats.totalPointsEarned')
      .sort({ 'giftStats.totalReceived': -1 })
      .limit(limit);
    
    const ranking = topUsers.map((user, index) => ({
      rank: index + 1,
      userId: user._id,
      nickname: user.nickname,
      profileImage: user.profileImage,
      totalReceived: user.giftStats?.totalReceived || 0,
      totalPointsEarned: user.giftStats?.totalPointsEarned || 0,
      badge: user.giftStats?.badge || getGiftBadge(0),
    }));
    
    res.json({ ranking });
  } catch (error) {
    console.error('랭킹 조회 오류:', error);
    res.status(500).json({ message: '랭킹을 가져오는데 실패했습니다.' });
  }
});

// 내 선물 통계
router.get('/my-stats', authMiddleware, async (req, res) => {
  try {
    const user = await User.findById(req.userId)
      .select('giftStats');
    
    if (!user) {
      return res.status(404).json({ message: '사용자를 찾을 수 없습니다.' });
    }
    
    const stats = {
      totalSent: user.giftStats?.totalSent || 0,
      totalReceived: user.giftStats?.totalReceived || 0,
      totalPointsEarned: user.giftStats?.totalPointsEarned || 0,
      badge: user.giftStats?.badge || getGiftBadge(0),
      nextBadge: getNextBadge(user.giftStats?.totalReceived || 0),
    };
    
    res.json({ stats });
  } catch (error) {
    console.error('내 선물 통계 조회 오류:', error);
    res.status(500).json({ message: '통계를 가져오는데 실패했습니다.' });
  }
});

// 다음 배지 정보 가져오기
function getNextBadge(totalReceived) {
  for (const badge of GIFT_BADGES) {
    if (totalReceived < badge.minGifts) {
      return {
        ...badge,
        giftsNeeded: badge.minGifts - totalReceived,
      };
    }
  }
  return null; // 최고 등급 달성
}

module.exports = router;
