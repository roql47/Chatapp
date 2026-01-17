const mongoose = require('mongoose');

const ratingSchema = new mongoose.Schema({
  // 평가한 사람
  rater: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  // 평가받은 사람
  rated: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  // 채팅방 ID
  roomId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'ChatRoom',
    required: true,
  },
  // 별점 (1-5)
  score: {
    type: Number,
    required: true,
    min: 1,
    max: 5,
  },
  // 평가 태그들
  tags: {
    friendly: { type: Boolean, default: false },      // 친절해요
    funny: { type: Boolean, default: false },         // 유머있어요
    interesting: { type: Boolean, default: false },   // 대화가 재미있어요
    respectful: { type: Boolean, default: false },    // 예의바르다
    goodListener: { type: Boolean, default: false },  // 경청을 잘해요
  },
  // 한줄 코멘트 (선택사항)
  comment: {
    type: String,
    maxlength: 100,
    default: '',
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
});

// 동일 채팅방에서 동일 유저 평가는 1회만
ratingSchema.index({ rater: 1, rated: 1, roomId: 1 }, { unique: true });
ratingSchema.index({ rated: 1, createdAt: -1 });

module.exports = mongoose.model('Rating', ratingSchema);
