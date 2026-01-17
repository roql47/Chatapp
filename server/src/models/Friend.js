const mongoose = require('mongoose');

const friendSchema = new mongoose.Schema({
  // 친구 요청 보낸 사람
  requesterId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  // 친구 요청 받은 사람
  receiverId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  status: {
    type: String,
    enum: ['pending', 'accepted', 'rejected'],
    default: 'pending',
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
  acceptedAt: {
    type: Date,
    default: null,
  },
});

// 인덱스 설정
friendSchema.index({ requesterId: 1, receiverId: 1 }, { unique: true });
friendSchema.index({ requesterId: 1, status: 1 });
friendSchema.index({ receiverId: 1, status: 1 });

module.exports = mongoose.model('Friend', friendSchema);
