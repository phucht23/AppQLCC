// lib/screens/my_leave_requests_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart'; // ← DÙNG ApiService ĐỂ GỌI ĐÚNG

class MyLeaveRequestsScreen extends StatefulWidget {
  const MyLeaveRequestsScreen({super.key});

  @override
  State<MyLeaveRequestsScreen> createState() => _MyLeaveRequestsScreenState();
}

class _MyLeaveRequestsScreenState extends State<MyLeaveRequestsScreen> {
  List<dynamic> requests = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadMyRequests();
  }

  Future<void> loadMyRequests() async {
    setState(() => isLoading = true);

    try {
      // DÙNG ApiService – tự động thêm token + gọi đúng endpoint
      final result = await ApiService.getMyLeaveRequests();

      if (result != null && result['data'] != null) {
        setState(() {
          requests = result['data'];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải đơn: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  String getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Đang chờ duyệt';
      case 'approved':
        return 'Đã duyệt';
      case 'rejected':
        return 'Bị từ chối';
      default:
        return status;
    }
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đơn nghỉ phép của tôi'),
        backgroundColor: Colors.orange[700],
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : requests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_busy, size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      const Text(
                        'Chưa có đơn xin nghỉ nào',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: loadMyRequests,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      final req = requests[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 3,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Ngày nghỉ: ${req['date']}',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: getStatusColor(req['status']).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: getStatusColor(req['status'])),
                                    ),
                                    child: Text(
                                      getStatusText(req['status']),
                                      style: TextStyle(
                                        color: getStatusColor(req['status']),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('Lý do: ${req['reason']}'),
                              const SizedBox(height: 8),
                              Text(
                                'Gửi ngày: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(req['createdAt']))}',
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}