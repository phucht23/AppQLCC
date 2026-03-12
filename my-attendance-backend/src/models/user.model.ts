import mongoose from 'mongoose';

const userSchema = new mongoose.Schema({
  email: { type: String, required: true, unique: true, lowercase: true, trim: true },
  password: { type: String, required: true },
  name: { type: String, default: '' },
  role: { type: String, default: 'employee', enum: ['employee', 'admin'] },
  isActive: { type: Boolean, default: true },
  // THÊM 2 TRƯỜNG CHỐNG CHẤM CÔNG HỘ
  faceDescriptor: { 
    type: [Number],           // mảng 128 hoặc 10 số đặc trưng khuôn mặt
    default: null 
  },
  hasRegisteredFace: { 
    type: Boolean, 
    default: false 
  },
}, { timestamps: true });
// Index để tìm nhanh user theo email
userSchema.index({ email: 1 });

const User = mongoose.model('User', userSchema);
export default User;
