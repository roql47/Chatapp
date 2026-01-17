const express = require('express');
const router = express.Router();
const Report = require('../models/Report');
const User = require('../models/User');
const authMiddleware = require('../middleware/auth');

// 신고 카테고리 목록
const REPORT_CATEGORIES = [
  { id: 'abuse', name: '욕설/비하', icon: '🤬' },
  { id: 'sexual', name: '성희롱/음란', icon: '🔞' },
  { id: 'spam', name: '광고/스팸', icon: '📢' },
  { id: 'scam', name: '사기/피싱', icon: '💰' },
  { id: 'impersonation', name: '사칭', icon: '🎭' },
  { id: 'threat', name: '협박/위협', icon: '⚠️' },
  { id: 'personal_info', name: '개인정보 요구', icon: '🔒' },
  { id: 'other', name: '기타', icon: '📝' },
];

// 신고 카테고리 목록 조회
router.get('/categories', (req, res) => {
  res.json({ categories: REPORT_CATEGORIES });
});

// 신고하기
router.post('/', authMiddleware, async (req, res) => {
  try {
    const { reportedUserId, roomId, category, description, evidence } = req.body;

    if (!reportedUserId || !category) {
      return res.status(400).json({ message: '필수 정보가 누락되었습니다.' });
    }

    // 신고 생성
    const report = await Report.create({
      reporter: req.userId,
      reported: reportedUserId,
      roomId,
      category,
      description,
      evidence: evidence || [],
    });

    // 신고 당한 유저의 신고 횟수 증가
    const reportedUser = await User.findByIdAndUpdate(
      reportedUserId,
      { $inc: { 'sanctions.reportedCount': 1 } },
      { new: true }
    );

    // 자동 제재 로직: 신고 5회 이상이면 자동 경고
    if (reportedUser && reportedUser.sanctions.reportedCount >= 5) {
      const warningThreshold = Math.floor(reportedUser.sanctions.reportedCount / 5);
      
      if (reportedUser.sanctions.warningCount < warningThreshold) {
        reportedUser.sanctions.warningCount = warningThreshold;
        
        // 경고 3회 이상이면 1일 정지
        if (reportedUser.sanctions.warningCount >= 3 && !reportedUser.sanctions.isSuspended) {
          reportedUser.sanctions.isSuspended = true;
          reportedUser.sanctions.suspendedUntil = new Date(Date.now() + 24 * 60 * 60 * 1000);
        }
        
        // 경고 5회 이상이면 영구 정지
        if (reportedUser.sanctions.warningCount >= 5) {
          reportedUser.sanctions.isBanned = true;
          reportedUser.sanctions.bannedAt = new Date();
        }
        
        await reportedUser.save();
      }
    }

    res.status(201).json({
      message: '신고가 접수되었습니다. 검토 후 조치하겠습니다.',
      report,
    });
  } catch (error) {
    console.error('신고 오류:', error);
    res.status(500).json({ message: '신고에 실패했습니다.' });
  }
});

// 내 신고 목록 조회
router.get('/my', authMiddleware, async (req, res) => {
  try {
    const reports = await Report.find({ reporter: req.userId })
      .populate('reported', 'nickname profileImage')
      .sort({ createdAt: -1 });

    res.json({ reports });
  } catch (error) {
    console.error('신고 목록 조회 오류:', error);
    res.status(500).json({ message: '신고 목록을 가져오는데 실패했습니다.' });
  }
});

// 신고 상세 조회
router.get('/:reportId', authMiddleware, async (req, res) => {
  try {
    const report = await Report.findOne({
      _id: req.params.reportId,
      reporter: req.userId,
    })
      .populate('reported', 'nickname profileImage')
      .populate('roomId');

    if (!report) {
      return res.status(404).json({ message: '신고를 찾을 수 없습니다.' });
    }

    res.json({ report });
  } catch (error) {
    console.error('신고 상세 조회 오류:', error);
    res.status(500).json({ message: '신고 정보를 가져오는데 실패했습니다.' });
  }
});

module.exports = router;
