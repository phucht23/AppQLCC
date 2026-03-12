import mongoose from 'mongoose';

const attendanceSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  date: { type: String, required: true, index: true }, // format: yyyy-MM-dd
  checkIn: { type: Date, default: null },
  checkOut: { type: Date, default: null },
  platform: { type: String, default: 'mobile', enum: ['mobile', 'web', 'qr', 'camera'] },
  photoUrl: { type: String, default: '' },
  photoUrlCheckOut: { type: String, default: '' },
  checkOutPlatform: { type: String, default: '' },
  location: {
    latitude: Number,
    longitude: Number,
    address: String
  },
  deviceInfo: {
    model: String,
    os: String,
    appVersion: String
  }
}, { timestamps: true });

attendanceSchema.index({ userId: 1, date: 1 }, { unique: true });

const Attendance = mongoose.model('Attendance', attendanceSchema);
export default Attendance;
