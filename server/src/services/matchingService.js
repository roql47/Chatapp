const User = require('../models/User');
const ChatRoom = require('../models/ChatRoom');
const authService = require('./authService');

// ============================================
// 포인트 설정
// ============================================
const GENDER_FILTER_COST = 10;  // 성별 필터 매칭 비용

// ============================================
// 필터 타임아웃 설정
// ============================================
const FILTER_TIMEOUT = 30 * 1000;  // 30초 후 필터 해제

// ============================================
// 🧪 테스트 모드 설정
// ============================================
const TEST_MODE = false;  // 테스트 모드 ON/OFF (터미널 클라이언트 사용 시 false)
const TEST_MATCH_DELAY = 3000;  // 3초 후 테스트 봇과 매칭

// 테스트 봇 정보
const TEST_BOT = {
  _id: 'test_bot_001',
  kakaoId: 'test_bot_kakao',
  nickname: '테스트 봇 🤖',
  profileImage: null,
  gender: 'other',
  interests: ['테스트', '개발', '채팅'],
  isOnline: true,
  rating: { averageScore: 4.5, totalRatings: 100 },
};
// ============================================

// 매칭 대기열
const matchingQueue = new Map(); // userId -> { socketId, filter, timestamp, user }

// 관심사 일치율 계산
const calculateInterestMatch = (interests1, interests2) => {
  if (!interests1?.length || !interests2?.length) return 0;
  
  const commonInterests = interests1.filter(i => interests2.includes(i));
  const totalUnique = new Set([...interests1, ...interests2]).size;
  
  return {
    matchRate: Math.round((commonInterests.length / totalUnique) * 100),
    commonInterests,
    commonCount: commonInterests.length,
  };
};

// 매칭 점수 계산 (높을수록 좋은 매칭)
const calculateMatchScore = (currentUser, candidateUser, filter) => {
  let score = 0;
  
  // 1. 관심사 일치 점수 (최대 50점)
  const interestMatch = calculateInterestMatch(
    currentUser.interests, 
    candidateUser.interests
  );
  score += interestMatch.matchRate * 0.5;
  
  // 2. 평점 점수 (최대 25점)
  if (candidateUser.rating?.averageScore) {
    score += candidateUser.rating.averageScore * 5;
  }
  
  // 3. 대기 시간 보정 (오래 기다린 사람 우선)
  const waitTime = Date.now() - (matchingQueue.get(candidateUser._id.toString())?.timestamp || Date.now());
  score += Math.min(waitTime / 10000, 5); // 최대 5점
  
  return {
    score,
    interestMatch,
  };
};

// 매칭 대기열에 추가
const addToQueue = async (userId, socketId, filter) => {
  const user = await User.findById(userId);
  matchingQueue.set(userId, {
    socketId,
    filter,
    timestamp: Date.now(),
    user,
  });
  console.log(`매칭 대기열에 추가: ${userId}, 현재 대기 인원: ${matchingQueue.size}`);
};

// 매칭 대기열에서 제거
const removeFromQueue = (userId) => {
  matchingQueue.delete(userId);
  console.log(`매칭 대기열에서 제거: ${userId}, 현재 대기 인원: ${matchingQueue.size}`);
};

// 필터 타임아웃 확인 (30초 이상 대기 시 필터 해제)
const isFilterExpired = (timestamp) => {
  return Date.now() - timestamp > FILTER_TIMEOUT;
};

// MBTI 필터 일치 확인 (다중 선택 지원)
const matchesMbtiFilter = (preferredMbtis, targetMbti) => {
  // 필터가 없거나 비어있으면 매칭 허용
  if (!preferredMbtis || preferredMbtis.length === 0) return true;
  // 타겟 MBTI가 필터 목록에 포함되어 있으면 매칭
  return preferredMbtis.includes(targetMbti);
};

// 관심사 필터 일치 확인 (하나라도 일치하면 매칭)
const matchesInterestFilter = (preferredInterests, targetInterests) => {
  // 필터가 없거나 비어있으면 매칭 허용
  if (!preferredInterests || preferredInterests.length === 0) return true;
  if (!targetInterests || targetInterests.length === 0) return false;
  // 하나라도 일치하면 매칭
  return preferredInterests.some(interest => targetInterests.includes(interest));
};

// 매칭 상대 찾기 (점수 기반)
const findMatch = async (userId, filter) => {
  try {
    const currentUser = await User.findById(userId);
    if (!currentUser) return null;

    // 제재 상태 확인
    if (currentUser.sanctions?.isBanned) {
      return { error: '계정이 정지되었습니다.' };
    }
    if (currentUser.sanctions?.isSuspended && new Date() < currentUser.sanctions.suspendedUntil) {
      return { error: `계정이 ${currentUser.sanctions.suspendedUntil.toLocaleDateString()}까지 정지되었습니다.` };
    }

    // 차단 목록을 문자열 배열로 변환 (ObjectId 비교 문제 해결)
    const blockedUsers = (currentUser.blockedUsers || []).map(id => id.toString());
    const candidates = [];
    
    // 현재 사용자의 대기 시간 확인
    const currentUserData = matchingQueue.get(userId);
    const currentUserTimestamp = currentUserData?.timestamp || Date.now();
    const isCurrentUserFilterExpired = isFilterExpired(currentUserTimestamp);

    // 매칭 대기열에서 후보 찾기
    for (const [candidateId, candidateData] of matchingQueue) {
      if (candidateId === userId) continue;
      
      // 차단 확인 (문자열로 비교)
      if (blockedUsers.includes(candidateId.toString())) {
        console.log(`🚫 차단된 사용자 스킵: ${userId} blocked ${candidateId}`);
        continue;
      }

      const candidateUser = candidateData.user || await User.findById(candidateId);
      if (!candidateUser) continue;

      // 제재 상태 확인
      if (candidateUser.sanctions?.isBanned) continue;
      if (candidateUser.sanctions?.isSuspended && new Date() < candidateUser.sanctions.suspendedUntil) continue;

      // 상대방의 차단 목록 확인 (문자열로 비교)
      const candidateBlockedUsers = (candidateUser.blockedUsers || []).map(id => id.toString());
      if (candidateBlockedUsers.includes(userId.toString())) {
        console.log(`🚫 상대방에게 차단됨 스킵: ${candidateId} blocked ${userId}`);
        continue;
      }

      // 상대방의 대기 시간 확인
      const isCandidateFilterExpired = isFilterExpired(candidateData.timestamp);
      
      // 둘 다 필터가 만료되지 않았을 때만 필터 적용
      const applyFilters = !isCurrentUserFilterExpired && !isCandidateFilterExpired;
      
      if (applyFilters) {
        // 성별 필터 확인
        const candidateFilter = candidateData.filter || {};
        if (filter.preferredGender && filter.preferredGender !== 'any') {
          if (candidateUser.gender !== filter.preferredGender) continue;
        }
        if (candidateFilter.preferredGender && candidateFilter.preferredGender !== 'any') {
          if (currentUser.gender !== candidateFilter.preferredGender) continue;
        }
        
        // MBTI 필터 확인 (다중 선택)
        if (!matchesMbtiFilter(filter.preferredMbtis, candidateUser.mbti)) continue;
        if (!matchesMbtiFilter(candidateFilter.preferredMbtis, currentUser.mbti)) continue;
        
        // 관심사 필터 확인 (다중 선택, 하나라도 일치하면 OK)
        if (!matchesInterestFilter(filter.interests, candidateUser.interests)) continue;
        if (!matchesInterestFilter(candidateFilter.interests, currentUser.interests)) continue;
      } else {
        // 필터 만료 시 로그
        if (isCurrentUserFilterExpired || isCandidateFilterExpired) {
          console.log(`⏰ 필터 타임아웃! ${userId} 또는 ${candidateId} - 필터 없이 매칭`);
        }
      }

      // 매칭 점수 계산
      const matchInfo = calculateMatchScore(currentUser, candidateUser, filter);
      
      candidates.push({
        candidateId,
        candidateSocketId: candidateData.socketId,
        candidateUser,
        filterBypassed: !applyFilters,
        ...matchInfo,
      });
    }

    if (candidates.length === 0) return null;

    // 점수가 높은 순으로 정렬하고 최고 점수 후보 선택
    candidates.sort((a, b) => b.score - a.score);
    const bestMatch = candidates[0];

    return {
      candidateId: bestMatch.candidateId,
      candidateSocketId: bestMatch.candidateSocketId,
      candidateUser: bestMatch.candidateUser,
      interestMatch: bestMatch.interestMatch,
      matchScore: bestMatch.score,
      filterBypassed: bestMatch.filterBypassed,
    };
  } catch (error) {
    console.error('매칭 오류:', error);
    return null;
  }
};

// 매칭 프리뷰 생성
const createMatchPreview = (partner, interestMatch) => {
  return {
    nickname: partner.nickname,
    profileImage: partner.profileImage,
    gender: partner.gender,
    interests: partner.interests?.slice(0, 5) || [],
    rating: {
      averageScore: partner.rating?.averageScore || 0,
      totalRatings: partner.rating?.totalRatings || 0,
    },
    interestMatch: interestMatch || { matchRate: 0, commonInterests: [] },
  };
};

// 채팅방 생성
const createChatRoom = async (user1Id, user2Id) => {
  try {
    const room = await ChatRoom.create({
      participants: [user1Id, user2Id],
    });
    return room;
  } catch (error) {
    console.error('채팅방 생성 오류:', error);
    throw error;
  }
};

// 채팅방 종료
const endChatRoom = async (roomId) => {
  try {
    await ChatRoom.findByIdAndUpdate(roomId, {
      isActive: false,
      endedAt: new Date(),
    });
    return true;
  } catch (error) {
    console.error('채팅방 종료 오류:', error);
    return false;
  }
};

// 성별 필터 사용 여부 확인
const hasGenderFilter = (filter) => {
  return filter.preferredGender && filter.preferredGender !== 'any';
};

// 포인트 차감 (성별 필터 시)
const deductPointsForGenderFilter = async (userId, filter) => {
  if (!hasGenderFilter(filter)) {
    return { success: true };
  }

  const user = await User.findById(userId);
  if (!user) {
    return { success: false, message: '사용자를 찾을 수 없습니다.' };
  }

  if (user.points < GENDER_FILTER_COST) {
    return { 
      success: false, 
      message: `포인트가 부족합니다. 성별 필터 매칭에는 ${GENDER_FILTER_COST}P가 필요합니다.`,
      needsPoints: true,
    };
  }

  const result = await authService.usePoints(userId, GENDER_FILTER_COST, '성별 필터 매칭');
  return result;
};

// 매칭 처리
const processMatching = async (userId, socketId, filter, io) => {
  // 성별 필터가 있으면 포인트 확인
  if (hasGenderFilter(filter)) {
    const pointCheck = await deductPointsForGenderFilter(userId, filter);
    if (!pointCheck.success) {
      return {
        success: false,
        error: pointCheck.message,
        needsPoints: pointCheck.needsPoints,
      };
    }
  }

  // 대기열에 추가
  await addToQueue(userId, socketId, filter);

  // 매칭 상대 찾기
  const match = await findMatch(userId, filter);

  if (match?.error) {
    removeFromQueue(userId);
    return { success: false, error: match.error };
  }

  if (match) {
    // 매칭 성공
    removeFromQueue(userId);
    removeFromQueue(match.candidateId);

    const room = await createChatRoom(userId, match.candidateId);
    const currentUser = await User.findById(userId).select('-blockedUsers -sanctions');

    // 매칭 프리뷰 정보 생성
    const partnerPreview = createMatchPreview(match.candidateUser, match.interestMatch);
    const currentUserPreview = createMatchPreview(currentUser, match.interestMatch);

    return {
      success: true,
      room,
      currentUser,
      partner: match.candidateUser,
      partnerSocketId: match.candidateSocketId,
      partnerPreview,
      currentUserPreview,
      interestMatch: match.interestMatch,
    };
  }

  return { success: false, waiting: true };
};

// 대기열 크기
const getQueueSize = () => matchingQueue.size;

// 대기열 정리
const cleanupQueue = (maxAge = 5 * 60 * 1000) => {
  const now = Date.now();
  for (const [userId, data] of matchingQueue) {
    if (now - data.timestamp > maxAge) {
      matchingQueue.delete(userId);
    }
  }
};

module.exports = {
  addToQueue,
  removeFromQueue,
  findMatch,
  createChatRoom,
  endChatRoom,
  processMatching,
  getQueueSize,
  cleanupQueue,
  calculateInterestMatch,
  createMatchPreview,
  TEST_MODE,
  TEST_MATCH_DELAY,
  TEST_BOT,
  GENDER_FILTER_COST,
  hasGenderFilter,
};
