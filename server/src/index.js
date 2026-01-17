const express = require('express');
const http = require('http');
const path = require('path');
const { Server } = require('socket.io');
const cors = require('cors');
const connectDB = require('./config/database');
const config = require('./config/env');
const { setupSocketHandlers, getOnlineCount } = require('./socket/socketHandler');

// 라우터
const authRoutes = require('./routes/authRoutes');
const reportRoutes = require('./routes/reportRoutes');
const friendRoutes = require('./routes/friendRoutes');
const ratingRoutes = require('./routes/ratingRoutes');
const giftRoutes = require('./routes/giftRoutes');
const vipRoutes = require('./routes/vipRoutes');
const chatRoutes = require('./routes/chatRoutes');
const uploadRoutes = require('./routes/uploadRoutes');

const app = express();
const server = http.createServer(app);

// Socket.io 설정
const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST'],
  },
});

// 미들웨어
app.use(cors());
app.use(express.json());

// 정적 파일 서빙 (업로드된 이미지)
app.use('/uploads', express.static(path.join(__dirname, '../uploads')));

// MongoDB 연결
connectDB();

// API 라우트
app.use('/api/auth', authRoutes);
app.use('/api/reports', reportRoutes);
app.use('/api/friends', friendRoutes);
app.use('/api/ratings', ratingRoutes);
app.use('/api/gifts', giftRoutes);
app.use('/api/vip', vipRoutes);
app.use('/api/chat', chatRoutes);
app.use('/api/upload', uploadRoutes);

// 상태 체크 엔드포인트
app.get('/api/health', (req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    onlineUsers: getOnlineCount(),
  });
});

// Socket.io 핸들러 설정
setupSocketHandlers(io);

// io 객체를 전역에서 접근 가능하도록 설정
app.set('io', io);

// 에러 핸들링
app.use((err, req, res, next) => {
  console.error('서버 오류:', err);
  res.status(500).json({ message: '서버 오류가 발생했습니다.' });
});

// 서버 시작
const PORT = config.PORT;
server.listen(PORT, () => {
  console.log(`
╔════════════════════════════════════════════╗
║                                            ║
║     🚀 랜덤채팅 서버 시작                   ║
║                                            ║
║     포트: ${PORT}                             ║
║     환경: ${config.NODE_ENV}                   ║
║                                            ║
╚════════════════════════════════════════════╝
  `);
});

module.exports = { app, server, io };
