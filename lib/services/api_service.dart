// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;

class ApiService {
  // ⚠️ ĐỔI IP NÀY CHO ĐÚNG VỚI MÁY TÍNH CHẠY SERVER CỦA BẠN
  static String get baseUrl {
    if (Platform.isAndroid || Platform.isIOS) {
      return 'http://192.168.1.210:3000'; // IP máy tính của bạn khi chạy trên điện thoại thật
    }
    return 'http://127.0.0.1:3000'; // khi chạy trên emulator hoặc web
  }

  // ============= AUTH =============

  static Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['token']);
        await prefs.setString('userId', data['userId']);
        await prefs.setString('userName', data['name'] ?? '');
        await prefs.setString('userEmail', data['email'] ?? '');
        await prefs.setString('userRole', data['role'] ?? 'employee');
        return data;
      }
      return null;
    } catch (e) {
      print('Login error: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> register(String email, String password, String name) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'name': name,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Register error: $e');
      return null;
    }
  }

  // ============= ATTENDANCE =============

  static Future<Map<String, dynamic>?> checkin({
    String platform = 'mobile',
    String photoUrl = '',
    double? latitude,
    double? longitude,
    Map<String, dynamic>? deviceInfo,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) return null;

      final Map<String, dynamic> body = {
        'platform': platform,
        'photoUrl': photoUrl,
        if (deviceInfo != null) 'deviceInfo': deviceInfo,
      };

      if (latitude != null && longitude != null) {
        body['latitude'] = latitude;
        body['longitude'] = longitude;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/checkin'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 400 || response.statusCode == 403) {
        return jsonDecode(response.body);
      }

      print('Checkin unexpected status: ${response.statusCode} - ${response.body}');
      return null;
    } catch (e) {
      print('Checkin exception: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getTodayStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/attendance/today'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Get today status error: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getAttendanceHistory({
    int limit = 30,
    int skip = 0,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) return null;

      var url = '$baseUrl/attendance/history?limit=$limit&skip=$skip';
      if (startDate != null) url += '&startDate=$startDate';
      if (endDate != null) url += '&endDate=$endDate';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Get history error: $e');
      return null;
    }
  }

  // ============= USER =============

  static Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/user/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Get profile error: $e');
      return null;
    }
  }

  // ============= LEAVE REQUESTS (3 HÀM MỚI) =============

  /// Nhân viên xem đơn nghỉ phép của mình
  static Future<Map<String, dynamic>?> getMyLeaveRequests() async {
    try {
      final token = await getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/leave/my-requests'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Get my leave requests error: $e');
      return null;
    }
  }

  /// Admin xem tất cả đơn nghỉ phép
  static Future<Map<String, dynamic>?> getAdminLeaveRequests() async {
    try {
      final token = await getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/admin/leave/requests'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Get admin leave requests error: $e');
      return null;
    }
  }

  /// Admin duyệt/từ chối đơn
  static Future<Map<String, dynamic>?> reviewLeaveRequest(
    String requestId,
    String status, // 'approved' hoặc 'rejected'
    String note,
  ) async {
    try {
      final token = await getToken();
      if (token == null) return null;

      final response = await http.post(
        Uri.parse('$baseUrl/admin/leave/review'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'requestId': requestId,
          'status': status,
          'note': note,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Review leave request error: $e');
      return null;
    }
  }

  // ============= HELPERS =============

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  static Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userRole');
  }

  static Future<Map<String, String?>> getUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'userId': prefs.getString('userId'),
      'userName': prefs.getString('userName'),
      'userEmail': prefs.getString('userEmail'),
      'userRole': prefs.getString('userRole'),
    };
  }
}