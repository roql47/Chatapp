const express = require('express');
const router = express.Router();
const Friend = require('../models/Friend');
const User = require('../models/User');
const ChatRoom = require('../models/ChatRoom');
const Message = require('../models/Message');
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

// 친구 목록 조회 (최신 메시지 포함)
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

    // 친구 정보 정리 및 최신 메시지 조회
    const friendList = await Promise.all(friends.map(async (f) => {
      const friend = f.requesterId._id.toString() === userId 
        ? f.receiverId 
        : f.requesterId;
      
      // DM 채팅방 찾기
      const chatRoom = await ChatRoom.findOne({
        participants: { $all: [userId, friend._id], $size: 2 },
        isDM: true,
      });
      
      let lastMessage = null;
      let lastMessageTime = null;
      let unreadCount = 0;
      
      if (chatRoom) {
        // 최신 메시지 조회
        const latestMessage = await Message.findOne({ roomId: chatRoom._id })
          .sort({ timestamp: -1 })
          .limit(1);
        
        if (latestMessage) {
          // 이미지인 경우 "사진" 텍스트로 표시
          lastMessage = latestMessage.type === 'image' ? '📷 사진' : latestMessage.content;
          lastMessageTime = latestMessage.timestamp;
          
          // 읽지 않은 메시지 수 (상대방이 보낸 메시지 중 읽지 않은 것)
          unreadCount = await Message.countDocuments({
            roomId: chatRoom._id,
            senderId: friend._id,
            isRead: false,
          });
        }
      }
      
      return {
        id: f._id,
        oderId: friend._id, // 기존 호환성 유지
        friendUserId: friend._id, // 친구 사용자 ID (DM용)
        nickname: friend.nickname,
        profileImage: friend.profileImage,
        isOnline: friend.isOnline,
        status: 'accepted',
        createdAt: f.acceptedAt || f.createdAt,
        lastMessage,
        lastMessageTime,
        unreadCount,
      };
    }));
    
    // 최신 메시지 시간 기준으로 정렬 (최신 대화가 위로)
    friendList.sort((a, b) => {
      if (!a.lastMessageTime && !b.lastMessageTime) return 0;
      if (!a.lastMessageTime) return 1;
      if (!b.lastMessageTime) return -1;
      return new Date(b.lastMessageTime) - new Date(a.lastMessageTime);
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

// 친구와 DM 채팅방 생성 또는 조회
router.post('/dm/:friendUserId', authMiddleware, async (req, res) => {
  try {
    const { friendUserId } = req.params;
    const userId = req.userId;

    // 친구 관계 확인
    const friendship = await Friend.findOne({
      $or: [
        { requesterId: userId, receiverId: friendUserId, status: 'accepted' },
        { requesterId: friendUserId, receiverId: userId, status: 'accepted' }
      ]
    });

    if (!friendship) {
      return res.status(403).json({ message: '친구만 DM을 보낼 수 있습니다.' });
    }

    // 기존 DM 채팅방 찾기 (isDM 플래그로 구분)
    let chatRoom = await ChatRoom.findOne({
      participants: { $all: [userId, friendUserId], $size: 2 },
      isDM: true,
    });

    // 없으면 새로 생성
    if (!chatRoom) {
      chatRoom = await ChatRoom.create({
        participants: [userId, friendUserId],
        isDM: true,
        isActive: true,
      });
    } else if (!chatRoom.isActive) {
      // 비활성화된 채팅방 재활성화
      chatRoom.isActive = true;
      await chatRoom.save();
    }

    // 상대방 정보 조회
    const friend = await User.findById(friendUserId).select('nickname profileImage isOnline gender interests mbti');

    res.json({
      room: {
        id: chatRoom._id,
        participants: chatRoom.participants,
        createdAt: chatRoom.createdAt,
        isDM: true,
      },
      partner: {
        id: friend._id,
        nickname: friend.nickname,
        profileImage: friend.profileImage,
        isOnline: friend.isOnline,
        gender: friend.gender,
        interests: friend.interests,
        mbti: friend.mbti,
      },
    });
  } catch (error) {
    console.error('DM 채팅방 생성 오류:', error);
    res.status(500).json({ message: 'DM 채팅방 생성에 실패했습니다.' });
  }
});

// 친구 DM 채팅 기록 조회
router.get('/dm/:friendUserId/messages', authMiddleware, async (req, res) => {
  try {
    const { friendUserId } = req.params;
    const userId = req.userId;
    const { limit = 50, before } = req.query;

    // 친구 관계 확인
    const friendship = await Friend.findOne({
      $or: [
        { requesterId: userId, receiverId: friendUserId, status: 'accepted' },
        { requesterId: friendUserId, receiverId: userId, status: 'accepted' }
      ]
    });

    if (!friendship) {
      return res.status(403).json({ message: '친구만 DM을 조회할 수 있습니다.' });
    }

    // DM 채팅방 찾기
    const chatRoom = await ChatRoom.findOne({
      participants: { $all: [userId, friendUserId], $size: 2 },
      isDM: true,
    });

    if (!chatRoom) {
      return res.json({ messages: [], hasMore: false });
    }

    // 메시지 조회
    const query = { roomId: chatRoom._id };
    if (before) {
      query.timestamp = { $lt: new Date(before) };
    }

    const messages = await Message.find(query)
      .sort({ timestamp: -1 })
      .limit(parseInt(limit));

    res.json({
      messages: messages.reverse(),
      hasMore: messages.length === parseInt(limit),
      roomId: chatRoom._id,
    });
  } catch (error) {
    console.error('DM 메시지 조회 오류:', error);
    res.status(500).json({ message: 'DM 메시지 조회에 실패했습니다.' });
  }
});

module.exports = router;
