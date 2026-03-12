// lib/screens/manual_checkin_screen.dart
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ManualCheckInScreen extends StatefulWidget {
  final bool isCheckIn;
  
  const ManualCheckInScreen({super.key, required this.isCheckIn});

  @override
  State<ManualCheckInScreen> createState() => _ManualCheckInScreenState();
}

class _ManualCheckInScreenState extends State<ManualCheckInScreen> {
  bool _isLoading = false;

  Future<void> _handleCheckIn() async {
    setState(() => _isLoading = true);
    
    final result = await ApiService.checkin(platform: 'manual');
    
    setState(() => _isLoading = false);

    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Chấm công thành công!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chấm công thất bại!'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isCheckIn ? 'Check In thủ công' : 'Check Out thủ công'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.isCheckIn ? Icons.login : Icons.logout,
                size: 100,
                color: widget.isCheckIn ? Colors.green : Colors.red,
              ),
              const SizedBox(height: 30),
              Text(
                widget.isCheckIn ? 'Xác nhận Check In?' : 'Xác nhận Check Out?',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleCheckIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.isCheckIn ? Colors.green : Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          widget.isCheckIn ? 'Check In' : 'Check Out',
                          style: const TextStyle(fontSize: 18),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}