import 'package:flutter/material.dart';
import '../services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool isNotificationEnabled = false;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    checkNotificationStatus();
  }

  Future<void> checkNotificationStatus() async {
    final pending = await NotificationService().getPendingNotifications();
    setState(() {
      isNotificationEnabled = pending.isNotEmpty;
      isLoading = false;
    });
  }

  Future<void> toggleNotifications(bool value) async {
    setState(() {
      isLoading = true;
    });

    if (value) {
      await NotificationService().enableAllReminders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Đã bật nhắc nhở check in/out'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      await NotificationService().disableAllReminders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔕 Đã tắt nhắc nhở'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }

    await checkNotificationStatus();
  }

  Future<void> testNotification() async {
    await NotificationService().showTestNotification();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('📱 Đã gửi thông báo test')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text(
                    'Nhắc nhở chấm công',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('Nhận thông báo lúc 8:00 AM và 17:00 PM'),
                  value: isNotificationEnabled,
                  onChanged: isLoading ? null : toggleNotifications,
                  secondary: const Icon(Icons.notifications_active),
                ),
                if (isNotificationEnabled) ...[
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.alarm, color: Colors.green),
                    title: const Text('Check In'),
                    subtitle: const Text('8:00 AM hàng ngày'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.alarm, color: Colors.red),
                    title: const Text('Check Out'),
                    subtitle: const Text('17:00 PM hàng ngày'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.bug_report, color: Colors.orange),
              title: const Text('Test thông báo'),
              subtitle: const Text('Gửi thông báo thử ngay'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: testNotification,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Text(
                      'Lưu ý',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('• Nhắc nhở sẽ lặp lại hàng ngày'),
                const Text('• Cần cho phép quyền thông báo'),
                const Text('• Hoạt động ngay cả khi app đóng'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}