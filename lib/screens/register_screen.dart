// lib/screens/register_screen.dart
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'face_registration_screen.dart';        // THÊM DÒNG NÀY
import '../services/api_service.dart';          // THÊM DÒNG NÀY (nếu chưa có

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

    Future<void> handleRegister() async {
    if (passwordController.text != confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mật khẩu xác nhận không khớp!')),
      );
      return;
    }
    if (passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mật khẩu phải có ít nhất 6 ký tự!')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final registerResult = await ApiService.register(
      emailController.text.trim(),
      passwordController.text.trim(),
      nameController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (registerResult == null || registerResult['userId'] == null) {
      String msg = registerResult?['message'] ?? 'Đăng ký thất bại, vui lòng thử lại';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
      return;
    }

    final String userId = registerResult['userId'].toString();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đăng ký thành công! Đang mở camera chụp khuôn mặt...'),
        backgroundColor: Colors.green,
      ),
    );

    final faceSuccess = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FaceRegistrationScreen(userId: userId),
      ),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(faceSuccess == true
              ? 'Đăng ký khuôn mặt thành công! Bạn có thể đăng nhập'
              : 'Bạn đã bỏ qua đăng ký khuôn mặt'),
          backgroundColor: faceSuccess == true ? Colors.green : Colors.orange,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Đăng ký tài khoản")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Icon(Icons.person_add, size: 80, color: Colors.indigo),
            const SizedBox(height: 30),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "Họ và tên",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 15),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: "Mật khẩu",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 15),
            TextField(
              controller: confirmPasswordController,
              decoration: const InputDecoration(
                labelText: "Xác nhận mật khẩu",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : handleRegister,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Đăng ký", style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}