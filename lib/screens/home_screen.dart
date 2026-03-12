// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'attendance_history_screen.dart';
import 'login_screen.dart';
import 'manual_checkin_screen.dart';
import 'qr_generator_screen.dart';
import 'admin_dashboard_screen.dart';
import 'settings_screen.dart';
import 'calendar_screen.dart';
import 'qr_scanner_screen.dart';
import 'face_registration_screen.dart';
import 'face_checkin_screen.dart';
import 'leave_request_screen.dart';
import 'my_leave_requests_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  
  Map<String, dynamic>? userData;
  Map<String, dynamic>? todayAttendance;
  bool isLoading = true;
  bool isAdmin = false;
  
  String checkInTime = '--:--';
  String checkOutTime = '--:--';
  String totalHours = '0h';
  String currentTime = '';

  @override
  void initState() {
    super.initState();
    loadUserData();
    _updateTime();
  }

  void _updateTime() {
    setState(() {
      currentTime = DateFormat('HH:mm:ss - dd/MM/yyyy', 'vi_VN').format(DateTime.now());
    });
    Future.delayed(const Duration(seconds: 1), _updateTime);
  }

  Future<void> loadUserData() async {
    setState(() => isLoading = true);
    
    final userInfo = await ApiService.getUserInfo();
    final role = userInfo['userRole'] ?? 'employee';
    final profile = await ApiService.getUserProfile();
    
    setState(() {
      userData = profile;
      isAdmin = role == 'admin';
    });
    
    await loadTodayAttendance();
    setState(() => isLoading = false);
  }

  Future<void> loadTodayAttendance() async {
    final result = await ApiService.getTodayStatus();
    
    if (result != null) {
      setState(() {
        todayAttendance = result;
        
        final attendance = result['attendance'];
        if (attendance != null) {
          if (attendance['checkIn'] != null) {
            DateTime checkIn = DateTime.parse(attendance['checkIn']);
            checkInTime = DateFormat('HH:mm:ss').format(checkIn);
          } else {
            checkInTime = '--:--:--';
          }
          
          if (attendance['checkOut'] != null) {
            DateTime checkOut = DateTime.parse(attendance['checkOut']);
            checkOutTime = DateFormat('HH:mm:ss').format(checkOut);
            
            if (attendance['checkIn'] != null) {
              DateTime checkIn = DateTime.parse(attendance['checkIn']);
              Duration diff = checkOut.difference(checkIn);
              int hours = diff.inHours;
              int minutes = diff.inMinutes.remainder(60);
              totalHours = '${hours}h ${minutes}m';
            }
          } else {
            checkOutTime = '--:--:--';
          }
        } else {
          checkInTime = '--:--:--';
          checkOutTime = '--:--:--';
          totalHours = '0h';
        }
      });
    }
  }

  Future<void> handleCheckIn() async {
    setState(() => isLoading = true);
    final result = await ApiService.checkin();
    setState(() => isLoading = false);

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Chấm công thành công!')),
      );
      await loadTodayAttendance();
      setState(() {});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chấm công thất bại!')),
      );
    }
  }

  Future<void> logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận'),
        content: const Text('Bạn có chắc muốn đăng xuất?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Đăng xuất', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authService.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final hasCheckedIn = todayAttendance?['hasCheckedIn'] ?? false;
    final hasCheckedOut = todayAttendance?['hasCheckedOut'] ?? false;

        return Scaffold(
      appBar: AppBar(
        title: const Text('Chấm Công QR'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: 'Lịch làm việc',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CalendarScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            tooltip: 'Cài đặt',
          ),
          IconButton(
  icon: const Icon(Icons.face_retouching_natural),
  onPressed: () async {
    final userInfo = await ApiService.getUserInfo();
    final userId = userInfo['userId'];
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không lấy được ID người dùng')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FaceRegistrationScreen(userId: userId),
      ),
    );
  },
  tooltip: 'Đăng ký khuôn mặt',
),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: logout,
            tooltip: 'Đăng xuất',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadTodayAttendance,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildUserInfoCard(),
              const SizedBox(height: 20),
              _buildTimeCard(),
              const SizedBox(height: 20),
              _buildAttendanceButtons(hasCheckedIn, hasCheckedOut),
              const SizedBox(height: 20),
              _buildTodayAttendance(),
            ],
          ),
        ),
      ),
      // THÊM DẤU PHẨY Ở ĐÂY + ĐÓNG NGOẶC ĐÚNG CHỖ
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Nút Quét QR – luôn hiện
          FloatingActionButton(
            heroTag: "scanQR",
            backgroundColor: Colors.deepOrange,
            tooltip: 'Quét mã QR chấm công',
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const QRScannerScreen()),
              );
              if (result == true) {
      await loadTodayAttendance();
      setState(() {});                 // ← đây là dòng bạn cần thêm
    }
            },
            child: const Icon(Icons.qr_code_scanner, size: 30),
          ),
          const SizedBox(width: 16),
          // Nút Admin hoặc Tạo QR (giữ nguyên logic cũ)
          isAdmin
              ? FloatingActionButton.extended(
                  heroTag: "admin",
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDashboardScreen())),
                  icon: const Icon(Icons.admin_panel_settings),
                  label: const Text('Admin'),
                  backgroundColor: Colors.deepPurple,
                )
              : FloatingActionButton.extended(
                  heroTag: "createQR",
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QRGeneratorScreen())),
                  icon: const Icon(Icons.qr_code),
                  label: const Text('Tạo mã QR'),
                  backgroundColor: Colors.purple,
                ),
        ],
      ), // kết thúc floatingActionButton
    ); // kết thúc Scaffold và build()
  }

  Widget _buildUserInfoCard() {
    final userName = userData?['name'] ?? 'Người dùng';
    final userEmail = userData?['email'] ?? '';

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: isAdmin ? Colors.deepPurple : Colors.blue,
              child: Text(
                userName.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isAdmin) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'ADMIN',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    userEmail,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeCard() {
    return Card(
      color: Colors.indigo.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.access_time, size: 50, color: Colors.indigo),
            const SizedBox(height: 10),
            Text(
              currentTime,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceButtons(bool hasCheckedIn, bool hasCheckedOut) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton.icon(
            onPressed: hasCheckedIn && hasCheckedOut ? null : handleCheckIn,
            icon: Icon(hasCheckedIn ? Icons.logout : Icons.login, size: 28),
            label: Text(
              hasCheckedIn && hasCheckedOut
                  ? 'Đã hoàn thành chấm công hôm nay'
                  : hasCheckedIn
                      ? 'Check Out'
                      : 'Check In',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: hasCheckedIn && hasCheckedOut
                  ? Colors.grey
                  : hasCheckedIn
                      ? Colors.orange[600]
                      : Colors.green[600],
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AttendanceHistoryScreen(),
                ),
              );
            },
            icon: const Icon(Icons.history, size: 28),
            label: const Text(
              'Lịch sử chấm công',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 20),
            ),
          ),
        ),

        // 🆕 THÊM NÚT FACE CHECK-IN Ở ĐÂY
const SizedBox(height: 16),
SizedBox(
  width: double.infinity,
  child: ElevatedButton.icon(
    onPressed: () async{
      final result = await Navigator.push(  // Thêm await và final result
        context,
        MaterialPageRoute(
          builder: (_) => const FaceCheckinScreen(),
        ),
      );
      // REFRESH DỮ LIỆU KHI QUAY VỀ TỪ FACE CHECK-IN
      if (result == true) {
        await loadTodayAttendance();
        setState(() {});
      } 
    },
    icon: const Icon(Icons.face_retouching_natural, size: 28),
    label: const Text(
      'Chấm công bằng khuôn mặt',
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    ),
    style: ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 20),
      backgroundColor: Colors.blueAccent,
      foregroundColor: Colors.white,
    ),
  ),
),
// 🆕 NÚT XIN NGHỈ PHÉP MỚI
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LeaveRequestScreen()),
              );
            },
            icon: const Icon(Icons.beach_access, size: 28),
            label: const Text(
              'Xin nghỉ phép',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 20),
              backgroundColor: Colors.orange[700],
              foregroundColor: Colors.white,
            ),
          ),
        ),
        //Xem đơn nghỉ phép
        const SizedBox(height: 16),
SizedBox(
  width: double.infinity,
  child: OutlinedButton.icon(
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MyLeaveRequestsScreen()),
      );
    },
    icon: const Icon(Icons.list_alt, size: 28),
    label: const Text(
      'Xem đơn nghỉ phép của tôi',
      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    ),
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 20),
    ),
  ),
),
      ],
    );
  }

  Widget _buildTodayAttendance() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Chấm công hôm nay',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTimeInfo('Giờ vào', checkInTime, Colors.green),
                _buildTimeInfo('Giờ ra', checkOutTime, Colors.red),
                _buildTimeInfo('Tổng giờ', totalHours, Colors.blue),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeInfo(String label, String time, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          time,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}