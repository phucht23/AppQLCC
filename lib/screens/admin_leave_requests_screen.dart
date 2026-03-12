// lib/screens/admin_leave_requests_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart'; // ← DÙNG ApiService

class AdminLeaveRequestsScreen extends StatefulWidget {
  const AdminLeaveRequestsScreen({super.key});

  @override
  State<AdminLeaveRequestsScreen> createState() => _AdminLeaveRequestsScreenState();
}

class _AdminLeaveRequestsScreenState extends State<AdminLeaveRequestsScreen> {
  List<dynamic> requests = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadRequests();
  }

  Future<void> loadRequests() async {
    setState(() => isLoading = true);

    try {
      // DÙNG ApiService – tự động thêm token + gọi đúng endpoint
      final result = await ApiService.getAdminLeaveRequests(); // giả sử bạn thêm hàm này

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

  Future<void> reviewRequest(String requestId, String status, String note) async {
    try {
      final result = await ApiService.reviewLeaveRequest(requestId, status, note);

      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã ${status == 'approved' ? 'duyệt' : 'từ chối'} đơn thành công!'),
            backgroundColor: Colors.green,
          ),
        );
        loadRequests(); // reload danh sách
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lỗi xử lý'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lỗi kết nối'), backgroundColor: Colors.red),
      );
    }
  }

  void showReviewDialog(dynamic request) {
    final noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Xử lý đơn của ${request['userId']['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ngày nghỉ: ${request['date']}'),
            Text('Lý do: ${request['reason']}'),
            const SizedBox(height: 10),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: 'Ghi chú (tùy chọn)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              reviewRequest(request['_id'], 'rejected', noteController.text);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Từ chối'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              reviewRequest(request['_id'], 'approved', noteController.text);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Duyệt'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Duyệt đơn nghỉ phép'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : requests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_note, size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      const Text(
                        'Chưa có đơn xin nghỉ nào',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: loadRequests,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      final req = requests[index];
                      final user = req['userId'];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 3,
                        child: ListTile(
                          title: Text(user['name'] ?? user['email']),
                          subtitle: Text('Ngày: ${req['date']}\nLý do: ${req['reason']}'),
                          trailing: req['status'] == 'pending'
                              ? ElevatedButton(
                                  onPressed: () => showReviewDialog(req),
                                  child: const Text('Xử lý'),
                                )
                              : Text(
                                  req['status'] == 'approved' ? 'Đã duyệt' : 'Đã từ chối',
                                  style: TextStyle(
                                    color: req['status'] == 'approved' ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}