const jwt = require('jsonwebtoken');
const axios = require('axios');
const User = require('../models/User');
const config = require('../config/env');

// JWT 토큰 생성
const generateToken = (userId) => {
  return jwt.sign({ id: userId }, config.JWT_SECRET, {
    expiresIn: '30d',
  });
};

// JWT 토큰 검증
const verifyToken = (token) => {
  try {
    return jwt.verify(token, config.JWT_SECRET);
  } catch (error) {
    return null;
  }
};

// 카카오 액세스 토큰으로 사용자 정보 가져오기
const getKakaoUserInfo = async (accessToken) => {
  try {
    const response = await axios.get('https://kapi.kakao.com/v2/user/me', {
      headers: {
        Authorization: `Bearer ${accessToken}`,
      },
    });
    return response.data;
  } catch (error) {
    console.error('카카오 사용자 정보 조회 오류:', error.message);
    return null;
  }
};

// 카카오 로그인/회원가입
const loginWithKakao = async (kakaoId, nickname, profileImage, accessToken) => {
  try {
    // 기존 사용자 찾기
    let user = await User.findOne({ kakaoId });

    if (user) {
      // 기존 사용자 - 정보 업데이트
      user.lastActive = new Date();
      await user.save();
    } else {
      // 신규 사용자 생성
      user = await User.create({
        kakaoId,
        nickname: nickname || '익명',
        profileImage,
      });
    }

    // JWT 토큰 생성
    const token = generateToken(user._id);

    return { user, token };
  } catch (error) {
    console.error('카카오 로그인 오류:', error);
    throw error;
  }
};

// 사용자 정보 조회
const getUserById = async (userId) => {
  try {
    const user = await User.findById(userId).select('-blockedUsers');
    return user;
  } catch (error) {
    console.error('사용자 조회 오류:', error);
    return null;
  }
};

// 프로필 업데이트
const updateProfile = async (userId, updates) => {
  try {
    const allowedUpdates = ['nickname', 'gender', 'interests', 'profileImage', 'mbti'];
    const filteredUpdates = {};
    
    // 현재 사용자 정보 가져오기
    const currentUser = await User.findById(userId);
    if (!currentUser) {
      throw new Error('사용자를 찾을 수 없습니다.');
    }
    
    Object.keys(updates).forEach(key => {
      if (allowedUpdates.includes(key)) {
        // 성별은 이미 설정되어 있고 잠겨있으면 변경 불가
        if (key === 'gender') {
          if (currentUser.genderLocked && currentUser.gender) {
            console.log(`성별 변경 거부: userId=${userId}, 이미 잠김`);
            return; // 이 필드는 건너뜀
          }
          // 성별을 처음 설정하는 경우 잠금 설정
          if (updates[key] && updates[key] !== '') {
            filteredUpdates['genderLocked'] = true;
          }
        }
        filteredUpdates[key] = updates[key];
      }
    });

    const user = await User.findByIdAndUpdate(
      userId,
      filteredUpdates,
      { new: true, runValidators: true }
    ).select('-blockedUsers');

    return user;
  } catch (error) {
    console.error('프로필 업데이트 오류:', error);
    throw error;
  }
};

// 사용자 차단
const blockUser = async (userId, blockedUserId) => {
  try {
    await User.findByIdAndUpdate(userId, {
      $addToSet: { blockedUsers: blockedUserId },
    });
    return true;
  } catch (error) {
    console.error('차단 오류:', error);
    return false;
  }
};

// 차단 해제
const unblockUser = async (userId, blockedUserId) => {
  try {
    await User.findByIdAndUpdate(userId, {
      $pull: { blockedUsers: blockedUserId },
    });
    return true;
  } catch (error) {
    console.error('차단 해제 오류:', error);
    return false;
  }
};

// 차단 목록 조회
const getBlockedUsers = async (userId) => {
  try {
    const user = await User.findById(userId)
      .populate('blockedUsers', 'nickname profileImage');
    return user?.blockedUsers || [];
  } catch (error) {
    console.error('차단 목록 조회 오류:', error);
    return [];
  }
};

// 계정 삭제
const deleteAccount = async (userId) => {
  try {
    await User.findByIdAndDelete(userId);
    return true;
  } catch (error) {
    console.error('계정 삭제 오류:', error);
    return false;
  }
};

// ============================================
// 포인트 관련 함수
// ============================================

// 포인트 사용
const usePoints = async (userId, amount, description) => {
  try {
    const user = await User.findById(userId);
    
    if (!user) {
      return { success: false, message: '사용자를 찾을 수 없습니다.' };
    }
    
    if (user.points < amount) {
      return { success: false, message: '포인트가 부족합니다.' };
    }
    
    user.points -= amount;
    user.pointHistory.push({
      type: 'use',
      amount: -amount,
      description,
      createdAt: new Date(),
    });
    
    await user.save();
    
    return { success: true, points: user.points };
  } catch (error) {
    console.error('포인트 사용 오류:', error);
    return { success: false, message: '포인트 사용에 실패했습니다.' };
  }
};

// 포인트 충전
const chargePoints = async (userId, amount, description) => {
  try {
    const user = await User.findById(userId);
    
    if (!user) {
      return { success: false, message: '사용자를 찾을 수 없습니다.' };
    }
    
    user.points += amount;
    user.pointHistory.push({
      type: 'charge',
      amount: amount,
      description,
      createdAt: new Date(),
    });
    
    await user.save();
    
    return { success: true, points: user.points };
  } catch (error) {
    console.error('포인트 충전 오류:', error);
    return { success: false, message: '포인트 충전에 실패했습니다.' };
  }
};

// 보너스 포인트 지급
const giveBonus = async (userId, amount, description) => {
  try {
    const user = await User.findById(userId);
    
    if (!user) {
      return { success: false, message: '사용자를 찾을 수 없습니다.' };
    }
    
    user.points += amount;
    user.pointHistory.push({
      type: 'bonus',
      amount: amount,
      description,
      createdAt: new Date(),
    });
    
    await user.save();
    
    return { success: true, points: user.points };
  } catch (error) {
    console.error('보너스 포인트 지급 오류:', error);
    return { success: false, message: '보너스 포인트 지급에 실패했습니다.' };
  }
};

module.exports = {
  generateToken,
  verifyToken,
  getKakaoUserInfo,
  loginWithKakao,
  getUserById,
  updateProfile,
  blockUser,
  unblockUser,
  getBlockedUsers,
  deleteAccount,
  usePoints,
  chargePoints,
  giveBonus,
};
