const express = require('express');
const http = require('http');
const path = require('path');
const { Server } = require('socket.io');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const mongoSanitize = require('express-mongo-sanitize');
const hpp = require('hpp');
const connectDB = require('./config/database');
const config = require('./config/env');
const { setupSocketHandlers, getOnlineCount } = require('./socket/socketHandler');

// 라우터
const authRoutes = require('./routes/authRoutes');
const reportRoutes = require('./routes/reportRoutes');
const friendRoutes = require('./routes/friendRoutes');
const ratingRoutes = require('./routes/ratingRoutes');
const giftRoutes = require('./routes/giftRoutes');
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
  // Socket.io 보안 설정
  pingTimeout: 60000,
  pingInterval: 25000,
  maxHttpBufferSize: 1e6, // 1MB 최대 메시지 크기
});

// ===== 보안 미들웨어 =====

// Helmet - HTTP 헤더 보안 설정
app.use(helmet({
  crossOriginResourcePolicy: { policy: 'cross-origin' }, // 이미지 서빙을 위해
}));

// CORS 설정
app.use(cors());

// Body 크기 제한 (DoS 방지)
app.use(express.json({ limit: '10kb' })); // JSON body 10KB 제한
app.use(express.urlencoded({ extended: true, limit: '10kb' }));

// NoSQL Injection 방지 (MongoDB 쿼리 악성 입력 차단)
app.use(mongoSanitize());

// HTTP Parameter Pollution 방지
app.use(hpp());

// ===== Rate Limiting (API 호출 횟수 제한) =====

// 전역 Rate Limiter - 1분당 100요청
const globalLimiter = rateLimit({
  windowMs: 60 * 1000, // 1분
  max: 100,
  message: { message: '너무 많은 요청입니다. 잠시 후 다시 시도해주세요.' },
  standardHeaders: true,
  legacyHeaders: false,
});
app.use('/api', globalLimiter);

// 로그인/인증 Rate Limiter - 더 엄격 (5분당 10요청)
const authLimiter = rateLimit({
  windowMs: 5 * 60 * 1000, // 5분
  max: 10,
  message: { message: '로그인 시도가 너무 많습니다. 5분 후 다시 시도해주세요.' },
  standardHeaders: true,
  legacyHeaders: false,
});
app.use('/api/auth/kakao', authLimiter);
app.use('/api/auth/adult-verification', authLimiter);

// 업로드 Rate Limiter - 1분당 10요청
const uploadLimiter = rateLimit({
  windowMs: 60 * 1000, // 1분
  max: 10,
  message: { message: '업로드 요청이 너무 많습니다. 잠시 후 다시 시도해주세요.' },
  standardHeaders: true,
  legacyHeaders: false,
});
app.use('/api/upload', uploadLimiter);

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
