import express from 'express';
import cors from 'cors';
import mongoose from 'mongoose';
import jwt from 'jsonwebtoken';
import bcrypt from 'bcryptjs';
import dotenv from 'dotenv';
import LeaveRequest from './models/leave_request.model'; // BỎ ĐUÔI .js, chỉ để .model
dotenv.config();

const app = express();
app.use(cors());
app.use(express.json());
//app.use('/leave', leaveRoutes);

const PORT = Number(process.env.PORT || 3000);
const JWT_SECRET = process.env.JWT_SECRET || 'chamcong2025_super_secret_key';

// Kết nối MongoDB
mongoose.connect(process.env.MONGODB_URI as string, {
  serverSelectionTimeoutMS: 5000,
  socketTimeoutMS: 45000,
})
  .then(() => console.log('✅ MongoDB Connected Successfully'))
  .catch(err => {
    console.error('❌ MongoDB Connection Error:', err);
    process.exit(1);
  });

// User Schema
const userSchema = new mongoose.Schema({
  email: { type: String, required: true, unique: true, lowercase: true, trim: true },
  password: { type: String, required: true },
  name: { type: String, default: '' },
  role: { type: String, default: 'employee', enum: ['employee', 'admin'] },
  isActive: { type: Boolean, default: true },
  faceDescriptor: { type: [Number], default: [] }, // Mảng lưu trữ đặc trưng khuôn mặt
  faceRegisteredAt: { type: Date, default: null } // Thời gian đăng ký khuôn mặt
}, { timestamps: true });

const User = mongoose.model('User', userSchema);

// Attendance Schema - CẬP NHẬT để phù hợp với Firebase
const attendanceSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  date: { type: String, required: true, index: true }, // Format: yyyy-MM-dd
  checkIn: { type: Date, default: null },
  checkOut: { type: Date, default: null },
  platform: { type: String, default: 'mobile', enum: ['mobile', 'web', 'qr', 'camera'] },
  photoUrl: { type: String, default: '' },
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

// Middleware xác thực
const authenticate = (req: any, res: any, next: any) => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Không có token xác thực' });
  }

  const token = authHeader.split(' ')[1];
  try {
    const decoded = jwt.verify(token, JWT_SECRET) as any;
    req.user = { 
      uid: decoded.userId,
      email: decoded.email,
      role: decoded.role || 'employee'
    };
    next();
  } catch (err) {
    return res.status(401).json({ error: 'Token không hợp lệ hoặc đã hết hạn' });
  }
};

// Middleware kiểm tra quyền admin
const requireAdmin = (req: any, res: any, next: any) => {
  if (req.user.role !== 'admin') {
    return res.status(403).json({ error: 'Chỉ admin mới có quyền truy cập' });
  }
  next();
};

// Root endpoint
app.get('/', (req, res) => {
  res.json({ 
    message: 'Backend chấm công đang chạy ngon lành! 🚀',
    version: '2.0.0',
    timestamp: new Date().toISOString()
  });
});

// ============= AUTH ENDPOINTS =============

// Đăng ký
app.post('/register', async (req, res) => {
  try {
    const { email, password, name, role = 'employee' } = req.body;

    if (!email || !password) {
      return res.status(400).json({ error: 'Email và mật khẩu là bắt buộc' });
    }

    if (password.length < 6) {
      return res.status(400).json({ error: 'Mật khẩu phải có ít nhất 6 ký tự' });
    }

    const existingUser = await User.findOne({ email: email.toLowerCase() });
    if (existingUser) {
      return res.status(400).json({ error: 'Email đã được đăng ký' });
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    const newUser = await new User({ 
      email: email.toLowerCase(), 
      password: hashedPassword,
      name: name || '',
      role: role
    }).save();

    res.status(201).json({ 
      message: 'Đăng ký thành công',
      userId: newUser._id
    });
  } catch (err: any) {
    console.error('Register error:', err);
    res.status(500).json({ error: 'Lỗi server khi đăng ký' });
  }
});

// Đăng nhập
app.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ error: 'Email và mật khẩu là bắt buộc' });
    }

    const user = await User.findOne({ email: email.toLowerCase() });
    if (!user) {
      return res.status(401).json({ error: 'Email hoặc mật khẩu không đúng' });
    }

    if (!user.isActive) {
      return res.status(403).json({ error: 'Tài khoản đã bị vô hiệu hóa' });
    }

    const isValidPassword = await bcrypt.compare(password, user.password);
    if (!isValidPassword) {
      return res.status(401).json({ error: 'Email hoặc mật khẩu không đúng' });
    }

    const token = jwt.sign(
      { userId: user._id, email: user.email, role: user.role }, 
      JWT_SECRET, 
      { expiresIn: '7d' }
    );

    res.json({ 
      token, 
      userId: user._id,
      email: user.email,
      name: user.name,
      role: user.role
    });
  } catch (err) {
    console.error('Login error:', err);
    res.status(500).json({ error: 'Lỗi server khi đăng nhập' });
  }
});

// ============= ATTENDANCE ENDPOINTS =============

// Chấm công (Check in hoặc Check out)
app.post('/checkin', authenticate, async (req: any, res) => {
  try {
    const { platform = 'mobile', photoUrl = '', location, deviceInfo } = req.body;
    const userId = req.user.uid;
    const today = new Date().toISOString().split('T')[0];

    // Tìm bản ghi attendance hôm nay
    let attendance = await Attendance.findOne({ userId, date: today });

    if (!attendance) {
      // Chưa có -> Tạo mới với checkIn
      attendance = await new Attendance({ 
        userId, 
        date: today, 
        platform, 
        photoUrl,
        location,
        deviceInfo,
        checkIn: new Date(new Date().getTime() + 7 * 60 * 60 * 1000)
      }).save();

      return res.json({ 
        message: 'Check in thành công! ✅', 
        time: attendance.checkIn,
        attendanceId: attendance._id,
        type: 'checkin'
      });
    } else if (attendance.checkIn && !attendance.checkOut) {
      // Đã check in, chưa check out -> Update checkOut
      attendance.checkOut = new Date(new Date().getTime() + 7 * 60 * 60 * 1000);
      await attendance.save();

      return res.json({ 
        message: 'Check out thành công! 👋', 
        time: attendance.checkOut,
        attendanceId: attendance._id,
        type: 'checkout'
      });
    } else {
      // Đã hoàn thành cả check in và check out
      return res.status(400).json({ 
        message: 'Hôm nay bạn đã hoàn thành chấm công!',
        checkedInAt: attendance.checkIn,
        checkedOutAt: attendance.checkOut
      });
    }
  } catch (err) {
    console.error('Checkin error:', err);
    res.status(500).json({ error: 'Lỗi server khi chấm công' });
  }
});

// Lấy lịch sử chấm công (có filter theo ngày)
app.get('/attendance/history', authenticate, async (req: any, res) => {
  try {
    const userId = req.user.uid;
    const { limit = 30, skip = 0, startDate, endDate } = req.query;

    let query: any = { userId };

    // Filter theo khoảng thời gian nếu có
    if (startDate || endDate) {
      query.date = {};
      if (startDate) query.date.$gte = startDate;
      if (endDate) query.date.$lte = endDate;
    }

    const attendances = await Attendance
      .find(query)
      .sort({ date: -1 })
      .limit(parseInt(limit as string))
      .skip(parseInt(skip as string));

    const total = await Attendance.countDocuments(query);

    res.json({
      data: attendances,
      total,
      limit: parseInt(limit as string),
      skip: parseInt(skip as string)
    });
  } catch (err) {
    console.error('Get history error:', err);
    res.status(500).json({ error: 'Lỗi khi lấy lịch sử chấm công' });
  }
});

// Kiểm tra trạng thái chấm công hôm nay
app.get('/attendance/today', authenticate, async (req: any, res) => {
  try {
    const userId = req.user.uid;
    const today = new Date().toISOString().split('T')[0];

    const todayAttendance = await Attendance.findOne({ userId, date: today });

    res.json({
      hasCheckedIn: !!todayAttendance?.checkIn,
      hasCheckedOut: !!todayAttendance?.checkOut,
      attendance: todayAttendance
    });
  } catch (err) {
    console.error('Check today error:', err);
    res.status(500).json({ error: 'Lỗi khi kiểm tra trạng thái' });
  }
});

// ============= ADMIN ENDPOINTS =============

// Lấy danh sách nhân viên
app.get('/admin/employees', authenticate, requireAdmin, async (req: any, res) => {
  try {
    const employees = await User
      .find({ role: 'employee' })
      .select('-password')
      .sort({ name: 1 });

    res.json({
      employees,
      total: employees.length
    });
  } catch (err) {
    console.error('Get employees error:', err);
    res.status(500).json({ error: 'Lỗi khi lấy danh sách nhân viên' });
  }
});

// Lấy attendance của tất cả nhân viên theo ngày
app.get('/admin/attendance/today', authenticate, requireAdmin, async (req: any, res) => {
  try {
    const { date } = req.query;
    const targetDate = date || new Date().toISOString().split('T')[0];

    const attendance = await Attendance
      .find({ date: targetDate })
      .populate('userId', 'name email');

    res.json({
      date: targetDate,
      attendance,
      total: attendance.length
    });
  } catch (err) {
    console.error('Get admin attendance error:', err);
    res.status(500).json({ error: 'Lỗi khi lấy dữ liệu chấm công' });
  }
});

// Lấy báo cáo attendance theo khoảng thời gian
app.get('/admin/attendance/report', authenticate, requireAdmin, async (req: any, res) => {
  try {
    const { startDate, endDate, userId } = req.query;

    let query: any = {};
    if (startDate || endDate) {
      query.date = {};
      if (startDate) query.date.$gte = startDate;
      if (endDate) query.date.$lte = endDate;
    }
    if (userId) query.userId = userId;

    const attendance = await Attendance
      .find(query)
      .populate('userId', 'name email')
      .sort({ date: -1 });

    res.json({
      data: attendance,
      total: attendance.length,
      filters: { startDate, endDate, userId }
    });
  } catch (err) {
    console.error('Get report error:', err);
    res.status(500).json({ error: 'Lỗi khi lấy báo cáo' });
  }
});

// ============= USER ENDPOINTS =============

// Lấy thông tin user
app.get('/user/profile', authenticate, async (req: any, res) => {
  try {
    const user = await User.findById(req.user.uid).select('-password');
    if (!user) {
      return res.status(404).json({ error: 'Không tìm thấy user' });
    }

    res.json(user);
  } catch (err) {
    console.error('Get profile error:', err);
    res.status(500).json({ error: 'Lỗi khi lấy thông tin user' });
  }
});

// ============= ROUTE ĐĂNG KÝ KHUÔN MẶT - ĐÃ FIX TRÙNG LẶP =============
app.post('/user/register-face', authenticate, async (req: any, res: any) => {
  try {
    const { faceDescriptor } = req.body;
    const userId = req.user.uid;

    // ===== VALIDATION INPUT =====
    if (!faceDescriptor || !Array.isArray(faceDescriptor) || faceDescriptor.length !== 10) {
      return res.status(400).json({ 
        success: false,
        error: 'Dữ liệu khuôn mặt không hợp lệ (phải là mảng đúng 10 số)' 
      });
    }

    // Kiểm tra tất cả giá trị phải là số hợp lệ
    const isValidNumbers = faceDescriptor.every((val: any) => 
      typeof val === 'number' && !isNaN(val) && isFinite(val)
    );
    if (!isValidNumbers) {
      return res.status(400).json({ 
        success: false,
        error: 'Face descriptor chứa giá trị không hợp lệ' 
      });
    }

    // ===== BƯỚC 1: KIỂM TRA TÀI KHOẢN HIỆN TẠI =====
    const currentUser = await User.findById(userId);
    if (!currentUser) {
      return res.status(404).json({ 
        success: false,
        error: 'Không tìm thấy tài khoản' 
      });
    }

    // Kiểm tra đã đăng ký chưa
    if (currentUser.faceDescriptor && 
        Array.isArray(currentUser.faceDescriptor) && 
        currentUser.faceDescriptor.length === 10) {
      return res.status(400).json({ 
        success: false,
        error: 'Tài khoản của bạn đã đăng ký khuôn mặt rồi!',
        message: 'Mỗi tài khoản chỉ được đăng ký 1 lần. Liên hệ admin nếu cần thay đổi.'
      });
    }

    // ===== BƯỚC 2: KIỂM TRA TRÙNG TOÀN CỤC =====
    console.log(`🔍 Đang kiểm tra trùng khuôn mặt cho user ${userId}...`);
    
    // Query chính xác hơn
    const allRegisteredUsers = await User.find({
      _id: { $ne: userId }, // Loại trừ chính user này
      faceDescriptor: { $exists: true, $type: 'array' },
      'faceDescriptor.0': { $exists: true } // Đảm bảo mảng không rỗng
    }).select('_id email name faceDescriptor');

    console.log(`📊 Tìm thấy ${allRegisteredUsers.length} user đã đăng ký khuôn mặt`);

    // Ngưỡng khoảng cách - QUAN TRỌNG!
    const DUPLICATE_THRESHOLD = 50; // ← Ngưỡng chặt chẽ
    const WARNING_THRESHOLD = 70;   // ← Cảnh báo gần trùng

    let closestMatch = null;
    let minDistance = Infinity;

    for (const user of allRegisteredUsers) {
      const savedDescriptor = user.faceDescriptor;
      
      // Kiểm tra tính hợp lệ của descriptor đã lưu
      if (!Array.isArray(savedDescriptor) || savedDescriptor.length !== 10) {
        continue;
      }

      // Tính Euclidean Distance
      let sumSquares = 0;
      for (let i = 0; i < 10; i++) {
        const diff = faceDescriptor[i] - savedDescriptor[i];
        sumSquares += diff * diff;
      }
      const distance = Math.sqrt(sumSquares);

      console.log(`   User ${user._id}: distance = ${distance.toFixed(2)}`);

      // Lưu kết quả gần nhất
      if (distance < minDistance) {
        minDistance = distance;
        closestMatch = {
          userId: user._id,
          email: user.email,
          name: user.name,
          distance: distance
        };
      }

      // PHÁT HIỆN TRÙNG CHẮC CHẮN
      if (distance < DUPLICATE_THRESHOLD) {
        console.log(`⚠️ PHÁT HIỆN TRÙNG! User ${userId} cố đăng ký mặt của User ${user._id}`);
        console.log(`   Khoảng cách: ${distance.toFixed(2)} < ngưỡng ${DUPLICATE_THRESHOLD}`);
        
        return res.status(409).json({ // 409 = Conflict
          success: false,
          error: 'Khuôn mặt này đã được đăng ký cho tài khoản khác!',
          message: 'Mỗi khuôn mặt chỉ được phép dùng cho 1 tài khoản duy nhất để tránh gian lận.',
          details: {
            distance: Math.round(distance * 100) / 100,
            threshold: DUPLICATE_THRESHOLD
          }
        });
      }
    }

    // Cảnh báo nếu gần trùng (log only, vẫn cho phép đăng ký)
    if (minDistance < WARNING_THRESHOLD) {
      console.log(`⚠️ CẢNH BÁO: Khuôn mặt gần trùng! Distance = ${minDistance.toFixed(2)}`);
    }

    // ===== BƯỚC 3: LƯU KHUÔN MẶT MỚI =====
    const result = await User.updateOne(
      { _id: userId },
      { 
        $set: { 
          faceDescriptor: faceDescriptor,
          faceRegisteredAt: new Date()
        }
      }
    );

    if (result.matchedCount === 0) {
      return res.status(404).json({ 
        success: false,
        error: 'Không tìm thấy user để cập nhật' 
      });
    }

    if (result.modifiedCount === 0) {
      return res.status(500).json({ 
        success: false,
        error: 'Không thể lưu dữ liệu khuôn mặt' 
      });
    }

    console.log(`✅ ĐĂNG KÝ KHUÔN MẶT THÀNH CÔNG cho User ${userId}`);
    console.log(`   Descriptor: [${faceDescriptor.slice(0, 3).map((v: number) => v.toFixed(1)).join(', ')}...]`);
    console.log(`   Khoảng cách gần nhất: ${minDistance.toFixed(2)}`);

    return res.json({ 
      success: true,
      message: 'Đăng ký khuôn mặt thành công! Khuôn mặt này đã được bảo vệ chống gian lận.',
      faceRegisteredAt: new Date(),
      info: {
        closestDistance: Math.round(minDistance * 100) / 100,
        totalRegistered: allRegisteredUsers.length
      }
    });

  } catch (err: any) {
    console.error('❌ Lỗi register face:', err);
    return res.status(500).json({ 
      success: false,
      error: 'Lỗi server khi lưu khuôn mặt',
      details: err.message 
    });
  }
});

// Health check
app.get('/health', (req, res) => {
  res.json({
    status: 'OK',
    mongodb: mongoose.connection.readyState === 1 ? 'Connected' : 'Disconnected',
    timestamp: new Date().toISOString()
  });
});
// ============= LEAVE REQUEST ENDPOINTS =============

// Nhân viên gửi đơn xin nghỉ (1 ngày)
app.post('/leave/request', authenticate, async (req: any, res) => {
  try {
    const { date, reason } = req.body; // date: "2025-12-20"
    const userId = req.user.uid;

    if (!date || !reason) {
      return res.status(400).json({ error: 'Vui lòng nhập ngày nghỉ và lý do' });
    }

    const user = await User.findById(userId);
    if (!user) return res.status(404).json({ error: 'Không tìm thấy nhân viên' });

    const newRequest = new LeaveRequest({
  userId,
  email: user.email,
  name: user.name || 'Không có tên', // lấy tên từ user
  date,                            // giữ nguyên String "2025-12-13"
  reason: reason.trim(),
});

    await newRequest.save();

    res.json({ 
      message: 'Gửi đơn xin nghỉ thành công! Đang chờ admin duyệt.',
      request: newRequest
    });
  } catch (err) {
    console.error('Leave request error:', err);
    res.status(500).json({ error: 'Lỗi khi gửi đơn' });
  }
});

// Nhân viên xem danh sách đơn của mình
app.get('/leave/my-requests', authenticate, async (req: any, res) => {
  try {
    const userId = req.user.uid;
    const requests = await LeaveRequest.find({ userId })
      .sort({ createdAt: -1 });

    res.json({ data: requests });
  } catch (err) {
    console.error('Get my requests error:', err);
    res.status(500).json({ error: 'Lỗi khi lấy danh sách đơn' });
  }
});

// Admin xem tất cả đơn (có thể filter pending)
app.get('/admin/leave/requests', authenticate, requireAdmin, async (req: any, res) => {
  try {
    const { status } = req.query;
    let query: any = {};
    if (status) query.status = status;

    const requests = await LeaveRequest.find(query)
      .populate('userId', 'name email')
      .sort({ createdAt: -1 });

    res.json({ data: requests });
  } catch (err) {
    console.error('Admin get leave requests error:', err);
    res.status(500).json({ error: 'Lỗi khi lấy danh sách đơn' });
  }
});

// Admin duyệt / từ chối đơn
app.post('/admin/leave/review', authenticate, requireAdmin, async (req: any, res) => {
  try {
    const { requestId, status } = req.body; // status: 'approved' hoặc 'rejected'

    if (!requestId || !['approved', 'rejected'].includes(status)) {
      return res.status(400).json({ error: 'Thông tin không hợp lệ' });
    }

    const request = await LeaveRequest.findById(requestId);
    if (!request) return res.status(404).json({ error: 'Không tìm thấy đơn' });

    request.status = status;
    request.approvedAt = new Date();

    await request.save();

    res.json({ 
      message: `Đơn đã được ${status === 'approved' ? 'duyệt' : 'từ chối'} thành công!`,
      request
    });
  } catch (err) {
    console.error('Review leave error:', err);
    res.status(500).json({ error: 'Lỗi khi duyệt đơn' });
  }
});

// 404 handler ← ← ← GIỮ NGUYÊN, NHƯNG BÂY GIỜ ROUTE ĐÃ Ở TRÊN
app.use((req, res) => {
  res.status(404).json({ error: 'API endpoint không tồn tại' });
});

// Error handler
app.use((err: any, req: any, res: any, next: any) => {
  console.error('Unhandled error:', err);
  res.status(500).json({ error: 'Lỗi server không xác định' });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Server đang chạy và CHO PHÉP TRUY CẬP TỪ MẠNG LAN`);
  console.log(`   🌐 Từ máy tính này: http://localhost:${PORT}`);
  console.log(`   📱 Từ điện thoại (cùng WiFi): http://192.168.1.9:${PORT}`);
  console.log(`   🔄 Nếu đổi mạng khác → thay IP ở app Flutter thôi!`);
  console.log(`📊 MongoDB URI: ${process.env.MONGODB_URI?.substring(0, 30)}...`);
});