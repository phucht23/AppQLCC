import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart'; // ← ĐÃ THÊM

class LeaveRequestScreen extends StatefulWidget {
  const LeaveRequestScreen({super.key});

  @override
  State<LeaveRequestScreen> createState() => _LeaveRequestScreenState();
}

class _LeaveRequestScreenState extends State<LeaveRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  DateTime? _selectedDate;
  final _reasonController = TextEditingController();
  bool _isLoading = false;

  //static const String baseUrl = 'http://172.20.10.3:3000'; // ← THAY BẰNG IP MÁY TÍNH CỦA BẠN (như lịch sử chấm công)

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ngày nghỉ')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final token = await _getToken();
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chưa đăng nhập')),
        );
        return;
      }

      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/leave/request'), // ← ĐÃ SỬA
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'date': DateFormat('yyyy-MM-dd').format(_selectedDate!),
          'reason': _reasonController.text.trim(),
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Gửi đơn thành công!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // quay về Home
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['error'] ?? 'Gửi đơn thất bại'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi kết nối: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Xin nghỉ phép'),
        backgroundColor: Colors.orange[700],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Chọn ngày nghỉ
              ListTile(
                title: Text(
                  _selectedDate == null
                      ? 'Chọn ngày nghỉ'
                      : 'Ngày nghỉ: ${DateFormat('dd/MM/yyyy (EEEE)', 'vi').format(_selectedDate!)}',
                  style: const TextStyle(fontSize: 18),
                ),
                trailing: const Icon(Icons.calendar_today),
                tileColor: Colors.grey[100],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                  }
                },
              ),
              const SizedBox(height: 20),

              // Lý do nghỉ
              TextFormField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: 'Lý do nghỉ *',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập lý do nghỉ';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),

              // Nút gửi đơn
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'GỬI ĐƠN XIN NGHỈ',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }
}