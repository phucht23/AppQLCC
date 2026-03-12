import mongoose from 'mongoose';

const leaveRequestSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  email: {
    type: String,
    required: true,
    lowercase: true,
    trim: true
  },
  name: {
    type: String,
    required: true
  }, // Tên nhân viên – lấy từ User để hiển thị
  date: {
    type: String,         // yyyy-MM-dd, ví dụ: "2025-12-13"
    required: true
  },
  reason: {
    type: String,
    required: true,
    trim: true
  },
  status: {
    type: String,
    enum: ['pending', 'approved', 'rejected'],
    default: 'pending'
  },
  note: {
    type: String,
    default: ''
  }, // Ghi chú admin
  approvedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    default: null
  },
  approvedAt: {
    type: Date,
    default: null
  }
}, {
  timestamps: true
});

// Index tìm nhanh
leaveRequestSchema.index({ userId: 1, status: 1 });
leaveRequestSchema.index({ status: 1, createdAt: -1 });

export default mongoose.model('LeaveRequest', leaveRequestSchema);