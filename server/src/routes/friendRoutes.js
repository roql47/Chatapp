const express = require('express');
const router = express.Router();
const Friend = require('../models/Friend');
const User = require('../models/User');
const authMiddleware = require('../middleware/auth');

// 친구 요청 보내기
router.post('/request/:userId', authMiddleware, async (req, res) => {
  try {
    const { userId } = req.params;
    const requesterId = req.userId;

    // 자기 자신에게 요청 불가
    if (requesterId === userId) {
      return res.status(400).json({ message: '자기 자신에게 친구 요청을 보낼 수 없습니다.' });
    }

    // 이미 친구 요청이 있는지 확인
    const existingRequest = await Friend.findOne({
      $or: [
        { requesterId, receiverId: userId },
        { requesterId: userId, receiverId: requesterId }
      ]
    });

    if (existingRequest) {
      if (existingRequest.status === 'accepted') {
        return res.status(400).json({ message: '이미 친구입니다.' });
      }
      if (existingRequest.status === 'pending') {
        return res.status(400).json({ message: '이미 친구 요청이 있습니다.' });
      }
    }

    // 친구 요청 생성
    const friendRequest = await Friend.create({
      requesterId,
      receiverId: userId,
      status: 'pending',
    });

    res.json({
      message: '친구 요청을 보냈습니다.',
      request: friendRequest,
    });
  } catch (error) {
    console.error('친구 요청 오류:', error);
    res.status(500).json({ message: '친구 요청에 실패했습니다.' });
  }
});

// 친구 요청 수락
router.post('/accept/:requestId', authMiddleware, async (req, res) => {
  try {
    const { requestId } = req.params;

    const request = await Friend.findById(requestId);
    if (!request) {
      return res.status(404).json({ message: '친구 요청을 찾을 수 없습니다.' });
    }

    if (request.receiverId.toString() !== req.userId) {
      return res.status(403).json({ message: '권한이 없습니다.' });
    }

    request.status = 'accepted';
    request.acceptedAt = new Date();
    await request.save();

    res.json({
      message: '친구 요청을 수락했습니다.',
      request,
    });
  } catch (error) {
    console.error('친구 수락 오류:', error);
    res.status(500).json({ message: '친구 요청 수락에 실패했습니다.' });
  }
});

// 친구 요청 거절
router.post('/reject/:requestId', authMiddleware, async (req, res) => {
  try {
    const { requestId } = req.params;

    const request = await Friend.findById(requestId);
    if (!request) {
      return res.status(404).json({ message: '친구 요청을 찾을 수 없습니다.' });
    }

    if (request.receiverId.toString() !== req.userId) {
      return res.status(403).json({ message: '권한이 없습니다.' });
    }

    request.status = 'rejected';
    await request.save();

    res.json({
      message: '친구 요청을 거절했습니다.',
    });
  } catch (error) {
    console.error('친구 거절 오류:', error);
    res.status(500).json({ message: '친구 요청 거절에 실패했습니다.' });
  }
});

// 친구 목록 조회
router.get('/list', authMiddleware, async (req, res) => {
  try {
    const userId = req.userId;

    // 수락된 친구 목록
    const friends = await Friend.find({
      $or: [
        { requesterId: userId, status: 'accepted' },
        { receiverId: userId, status: 'accepted' }
      ]
    }).populate('requesterId receiverId', 'nickname profileImage isOnline');

    // 친구 정보 정리
    const friendList = friends.map(f => {
      const friend = f.requesterId._id.toString() === userId 
        ? f.receiverId 
        : f.requesterId;
      return {
        id: f._id,
        oderId: friend._id,
        nickname: friend.nickname,
        profileImage: friend.profileImage,
        isOnline: friend.isOnline,
        status: 'accepted',
        createdAt: f.acceptedAt || f.createdAt,
      };
    });

    res.json({ friends: friendList });
  } catch (error) {
    console.error('친구 목록 조회 오류:', error);
    res.status(500).json({ message: '친구 목록을 가져오는데 실패했습니다.' });
  }
});

// 받은 친구 요청 목록
router.get('/requests/received', authMiddleware, async (req, res) => {
  try {
    const requests = await Friend.find({
      receiverId: req.userId,
      status: 'pending'
    }).populate('requesterId', 'nickname profileImage');

    const requestList = requests.map(r => ({
      id: r._id,
      oderId: r.requesterId._id,
      nickname: r.requesterId.nickname,
      profileImage: r.requesterId.profileImage,
      status: r.status,
      createdAt: r.createdAt,
    }));

    res.json({ requests: requestList });
  } catch (error) {
    console.error('받은 요청 조회 오류:', error);
    res.status(500).json({ message: '친구 요청 목록을 가져오는데 실패했습니다.' });
  }
});

// 보낸 친구 요청 목록
router.get('/requests/sent', authMiddleware, async (req, res) => {
  try {
    const requests = await Friend.find({
      requesterId: req.userId,
      status: 'pending'
    }).populate('receiverId', 'nickname profileImage');

    const requestList = requests.map(r => ({
      id: r._id,
      oderId: r.receiverId._id,
      nickname: r.receiverId.nickname,
      profileImage: r.receiverId.profileImage,
      status: r.status,
      createdAt: r.createdAt,
    }));

    res.json({ requests: requestList });
  } catch (error) {
    console.error('보낸 요청 조회 오류:', error);
    res.status(500).json({ message: '친구 요청 목록을 가져오는데 실패했습니다.' });
  }
});

// 친구 삭제
router.delete('/:friendId', authMiddleware, async (req, res) => {
  try {
    const { friendId } = req.params;
    const userId = req.userId;

    await Friend.findOneAndDelete({
      _id: friendId,
      $or: [
        { requesterId: userId },
        { receiverId: userId }
      ]
    });

    res.json({ message: '친구가 삭제되었습니다.' });
  } catch (error) {
    console.error('친구 삭제 오류:', error);
    res.status(500).json({ message: '친구 삭제에 실패했습니다.' });
  }
});

module.exports = router;
