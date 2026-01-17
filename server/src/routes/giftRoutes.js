const express = require('express');
const router = express.Router();
const Gift = require('../models/Gift');
const User = require('../models/User');
const authMiddleware = require('../middleware/auth');

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

    // 받는 사람 통계 업데이트
    receiver.giftStats.totalReceived += 1;
    receiver.pointHistory.push({
      type: 'gift_received',
      amount: 0, // 포인트는 받지 않음 (추후 정책에 따라 변경 가능)
      description: `${sender.nickname}님에게 ${giftInfo.name} 받음`,
    });
    await receiver.save();

    res.status(201).json({
      message: `${giftInfo.name}을(를) 선물했습니다!`,
      gift: {
        ...gift.toObject(),
        giftInfo,
      },
      remainingPoints: sender.points,
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

module.exports = router;
