// lib/screens/attendance_history_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart'; // ← DÙNG ApiService ĐỂ GỌI ĐÚNG VÀ LẤY TOKEN TỰ ĐỘNG

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> 
    with AutomaticKeepAliveClientMixin {

  List<Map<String, dynamic>> attendanceList = [];
  bool isLoading = true;
  String selectedMonth = DateFormat('yyyy-MM').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    loadAttendanceHistory();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    loadAttendanceHistory();
  }

  @override
  bool get wantKeepAlive => true;

  Future<void> loadAttendanceHistory() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      // DÙNG ApiService – tự động lấy token + gọi đúng endpoint
      final result = await ApiService.getAttendanceHistory(limit: 60);

      if (result != null && result['data'] != null) {
        final List<dynamic> records = result['data'];

        // Lọc theo tháng hiện tại (giữ nguyên logic của bạn)
        final filtered = records.where((record) {
          final dateStr = record['date'] as String?;
          if (dateStr == null) return false;
          return dateStr.startsWith(selectedMonth);
        }).toList();

        setState(() {
          attendanceList = filtered.cast<Map<String, dynamic>>();
        });
      } else {
        setState(() {
          attendanceList = [];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải lịch sử: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() {
        attendanceList = [];
      });
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  String calculateWorkHours(String? checkIn, String? checkOut) {
    if (checkIn == null || checkOut == null) return '--';
    
    try {
      DateTime inTime = DateTime.parse(checkIn);
      DateTime outTime = DateTime.parse(checkOut);
      Duration diff = outTime.difference(inTime);
      
      int hours = diff.inHours;
      int minutes = diff.inMinutes.remainder(60);
      
      return '${hours}h ${minutes}m';
    } catch (e) {
      return '--';
    }
  }

  String formatDate(String dateStr) {
    try {
      DateTime date = DateFormat('yyyy-MM-dd').parse(dateStr);
      return DateFormat('dd/MM/yyyy - EEEE', 'vi').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  void showMonthPicker() async {
    DateTime now = DateTime.now();
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateFormat('yyyy-MM').parse(selectedMonth),
      firstDate: DateTime(2020),
      lastDate: now,
      initialDatePickerMode: DatePickerMode.year,
    );

    if (picked != null) {
      setState(() {
        selectedMonth = DateFormat('yyyy-MM').format(picked);
      });
      loadAttendanceHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Tính tổng thống kê (giữ nguyên logic của bạn)
    int totalDays = attendanceList.length;
    int completeDays = attendanceList.where((item) => item['checkOut'] != null).length;
    
    Duration totalWorkTime = Duration.zero;
    for (var item in attendanceList) {
      if (item['checkIn'] != null && item['checkOut'] != null) {
        try {
          DateTime checkIn = DateTime.parse(item['checkIn']);
          DateTime checkOut = DateTime.parse(item['checkOut']);
          totalWorkTime += checkOut.difference(checkIn);
        } catch (e) {}
      }
    }
    
    int totalHours = totalWorkTime.inHours;
    int totalMinutes = totalWorkTime.inMinutes.remainder(60);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử chấm công'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: showMonthPicker,
            tooltip: 'Chọn tháng',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue[50],
            child: Column(
              children: [
                Text(
                  'Tháng ${DateFormat('MM/yyyy').format(DateFormat('yyyy-MM').parse(selectedMonth))}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('Số ngày', '$totalDays', Colors.blue),
                    _buildStatItem('Hoàn thành', '$completeDays', Colors.green),
                    _buildStatItem('Tổng giờ', '${totalHours}h ${totalMinutes}m', Colors.orange),
                  ],
                ),
              ],
            ),
          ),
          
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : attendanceList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.event_busy,
                              size: 80,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Chưa có dữ liệu chấm công',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: loadAttendanceHistory,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: attendanceList.length,
                          itemBuilder: (context, index) {
                            var item = attendanceList[index];
                            return _buildAttendanceCard(item);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[700],
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceCard(Map<String, dynamic> item) {
    String checkInStr = '--:--';
    String checkOutStr = '--:--';
    String workHours = '--';
    Color statusColor = Colors.orange;
    String status = 'Chưa hoàn thành';

    if (item['checkIn'] != null) {
      try {
        DateTime checkIn = DateTime.parse(item['checkIn']);
        checkInStr = DateFormat('HH:mm').format(checkIn);
      } catch (e) {
        checkInStr = '--:--';
      }
    }

    if (item['checkOut'] != null) {
      try {
        DateTime checkOut = DateTime.parse(item['checkOut']);
        checkOutStr = DateFormat('HH:mm').format(checkOut);
        workHours = calculateWorkHours(item['checkIn'], item['checkOut']);
        statusColor = Colors.green;
        status = 'Hoàn thành';
      } catch (e) {
        checkOutStr = '--:--';
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    formatDate(item['date'] ?? ''),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTimeItem(
                    Icons.login,
                    'Giờ vào',
                    checkInStr,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildTimeItem(
                    Icons.logout,
                    'Giờ ra',
                    checkOutStr,
                    Colors.red,
                  ),
                ),
                Expanded(
                  child: _buildTimeItem(
                    Icons.access_time,
                    'Tổng',
                    workHours,
                    Colors.blue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeItem(IconData icon, String label, String time, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          time,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}