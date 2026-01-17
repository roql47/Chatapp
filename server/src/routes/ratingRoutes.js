const express = require('express');
const router = express.Router();
const Rating = require('../models/Rating');
const User = require('../models/User');
const authMiddleware = require('../middleware/auth');

// 평가 태그 목록
const RATING_TAGS = [
  { id: 'friendly', name: '친절해요', emoji: '😊' },
  { id: 'funny', name: '유머있어요', emoji: '😂' },
  { id: 'interesting', name: '대화가 재미있어요', emoji: '💬' },
  { id: 'respectful', name: '예의바르다', emoji: '🎩' },
  { id: 'goodListener', name: '경청을 잘해요', emoji: '👂' },
];

// 태그 목록 조회
router.get('/tags', (req, res) => {
  res.json({ tags: RATING_TAGS });
});

// 평가하기
router.post('/', authMiddleware, async (req, res) => {
  try {
    const { ratedUserId, roomId, score, tags, comment } = req.body;

    if (!ratedUserId || !roomId || !score) {
      return res.status(400).json({ message: '필수 정보가 누락되었습니다.' });
    }

    if (score < 1 || score > 5) {
      return res.status(400).json({ message: '평점은 1~5 사이여야 합니다.' });
    }

    // 자기 자신 평가 불가
    if (req.userId === ratedUserId) {
      return res.status(400).json({ message: '자기 자신은 평가할 수 없습니다.' });
    }

    // 이미 평가했는지 확인
    const existingRating = await Rating.findOne({
      rater: req.userId,
      rated: ratedUserId,
      roomId,
    });

    if (existingRating) {
      return res.status(400).json({ message: '이미 평가했습니다.' });
    }

    // 평가 생성
    const rating = await Rating.create({
      rater: req.userId,
      rated: ratedUserId,
      roomId,
      score,
      tags: tags || {},
      comment: comment || '',
    });

    // 평가받은 유저의 평균 점수 및 태그 업데이트
    const ratedUser = await User.findById(ratedUserId);
    if (ratedUser) {
      const totalRatings = ratedUser.rating.totalRatings + 1;
      const currentTotal = ratedUser.rating.averageScore * ratedUser.rating.totalRatings;
      const newAverage = (currentTotal + score) / totalRatings;

      const updateTags = {};
      if (tags) {
        Object.keys(tags).forEach(tag => {
          if (tags[tag] && RATING_TAGS.some(t => t.id === tag)) {
            updateTags[`rating.tags.${tag}`] = 1;
          }
        });
      }

      await User.findByIdAndUpdate(ratedUserId, {
        $set: {
          'rating.averageScore': Math.round(newAverage * 10) / 10,
          'rating.totalRatings': totalRatings,
        },
        $inc: updateTags,
      });
    }

    res.status(201).json({
      message: '평가가 완료되었습니다.',
      rating,
    });
  } catch (error) {
    console.error('평가 오류:', error);
    res.status(500).json({ message: '평가에 실패했습니다.' });
  }
});

// 내가 받은 평가 조회
router.get('/received', authMiddleware, async (req, res) => {
  try {
    const ratings = await Rating.find({ rated: req.userId })
      .populate('rater', 'nickname profileImage')
      .sort({ createdAt: -1 })
      .limit(50);

    // 내 평균 점수 및 태그 통계
    const user = await User.findById(req.userId);
    const stats = user ? user.rating : null;

    res.json({ ratings, stats });
  } catch (error) {
    console.error('받은 평가 조회 오류:', error);
    res.status(500).json({ message: '평가 목록을 가져오는데 실패했습니다.' });
  }
});

// 특정 유저 평가 정보 조회
router.get('/user/:userId', authMiddleware, async (req, res) => {
  try {
    const user = await User.findById(req.params.userId).select('rating nickname');
    
    if (!user) {
      return res.status(404).json({ message: '사용자를 찾을 수 없습니다.' });
    }

    res.json({
      nickname: user.nickname,
      rating: user.rating,
    });
  } catch (error) {
    console.error('유저 평가 조회 오류:', error);
    res.status(500).json({ message: '평가 정보를 가져오는데 실패했습니다.' });
  }
});

module.exports = router;
