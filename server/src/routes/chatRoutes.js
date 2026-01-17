const express = require('express');
const router = express.Router();
const authMiddleware = require('../middleware/auth');
const ChatRoom = require('../models/ChatRoom');
const Message = require('../models/Message');

// 채팅 기록 목록 조회 (참여했던 채팅방 목록)
router.get('/history', authMiddleware, async (req, res) => {
  try {
    const userId = req.userId;
    
    // 사용자가 참여한 채팅방 목록 (최근 순)
    const chatRooms = await ChatRoom.find({
      participants: userId,
    })
      .populate('participants', 'nickname profileImage')
      .sort({ createdAt: -1 })
      .limit(50);

    console.log(`[chat/history] userId=${userId} rooms=${chatRooms.length}`);

    // 각 채팅방의 마지막 메시지 가져오기
    const historyWithLastMessage = await Promise.all(
      chatRooms.map(async (room) => {
        const lastMessage = await Message.findOne({ roomId: room._id })
          .sort({ timestamp: -1 })
          .limit(1);

        const messageCount = await Message.countDocuments({ roomId: room._id });

        // 상대방 정보 찾기
        const partner = room.participants.find(
          (p) => p._id.toString() !== userId
        );

        return {
          roomId: room._id,
          partner: partner ? {
            id: partner._id,
            nickname: partner.nickname,
            profileImage: partner.profileImage,
          } : null,
          lastMessage: lastMessage ? {
            content: lastMessage.content,
            type: lastMessage.type,
            timestamp: lastMessage.timestamp,
          } : null,
          messageCount,
          isActive: room.isActive,
          createdAt: room.createdAt,
          endedAt: room.endedAt,
        };
      })
    );

    res.json({ 
      history: historyWithLastMessage,
      total: historyWithLastMessage.length,
    });
  } catch (error) {
    console.error('채팅 기록 조회 오류:', error);
    res.status(500).json({ message: '채팅 기록을 가져오는데 실패했습니다.' });
  }
});

// 특정 채팅방의 메시지 목록 조회
router.get('/room/:roomId/messages', authMiddleware, async (req, res) => {
  try {
    const { roomId } = req.params;
    const { limit = 50, before } = req.query;

    const query = { roomId };
    if (before) {
      query.timestamp = { $lt: new Date(before) };
    }

    const messages = await Message.find(query)
      .sort({ timestamp: -1 })
      .limit(parseInt(limit));

    res.json({ 
      messages: messages.reverse(), // 시간순으로 정렬
      hasMore: messages.length === parseInt(limit),
    });
  } catch (error) {
    console.error('메시지 조회 오류:', error);
    res.status(500).json({ message: '메시지를 가져오는데 실패했습니다.' });
  }
});

module.exports = router;
