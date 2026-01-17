const authService = require('../services/authService');
const matchingService = require('../services/matchingService');
const Message = require('../models/Message');
const User = require('../models/User');
const ChatRoom = require('../models/ChatRoom');

// 소켓 ID와 사용자 ID 매핑
const userSockets = new Map(); // userId -> socketId
const socketUsers = new Map(); // socketId -> userId

const setupSocketHandlers = (io) => {
  // TEST_MODE용: "테스트 봇" 대화방 추적 (roomId -> true)
  const testBotRooms = new Set();

  // TEST_MODE용: 테스트 봇 유저를 DB에 보장 (메시지/방 저장을 위해 ObjectId 필요)
  const getOrCreateTestBotUser = async () => {
    const kakaoId = matchingService.TEST_BOT?.kakaoId || 'test_bot_kakao';
    let bot = await User.findOne({ kakaoId });
    if (!bot) {
      bot = await User.create({
        kakaoId,
        nickname: matchingService.TEST_BOT?.nickname || '테스트 봇 🤖',
        profileImage: null,
        gender: matchingService.TEST_BOT?.gender || 'other',
        interests: matchingService.TEST_BOT?.interests || ['테스트', '개발', '채팅'],
        isOnline: true,
      });
    }
    return bot;
  };

  // 인증 미들웨어
  io.use(async (socket, next) => {
    try {
      const token = socket.handshake.auth?.token;
      const userId = socket.handshake.query?.userId;

      if (!token || !userId) {
        return next(new Error('인증 정보가 필요합니다.'));
      }

      const decoded = authService.verifyToken(token);
      if (!decoded || decoded.id !== userId) {
        return next(new Error('유효하지 않은 토큰입니다.'));
      }

      socket.userId = userId;
      next();
    } catch (error) {
      next(new Error('인증 실패'));
    }
  });

  io.on('connection', async (socket) => {
    const userId = socket.userId;
    console.log(`사용자 연결됨: ${userId}`);

    // 매핑 저장
    userSockets.set(userId, socket.id);
    socketUsers.set(socket.id, userId);

    // 온라인 상태 업데이트
    await User.findByIdAndUpdate(userId, { isOnline: true });

    // 매칭 시작
    socket.on('start_matching', async (data) => {
      const { filter } = data;
      console.log(`매칭 시작: ${userId}`, filter);

      const result = await matchingService.processMatching(
        userId,
        socket.id,
        filter || {},
        io
      );

      if (result.success) {
        // 매칭 성공 - 양쪽에 알림
        const room = result.room;

        // 현재 사용자에게 매칭 정보 전송
        socket.emit('match_found', {
          room: {
            id: room._id,
            participants: room.participants,
            createdAt: room.createdAt,
          },
          partner: {
            id: result.partner._id,
            nickname: result.partner.nickname,
            profileImage: result.partner.profileImage,
            gender: result.partner.gender,
            interests: result.partner.interests,
          },
        });

        // 상대방에게 매칭 정보 전송
        io.to(result.partnerSocketId).emit('match_found', {
          room: {
            id: room._id,
            participants: room.participants,
            createdAt: room.createdAt,
          },
          partner: {
            id: result.currentUser._id,
            nickname: result.currentUser.nickname,
            profileImage: result.currentUser.profileImage,
            gender: result.currentUser.gender,
            interests: result.currentUser.interests,
          },
        });

        console.log(`매칭 성공: ${userId} <-> ${result.partner._id}`);
      } else if (matchingService.TEST_MODE) {
        // 🧪 테스트 모드: 일정 시간 후 테스트 봇과 자동 매칭
        console.log(`🧪 테스트 모드: ${matchingService.TEST_MATCH_DELAY/1000}초 후 테스트 봇과 매칭 예정`);
        
        setTimeout(async () => {
          // 아직 매칭 대기 중인지 확인
          if (matchingService.getQueueSize() > 0) {
            // 대기열에서 제거
            matchingService.removeFromQueue(userId);
            
            // ✅ 테스트도 채팅 기록이 남도록: DB에 실제 ChatRoom(ObjectId) 생성
            const botUser = await getOrCreateTestBotUser();
            const room = await ChatRoom.create({
              participants: [userId, botUser._id],
            });
            const roomId = room._id.toString();
            testBotRooms.add(roomId);
            
            // 테스트 봇과 매칭 알림
            socket.emit('match_found', {
              room: {
                id: roomId,
                participants: [userId, botUser._id.toString()],
                createdAt: room.createdAt,
              },
              partner: {
                // Flutter에서 테스트 봇 차단 로직 유지 (startsWith('test_bot'))
                id: 'test_bot_001',
                nickname: matchingService.TEST_BOT.nickname,
                profileImage: matchingService.TEST_BOT.profileImage,
                gender: matchingService.TEST_BOT.gender,
                interests: matchingService.TEST_BOT.interests,
              },
            });
            
            // 테스트 봇 자동 입장
            socket.join(roomId);
            
            console.log(`🧪 테스트 매칭 성공: ${userId} <-> ${matchingService.TEST_BOT.nickname}`);
            
            // 테스트 봇이 3초 후 인사 메시지 전송
            setTimeout(() => {
              // ✅ DB에 저장
              Message.create({
                roomId: room._id,
                senderId: botUser._id,
                senderNickname: matchingService.TEST_BOT.nickname,
                content: '안녕하세요! 저는 테스트 봇입니다 🤖\n메시지를 보내보세요!',
                type: 'text',
              }).then((message) => {
                // ✅ 클라이언트에는 기존 테스트봇 senderId 형식 유지
                socket.emit('message', {
                  id: message._id,
                  roomId,
                  senderId: 'test_bot_001',
                  senderNickname: matchingService.TEST_BOT.nickname,
                  content: message.content,
                  type: message.type,
                  timestamp: message.timestamp,
                  isRead: message.isRead,
                });
              }).catch((err) => console.error('테스트 봇 메시지 저장 오류:', err));
            }, 2000);
          }
        }, matchingService.TEST_MATCH_DELAY);
      }
    });

    // 매칭 취소
    socket.on('cancel_matching', () => {
      matchingService.removeFromQueue(userId);
      socket.emit('match_cancelled');
      console.log(`매칭 취소: ${userId}`);
    });

    // 채팅방 참가
    socket.on('join_room', (data) => {
      const { roomId } = data;
      socket.join(roomId);
      console.log(`방 참가: ${userId} -> ${roomId}`);
    });

    // 채팅방 나가기
    socket.on('leave_room', async (data) => {
      const { roomId } = data;
      socket.leave(roomId);
      testBotRooms.delete(roomId);
      
      // 상대방에게 알림
      socket.to(roomId).emit('partner_disconnected');
      
      // 채팅방 종료
      await matchingService.endChatRoom(roomId);
      
      console.log(`방 나감: ${userId} <- ${roomId}`);
    });

    // 메시지 전송
    socket.on('send_message', async (data) => {
      try {
        // ✅ 항상 메시지 저장 (테스트 계정/테스트봇도 기록 남김)
        const message = await Message.create({
          roomId: data.roomId,
          senderId: data.senderId,
          senderNickname: data.senderNickname,
          content: data.content,
          type: data.type || 'text',
        });

        // 같은 방의 다른 사용자들에게 메시지 전송
        socket.to(data.roomId).emit('message', {
          id: message._id,
          roomId: message.roomId,
          senderId: message.senderId,
          senderNickname: message.senderNickname,
          content: message.content,
          type: message.type,
          timestamp: message.timestamp,
          isRead: message.isRead,
        });

        console.log(`메시지 전송: ${userId} -> ${data.roomId}`);
        
        // 🧪 테스트 모드: 테스트 봇 자동 응답
        if (matchingService.TEST_MODE && testBotRooms.has(data.roomId)) {
          setTimeout(() => {
            const botResponses = [
              '네, 알겠습니다! 😊',
              '재미있네요! ㅋㅋㅋ',
              '오~ 그렇군요!',
              '좋은 생각이에요! 👍',
              '저도 그렇게 생각해요~',
              '더 자세히 알려주세요!',
              '정말요? 신기하네요!',
              '하하 재밌어요 😄',
            ];
            const randomResponse = botResponses[Math.floor(Math.random() * botResponses.length)];
            
            getOrCreateTestBotUser().then((botUser) => {
              return Message.create({
                roomId: data.roomId,
                senderId: botUser._id,
                senderNickname: matchingService.TEST_BOT.nickname,
                content: randomResponse,
                type: 'text',
              }).then((botMsg) => {
                socket.emit('message', {
                  id: botMsg._id,
                  roomId: data.roomId,
                  senderId: 'test_bot_001',
                  senderNickname: matchingService.TEST_BOT.nickname,
                  content: botMsg.content,
                  type: botMsg.type,
                  timestamp: botMsg.timestamp,
                  isRead: botMsg.isRead,
                });
              });
            }).catch((err) => console.error('테스트 봇 자동응답 저장 오류:', err));
          }, 1000 + Math.random() * 2000); // 1~3초 랜덤 딜레이
        }
      } catch (error) {
        console.error('메시지 저장 오류:', error);
      }
    });

    // 타이핑 상태
    socket.on('typing', (data) => {
      const { roomId, isTyping } = data;
      socket.to(roomId).emit('typing', {
        userId,
        isTyping,
      });
    });

    // WebRTC 시그널링 - 통화 요청
    socket.on('call_offer', (data) => {
      const { roomId, offer } = data;
      socket.to(roomId).emit('call_offer', {
        roomId,
        userId,
        offer,
      });
      console.log(`통화 요청: ${userId} in ${roomId}`);
    });

    // WebRTC 시그널링 - 통화 응답
    socket.on('call_answer', (data) => {
      const { roomId, answer } = data;
      socket.to(roomId).emit('call_answer', {
        roomId,
        userId,
        answer,
      });
      console.log(`통화 응답: ${userId} in ${roomId}`);
    });

    // WebRTC 시그널링 - ICE Candidate
    socket.on('ice_candidate', (data) => {
      const { roomId, candidate } = data;
      socket.to(roomId).emit('ice_candidate', {
        roomId,
        userId,
        candidate,
      });
    });

    // WebRTC 시그널링 - 통화 종료
    socket.on('end_call', (data) => {
      const { roomId } = data;
      socket.to(roomId).emit('call_ended');
      console.log(`통화 종료: ${userId} in ${roomId}`);
    });

    // 연결 해제
    socket.on('disconnect', async () => {
      console.log(`사용자 연결 해제: ${userId}`);
      
      // 매칭 대기열에서 제거
      matchingService.removeFromQueue(userId);
      
      // 매핑 제거
      userSockets.delete(userId);
      socketUsers.delete(socket.id);

      // 오프라인 상태 업데이트
      await User.findByIdAndUpdate(userId, {
        isOnline: false,
        lastActive: new Date(),
      });
    });
  });

  // 주기적으로 매칭 대기열 정리 (5분마다)
  setInterval(() => {
    matchingService.cleanupQueue();
  }, 5 * 60 * 1000);
};

// 특정 사용자에게 메시지 전송
const sendToUser = (io, userId, event, data) => {
  const socketId = userSockets.get(userId);
  if (socketId) {
    io.to(socketId).emit(event, data);
  }
};

// 온라인 사용자 수
const getOnlineCount = () => userSockets.size;

module.exports = {
  setupSocketHandlers,
  sendToUser,
  getOnlineCount,
};
