// backend/src/routes/auth.js
import express from 'express';
import { register } from '../controllers/authController.js';

const router = express.Router();

// Đăng ký
router.post('/register', register);

export default router;