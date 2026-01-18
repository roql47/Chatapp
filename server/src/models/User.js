const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
  kakaoId: {
    type: String,
    required: true,
    unique: true,
  },
  nickname: {
    type: String,
    required: true,
    maxlength: 10,
  },
  profileImage: {
    type: String,
    default: null,
  },
  gender: {
    type: String,
    enum: ['male', 'female', 'other', ''],
    default: '',
  },
  genderLocked: {
    type: Boolean,
    default: false, // 성별이 한 번 설정되면 true로 변경
  },
  mbti: {
    type: String,
    enum: ['', 'INTJ', 'INTP', 'ENTJ', 'ENTP', 'INFJ', 'INFP', 'ENFJ', 'ENFP', 
           'ISTJ', 'ISFJ', 'ESTJ', 'ESFJ', 'ISTP', 'ISFP', 'ESTP', 'ESFP'],
    default: '',
  },
  ageRange: {
    type: String,
    default: null, // 카카오에서 가져온 연령대 (예: '20~29')
  },
  
  // 성인인증
  adultVerification: {
    isVerified: {
      type: Boolean,
      default: false,
    },
    verifiedAt: {
      type: Date,
      default: null,
    },
    birthYear: {
      type: Number,
      default: null,
    },
    ci: {
      type: String,
      default: null, // 중복가입 방지용 고유값 (카카오 인증)
    },
    phone: {
      type: String,
      default: null, // SMS 인증 전화번호
    },
  },
  interests: {
    type: [String],
    default: [],
  },
  blockedUsers: {
    type: [mongoose.Schema.Types.ObjectId],
    ref: 'User',
    default: [],
  },
  isOnline: {
    type: Boolean,
    default: false,
  },
  lastActive: {
    type: Date,
    default: Date.now,
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
  
  // 포인트 시스템
  points: {
    type: Number,
    default: 100,
  },
  pointHistory: [{
    type: {
      type: String,
      enum: ['charge', 'use', 'bonus', 'gift_sent', 'gift_received'],
    },
    amount: Number,
    description: String,
    createdAt: {
      type: Date,
      default: Date.now,
    },
  }],
  
  // VIP 시스템
  vip: {
    isVip: {
      type: Boolean,
      default: false,
    },
    tier: {
      type: String,
      enum: ['none', 'bronze', 'silver', 'gold'],
      default: 'none',
    },
    expiresAt: {
      type: Date,
      default: null,
    },
  },
  
  // 제재 시스템
  sanctions: {
    warningCount: {
      type: Number,
      default: 0,
    },
    reportedCount: {
      type: Number,
      default: 0,
    },
    isSuspended: {
      type: Boolean,
      default: false,
    },
    suspendedUntil: {
      type: Date,
      default: null,
    },
    isBanned: {
      type: Boolean,
      default: false,
    },
    bannedAt: {
      type: Date,
      default: null,
    },
  },
  
  // 평가 시스템
  rating: {
    averageScore: {
      type: Number,
      default: 0,
    },
    totalRatings: {
      type: Number,
      default: 0,
    },
    tags: {
      friendly: { type: Number, default: 0 },      // 친절해요
      funny: { type: Number, default: 0 },         // 유머있어요
      interesting: { type: Number, default: 0 },   // 대화가 재미있어요
      respectful: { type: Number, default: 0 },    // 예의바르다
      goodListener: { type: Number, default: 0 },  // 경청을 잘해요
    },
  },
  
  // 선물 통계
  giftStats: {
    totalSent: {
      type: Number,
      default: 0,
    },
    totalReceived: {
      type: Number,
      default: 0,
    },
    totalPointsEarned: {
      type: Number,
      default: 0,
    },
    badge: {
      badge: { type: String, default: 'none' },
      name: { type: String, default: '없음' },
      icon: { type: String, default: '' },
      color: { type: Number, default: 0xFF9E9E9E },
      minGifts: { type: Number, default: 0 },
    },
  },
  
  // FCM 토큰 (Push 알림용)
  fcmToken: {
    type: String,
    default: null,
  },
  
  // 알림 설정
  notificationSettings: {
    friendRequest: { type: Boolean, default: true },
    message: { type: Boolean, default: true },
    matching: { type: Boolean, default: true },
    gift: { type: Boolean, default: true },
  },
  
  // 위치 정보
  location: {
    enabled: {
      type: Boolean,
      default: false,
    },
    latitude: {
      type: Number,
      default: null,
    },
    longitude: {
      type: Number,
      default: null,
    },
    updatedAt: {
      type: Date,
      default: null,
    },
  },
});

// 인덱스 설정
userSchema.index({ kakaoId: 1 });
userSchema.index({ gender: 1 });
userSchema.index({ interests: 1 });
userSchema.index({ 'vip.isVip': 1 });
userSchema.index({ 'sanctions.isBanned': 1 });

module.exports = mongoose.model('User', userSchema);
