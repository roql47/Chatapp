/**
 * 터미널 테스트 클라이언트
 * 
 * 사용법:
 *   node test-client.js
 * 
 * 에뮬레이터 앱과 실제 매칭을 테스트하기 위한 가상 사용자 클라이언트입니다.
 */

const { io } = require('socket.io-client');
const readline = require('readline');
const http = require('http');

// 설정 (AWS Lightsail 서버)
const SERVER_URL = 'http://52.79.154.253:3001';
const API_URL = 'http://52.79.154.253:3001/api';

// 상태
let socket = null;
let currentUser = null;
let authToken = null;
let currentRoomId = null;
let partnerInfo = null;

// 컬러 출력
const colors = {
  reset: '\x1b[0m',
  bright: '\x1b[1m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  magenta: '\x1b[35m',
  cyan: '\x1b[36m',
  red: '\x1b[31m',
};

const log = {
  info: (msg) => console.log(`${colors.cyan}[INFO]${colors.reset} ${msg}`),
  success: (msg) => console.log(`${colors.green}[SUCCESS]${colors.reset} ${msg}`),
  warn: (msg) => console.log(`${colors.yellow}[WARN]${colors.reset} ${msg}`),
  error: (msg) => console.log(`${colors.red}[ERROR]${colors.reset} ${msg}`),
  chat: (sender, msg) => console.log(`${colors.magenta}[${sender}]${colors.reset} ${msg}`),
  system: (msg) => console.log(`${colors.blue}[SYSTEM]${colors.reset} ${msg}`),
};

// HTTP 요청 헬퍼
function httpRequest(method, path, data = null) {
  return new Promise((resolve, reject) => {
    const fullPath = `/api${path}`;
    const options = {
      hostname: '52.79.154.253',
      port: 3001,
      path: fullPath,
      method: method,
      headers: {
        'Content-Type': 'application/json',
      },
    };

    if (authToken) {
      options.headers['Authorization'] = `Bearer ${authToken}`;
    }

    const req = http.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => body += chunk);
      res.on('end', () => {
        try {
          const parsed = JSON.parse(body);
          if (res.statusCode >= 400) {
            reject(new Error(parsed.message || `HTTP ${res.statusCode}`));
          } else {
            resolve(parsed);
          }
        } catch (e) {
          reject(new Error(`응답 파싱 오류: ${body}`));
        }
      });
    });

    req.on('error', (err) => {
      reject(new Error(`서버 연결 실패: ${err.message} (서버가 실행 중인지 확인하세요)`));
    });
    
    if (data) {
      req.write(JSON.stringify(data));
    }
    req.end();
  });
}

// 테스트 계정 생성
async function createTestAccount() {
  log.info('테스트 계정 생성 중...');
  
  try {
    const response = await httpRequest('POST', '/auth/test/create', {
      nickname: `터미널유저_${Math.floor(Math.random() * 1000)}`,
      gender: 'male',
      interests: ['게임', '음악', '영화'],
    });
    
    if (response.token) {
      currentUser = response.user;
      authToken = response.token;
      log.success(`계정 생성 완료: ${currentUser.nickname} (ID: ${response.userId})`);
      return true;
    } else {
      log.error(`계정 생성 실패: ${response.message}`);
      return false;
    }
  } catch (error) {
    log.error(`계정 생성 오류: ${error.message}`);
    return false;
  }
}

// 소켓 연결
function connectSocket() {
  if (!currentUser || !authToken) {
    log.error('먼저 계정을 생성해주세요.');
    return false;
  }

  log.info('서버에 연결 중...');

  socket = io(SERVER_URL, {
    auth: { token: authToken },
    query: { userId: currentUser._id },
    // 일부 환경(프록시/보안SW 등)에서 websocket 업그레이드가 막힐 수 있어
    // polling fallback을 허용합니다.
    transports: ['websocket', 'polling'],
    reconnection: true,
    reconnectionAttempts: Infinity,
    reconnectionDelay: 500,
    timeout: 10000,
  });

  // 연결 이벤트
  socket.on('connect', () => {
    log.success(`서버 연결됨 (Socket ID: ${socket.id})`);
  });

  socket.on('connect_error', (error) => {
    log.error(`연결 오류: ${error.message}`);
  });

  socket.on('disconnect', (reason) => {
    log.warn(`연결 해제: ${reason}`);
  });

  // 매칭 이벤트
  socket.on('match_found', (data) => {
    log.success('🎉 매칭 성공!');
    currentRoomId = data.room.id;
    partnerInfo = data.partner;
    
    console.log('\n' + '='.repeat(50));
    console.log(`${colors.bright}매칭된 상대방 정보${colors.reset}`);
    console.log('='.repeat(50));
    console.log(`닉네임: ${partnerInfo.nickname}`);
    console.log(`성별: ${partnerInfo.gender === 'male' ? '남성' : partnerInfo.gender === 'female' ? '여성' : '기타'}`);
    console.log(`관심사: ${partnerInfo.interests?.join(', ') || '없음'}`);
    console.log('='.repeat(50) + '\n');
    
    // 채팅방 입장
    socket.emit('join_room', { roomId: currentRoomId });
    log.info('채팅을 시작하세요! (메시지를 입력하고 Enter)');
  });

  socket.on('match_cancelled', () => {
    log.warn('매칭이 취소되었습니다.');
  });

  // 메시지 이벤트
  socket.on('message', (data) => {
    if (data.senderId !== currentUser._id) {
      log.chat(data.senderNickname || '상대방', data.content);
    }
  });

  // 타이핑 이벤트
  socket.on('typing', (data) => {
    if (data.userId !== currentUser._id && data.isTyping) {
      log.system('상대방이 입력 중...');
    }
  });

  // 상대방 연결 해제
  socket.on('partner_disconnected', () => {
    log.warn('상대방이 채팅을 종료했습니다.');
    currentRoomId = null;
    partnerInfo = null;
  });

  return true;
}

// 매칭 시작
function startMatching(filter = {}) {
  if (!socket?.connected) {
    log.error('서버에 연결되어 있지 않습니다.');
    return;
  }

  log.info('매칭 시작... (에뮬레이터에서도 매칭을 시작하세요)');
  socket.emit('start_matching', { filter });
}

// 매칭 취소
function cancelMatching() {
  if (!socket?.connected) {
    log.error('서버에 연결되어 있지 않습니다.');
    return;
  }

  socket.emit('cancel_matching');
  log.info('매칭을 취소했습니다.');
}

// 메시지 전송
function sendMessage(content) {
  if (!socket?.connected) {
    log.error('서버에 연결되어 있지 않습니다.');
    return;
  }

  if (!currentRoomId) {
    log.error('매칭된 채팅방이 없습니다.');
    return;
  }

  socket.emit('send_message', {
    roomId: currentRoomId,
    senderId: currentUser._id,
    senderNickname: currentUser.nickname,
    content: content,
    type: 'text',
  });

  log.chat('나', content);
}

// 채팅방 나가기
function leaveRoom() {
  if (!socket?.connected || !currentRoomId) {
    log.error('채팅방에 참여하고 있지 않습니다.');
    return;
  }

  socket.emit('leave_room', { roomId: currentRoomId });
  log.info('채팅방을 나갔습니다.');
  currentRoomId = null;
  partnerInfo = null;
}

// 도움말 출력
function printHelp() {
  console.log('\n' + '='.repeat(50));
  console.log(`${colors.bright}터미널 테스트 클라이언트 명령어${colors.reset}`);
  console.log('='.repeat(50));
  console.log('/create    - 테스트 계정 생성');
  console.log('/connect   - 서버에 소켓 연결');
  console.log('/match     - 매칭 시작');
  console.log('/cancel    - 매칭 취소');
  console.log('/leave     - 채팅방 나가기');
  console.log('/status    - 현재 상태 확인');
  console.log('/auto      - 자동 응답 모드 ON/OFF');
  console.log('/help      - 도움말 보기');
  console.log('/quit      - 종료');
  console.log('');
  console.log('채팅방에서는 일반 텍스트를 입력하면 메시지로 전송됩니다.');
  console.log('='.repeat(50) + '\n');
}

// 상태 출력
function printStatus() {
  console.log('\n' + '='.repeat(50));
  console.log(`${colors.bright}현재 상태${colors.reset}`);
  console.log('='.repeat(50));
  console.log(`계정: ${currentUser ? currentUser.nickname : '없음'}`);
  console.log(`소켓: ${socket?.connected ? '연결됨' : '연결 안됨'}`);
  console.log(`채팅방: ${currentRoomId || '없음'}`);
  console.log(`상대방: ${partnerInfo?.nickname || '없음'}`);
  console.log(`자동응답: ${autoResponseMode ? 'ON' : 'OFF'}`);
  console.log('='.repeat(50) + '\n');
}

// 자동 응답 모드
let autoResponseMode = false;
const autoResponses = [
  '안녕하세요! 😊',
  '네, 반갑습니다!',
  '오~ 그렇군요!',
  '재미있네요 ㅋㅋ',
  '저도 그렇게 생각해요~',
  '좋은 하루 되세요!',
  '음... 그럴 수 있죠',
  '정말요? 신기하네요!',
];

function toggleAutoResponse() {
  autoResponseMode = !autoResponseMode;
  log.info(`자동 응답 모드: ${autoResponseMode ? 'ON' : 'OFF'}`);
  
  if (autoResponseMode && socket) {
    socket.on('message', (data) => {
      if (data.senderId !== currentUser?._id && currentRoomId) {
        setTimeout(() => {
          const response = autoResponses[Math.floor(Math.random() * autoResponses.length)];
          sendMessage(response);
        }, 1000 + Math.random() * 2000);
      }
    });
  }
}

// 메인 함수
async function main() {
  console.log('\n' + '='.repeat(50));
  console.log(`${colors.bright}${colors.cyan}🚀 랜덤채팅 터미널 테스트 클라이언트${colors.reset}`);
  console.log('='.repeat(50));
  console.log('/help 를 입력하여 명령어를 확인하세요.\n');

  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });

  rl.setPrompt('> ');
  rl.prompt();

  rl.on('line', async (line) => {
    const input = line.trim();
    
    if (input.startsWith('/')) {
      const cmd = input.toLowerCase();
      
      switch (cmd) {
        case '/create':
          await createTestAccount();
          break;
        case '/connect':
          connectSocket();
          break;
        case '/match':
          startMatching();
          break;
        case '/cancel':
          cancelMatching();
          break;
        case '/leave':
          leaveRoom();
          break;
        case '/status':
          printStatus();
          break;
        case '/auto':
          toggleAutoResponse();
          break;
        case '/help':
          printHelp();
          break;
        case '/quit':
        case '/exit':
          log.info('종료합니다...');
          if (socket) socket.disconnect();
          rl.close();
          process.exit(0);
          break;
        default:
          log.warn('알 수 없는 명령어입니다. /help 를 입력하여 명령어를 확인하세요.');
      }
    } else if (input && currentRoomId) {
      sendMessage(input);
    } else if (input) {
      log.warn('채팅방에 참여하고 있지 않습니다. /match 로 매칭을 시작하세요.');
    }

    rl.prompt();
  });

  rl.on('close', () => {
    if (socket) socket.disconnect();
    process.exit(0);
  });
}

// 시작
main().catch(console.error);
