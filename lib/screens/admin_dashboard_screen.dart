// lib/screens/admin_dashboard_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import 'admin_leave_requests_screen.dart'; // ← THÊM DÒNG NÀY

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Map<String, dynamic>? todayReport;
  List<dynamic> employees = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadAdminData();
  }

  Future<void> loadAdminData() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final token = await ApiService.getToken();
      if (token == null) return;

      final reportRes = await http.get(
        Uri.parse('${ApiService.baseUrl}/admin/attendance/today'),
        headers: {'Authorization': 'Bearer $token'},
      );

      final empRes = await http.get(
        Uri.parse('${ApiService.baseUrl}/admin/employees'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (reportRes.statusCode == 200 && empRes.statusCode == 200) {
        final reportData = jsonDecode(reportRes.body);
        final empData = jsonDecode(empRes.body);

        if (mounted) {
          setState(() {
            todayReport = reportData;
            employees = empData['employees'] ?? [];
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải dữ liệu: $e')),
        );
        setState(() => isLoading = false);
      }
    }
  }

  Widget _buildStat(String label, num value, Color color) {
    return Column(
      children: [
        Text('$value', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản trị hệ thống'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadAdminData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      color: Colors.deepPurple.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            const Text('Thống kê hôm nay', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildStat('Đã chấm công', todayReport?['attendance']?.length ?? 0, Colors.green),
                                _buildStat('Chưa chấm công', employees.length - (todayReport?['attendance']?.length ?? 0), Colors.orange),
                                _buildStat('Tổng NV', employees.length, Colors.blue),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 🆕 NÚT DUYỆT ĐƠN NGHỈ PHÉP MỚI
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AdminLeaveRequestsScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.approval, size: 28),
                        label: const Text(
                          'Duyệt đơn nghỉ phép',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          backgroundColor: Colors.deepPurple[600],
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    const Text('Danh sách chấm công hôm nay', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    todayReport?['attendance'] == null || (todayReport!['attendance'] as List).isEmpty
                        ? const Center(child: Text('Chưa có nhân viên nào chấm công hôm nay'))
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: todayReport!['attendance'].length,
                            itemBuilder: (ctx, i) {
                              final att = todayReport!['attendance'][i];
                              final user = att['userId'] is Map ? att['userId'] : {'name': 'Unknown', 'email': ''};
                              return Card(
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.deepPurple,
                                    child: Text(user['name']?.toString().isNotEmpty == true ? user['name'][0].toUpperCase() : '?'),
                                    foregroundColor: Colors.white,
                                  ),
                                  title: Text(user['name'] ?? 'Chưa có tên'),
                                  subtitle: Text(user['email'] ?? ''),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(att['checkIn'] != null ? att['checkIn'].substring(11, 16) : '--:--', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      Text(att['checkOut'] != null ? att['checkOut'].substring(11, 16) : '--:--'),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                    const SizedBox(height: 30),
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: loadAdminData,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Làm mới'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}