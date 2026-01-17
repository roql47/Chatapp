const mongoose = require('mongoose');

const reportSchema = new mongoose.Schema({
  reporter: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  reported: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  roomId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'ChatRoom',
  },
  // 상세 신고 사유
  category: {
    type: String,
    enum: [
      'abuse',        // 욕설/비하
      'sexual',       // 성희롱/음란
      'spam',         // 광고/스팸
      'scam',         // 사기/피싱
      'impersonation', // 사칭
      'threat',       // 협박/위협
      'personal_info', // 개인정보 요구
      'other',        // 기타
    ],
    required: true,
  },
  description: {
    type: String,
    default: '',
    maxlength: 500,
  },
  // 증거 (스크린샷 URL 등)
  evidence: [{
    type: String,
  }],
  status: {
    type: String,
    enum: ['pending', 'reviewing', 'warning_issued', 'suspended', 'banned', 'dismissed'],
    default: 'pending',
  },
  // 처리 결과
  resolution: {
    action: {
      type: String,
      enum: ['none', 'warning', 'suspend_1day', 'suspend_3day', 'suspend_7day', 'suspend_30day', 'permanent_ban'],
      default: 'none',
    },
    processedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
    },
    processedAt: {
      type: Date,
    },
    note: {
      type: String,
    },
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
});

// 인덱스
reportSchema.index({ reported: 1, status: 1 });
reportSchema.index({ reporter: 1 });
reportSchema.index({ createdAt: -1 });

module.exports = mongoose.model('Report', reportSchema);
