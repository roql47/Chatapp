const mongoose = require('mongoose');

const messageSchema = new mongoose.Schema({
  roomId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'ChatRoom',
    required: true,
  },
  senderId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  senderNickname: {
    type: String,
    required: true,
  },
  content: {
    type: String,
    required: true,
    maxlength: 1000, // 트래픽 예방을 위한 글자수 제한
  },
  type: {
    type: String,
    enum: ['text', 'image', 'system'],
    default: 'text',
  },
  isRead: {
    type: Boolean,
    default: false,
  },
  timestamp: {
    type: Date,
    default: Date.now,
  },
});

// 인덱스 설정
messageSchema.index({ roomId: 1 });
messageSchema.index({ timestamp: -1 });

module.exports = mongoose.model('Message', messageSchema);
