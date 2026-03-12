// lib/services/auth_service.dart
import 'api_service.dart';

class AuthService {
  Future<String?> login(String email, String password) async {
    final result = await ApiService.login(email, password);
    if (result != null) return null; // thành công
    return 'Sai email hoặc mật khẩu';
  }

  Future<String?> register(String email, String password, String name) async {
    final result = await ApiService.register(email, password, name);
    if (result != null) {
      return null; // thành công
    } else {
      return 'Đăng ký thất bại';
    }
  }

  Future<void> signOut() async {
    await ApiService.logout();
  }
}