const mongoose = require('mongoose');

// 선물 종류 정의 (icon: Material Design Icon 이름)
const GIFT_TYPES = {
  heart: { name: '하트', price: 10, icon: 'favorite', color: 0xFFE91E63 },
  rose: { name: '장미', price: 30, icon: 'local_florist', color: 0xFFF44336 },
  star: { name: '별', price: 50, icon: 'star', color: 0xFFFFEB3B },
  diamond: { name: '다이아몬드', price: 100, icon: 'diamond', color: 0xFF00BCD4 },
  crown: { name: '왕관', price: 200, icon: 'workspace_premium', color: 0xFFFFD700 },
  rocket: { name: '로켓', price: 500, icon: 'rocket_launch', color: 0xFFFF5722 },
};

const giftSchema = new mongoose.Schema({
  // 보낸 사람
  sender: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  // 받은 사람
  receiver: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  // 선물 종류
  giftType: {
    type: String,
    enum: Object.keys(GIFT_TYPES),
    required: true,
  },
  // 선물 가격 (포인트)
  price: {
    type: Number,
    required: true,
  },
  // 메시지
  message: {
    type: String,
    maxlength: 100,
    default: '',
  },
  // 채팅방 ID (선택사항)
  roomId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'ChatRoom',
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
});

// 인덱스
giftSchema.index({ sender: 1, createdAt: -1 });
giftSchema.index({ receiver: 1, createdAt: -1 });

// 선물 종류 정보를 스태틱 메서드로 제공
giftSchema.statics.getGiftTypes = function() {
  return GIFT_TYPES;
};

giftSchema.statics.getGiftInfo = function(type) {
  return GIFT_TYPES[type] || null;
};

module.exports = mongoose.model('Gift', giftSchema);
