import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';  // ← THÊM DÒNG NÀY!!!
import 'register_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  void handleLogin() async {
  final email = emailController.text.trim();
  final password = passwordController.text.trim();

  if (email.isEmpty || password.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vui lòng nhập email và mật khẩu')),
    );
    return;
  }

  // DÙNG TRỰC TIẾP ApiService.login → BẮT BUỘC LƯU TOKEN VÀO SharedPreferences
  final data = await ApiService.login(email, password);

  if (data != null) {
    print('ĐĂNG NHẬP THÀNH CÔNG – TOKEN ĐÃ LƯU: ${data['token']}');
    print('User ID: ${data['userId']}');

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Email hoặc mật khẩu sai')),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Đăng nhập")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: "Mật khẩu"),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: handleLogin,
              child: const Text("Đăng nhập"),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => RegisterScreen()),
                );
              },
              child: const Text("Chưa có tài khoản? Đăng ký"),
            )
          ],
        ),
      ),
    );
  }
}
