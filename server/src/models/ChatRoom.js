const mongoose = require('mongoose');

const chatRoomSchema = new mongoose.Schema({
  participants: [{
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  }],
  isActive: {
    type: Boolean,
    default: true,
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
  endedAt: {
    type: Date,
    default: null,
  },
});

// 인덱스 설정
chatRoomSchema.index({ participants: 1 });
chatRoomSchema.index({ isActive: 1 });

module.exports = mongoose.model('ChatRoom', chatRoomSchema);
