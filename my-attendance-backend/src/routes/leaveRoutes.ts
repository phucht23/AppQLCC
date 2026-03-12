import express from 'express';
import { authenticate } from '../middlewares/authenticate.js';
const { requireAdmin } = require('../middlewares/requireAdmin.js');
import { 
  createLeave,
  getLeaveHistory,
  adminGetAllLeaves,
  adminUpdateLeave
} from '../controllers/leaveController.js';

const router = express.Router();

// ================= USER ROUTES =================

// Gửi đơn xin nghỉ
router.post('/', authenticate, createLeave);

// Lấy lịch sử đơn nghỉ của user
router.get('/history', authenticate, getLeaveHistory);

// ================= ADMIN ROUTES =================

// Lấy toàn bộ đơn nghỉ
router.get('/admin/list', authenticate, requireAdmin, adminGetAllLeaves);

// Cập nhật trạng thái đơn nghỉ
router.post('/admin/update', authenticate, requireAdmin, adminUpdateLeave);

export default router;
