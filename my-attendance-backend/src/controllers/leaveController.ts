import { Request, Response } from 'express';
import LeaveRequest from '../models/leave_request.model.js';

interface AuthRequest extends Request {
  user?: {
    uid: string;
    email: string;
    role: string;
  };
}

// User tạo đơn xin nghỉ
export const createLeave = async (req: AuthRequest, res: Response) => {
  try {
    const { reason, date } = req.body;

    if (!date) {
      return res.status(400).json({ error: "Ngày nghỉ là bắt buộc" });
    }

    const leave = await LeaveRequest.create({
      userId: req.user?.uid,
      email: req.user?.email,
      reason: reason || '',
      date
    });

    res.json({ message: "Gửi đơn xin nghỉ thành công", data: leave });
  } catch (err) {
    console.error("Create leave error:", err);
    res.status(500).json({ error: "Lỗi gửi đơn nghỉ" });
  }
};

// Lấy lịch sử đơn nghỉ của user
export const getLeaveHistory = async (req: AuthRequest, res: Response) => {
  try {
    const list = await LeaveRequest.find({ userId: req.user?.uid }).sort({ createdAt: -1 });
    res.json(list);
  } catch (err) {
    console.error("Get leave history error:", err);
    res.status(500).json({ error: "Lỗi lấy lịch sử nghỉ" });
  }
};

// Admin: lấy toàn bộ đơn nghỉ
export const adminGetAllLeaves = async (_req: Request, res: Response) => {
  try {
    const list = await LeaveRequest.find()
      .populate("userId", "name email")
      .sort({ createdAt: -1 });

    res.json(list);
  } catch (err) {
    console.error("Admin get all leaves error:", err);
    res.status(500).json({ error: "Lỗi lấy danh sách" });
  }
};

// Admin: cập nhật trạng thái đơn nghỉ
export const adminUpdateLeave = async (req: Request, res: Response) => {
  try {
    const { id, status } = req.body;

    if (!id || !status) {
      return res.status(400).json({ error: "ID và trạng thái là bắt buộc" });
    }

    const updated = await LeaveRequest.findByIdAndUpdate(
      id,
      { status, approvedAt: new Date() },
      { new: true }
    );

    res.json({ message: "Cập nhật thành công", data: updated });
  } catch (err) {
    console.error("Admin update leave error:", err);
    res.status(500).json({ error: "Lỗi cập nhật đơn" });
  }
};
