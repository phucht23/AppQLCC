// src/controllers/attendanceController.ts
import { Request, Response } from 'express';
import Attendance from '../models/attendance.model.js';
import { isWithinGeofence } from '../utils/geofence'; // ← Thêm import này

export const checkin = async (req: Request, res: Response): Promise<void> => {
  try {
    const userId = req.user!.uid; // Lấy userId từ middleware auth

    // Lấy latitude và longitude từ body (Flutter sẽ gửi lên)
    const { latitude, longitude } = req.body;

    // === BẮT BUỘC PHẢI GỬI VỊ TRÍ ĐỂ CHẤM CÔNG ===
    if (!latitude || !longitude) {
      res.status(400).json({
        success: false,
        message: 'Vui lòng bật GPS và gửi vị trí hiện tại để chấm công!',
      });
      return;
    }

    // === KIỂM TRA GEOFENCING ===
    const { allowed, distance } = isWithinGeofence(
      parseFloat(latitude as string),
      parseFloat(longitude as string)
    );

    if (!allowed) {
      res.status(403).json({
        success: false,
        message: `Bạn đang ở ngoài vùng cho phép chấm công (cách văn phòng khoảng ${distance}m)`,
      });
      return;
    }

    // === KIỂM TRA ĐÃ CHẤM CÔNG HÔM NAY CHƯA ===
    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);

    const todayEnd = new Date();
    todayEnd.setHours(23, 59, 59, 999);

    const existing = await Attendance.findOne({
      userId,
      checkinTime: { $gte: todayStart, $lte: todayEnd },
    });

    if (existing) {
      res.status(400).json({
        success: false,
        message: 'Bạn đã chấm công vào hôm nay rồi!',
      });
      return;
    }

    // === TẠO BẢN GHI CHẤM CÔNG MỚI ===
    const newAttendance = new Attendance({
      userId,
      platform: req.body.platform || 'mobile',
      photoUrl: req.body.photoUrl || '',
      location: {
        // Lưu tọa độ thực tế của người dùng
        latitude: parseFloat(latitude as string),
        longitude: parseFloat(longitude as string),
      },
      deviceInfo: req.body.deviceInfo || null,
      checkinTime: new Date(),
    });

    await newAttendance.save();

    res.status(200).json({
      success: true,
      message: 'Chấm công thành công!',
      distanceFromOffice: `${distance}m`, // Bonus: trả về khoảng cách để hiển thị ở app
    });
  } catch (error) {
    console.error('Checkin error:', error);
    res.status(500).json({
      success: false,
      message: 'Lỗi server khi chấm công',
    });
  }
};

// Các hàm khác giữ nguyên (nếu có)
export const getTodayStatus = async (req: Request, res: Response): Promise<void> => {
  // Logic của bạn...
};

export const getAttendanceHistory = async (req: Request, res: Response): Promise<void> => {
  // Logic của bạn...
};