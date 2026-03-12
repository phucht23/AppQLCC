// lib/screens/qr_scanner_screen.dart
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/api_service.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  MobileScannerController controller = MobileScannerController();
  bool _isProcessing = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _handleQRCode(String qrData) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    // Kiểm tra QR code hợp lệ
    if (qrData.toLowerCase().contains('checkin') || 
        qrData.toLowerCase().contains('chamcong')) {
      
      final result = await ApiService.checkin(platform: 'qr');
      
      if (result != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Chấm công thành công!'),
            backgroundColor: Colors.green,
          ),
        );
        
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chấm công thất bại!'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isProcessing = false);
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mã QR không hợp lệ!'),
          backgroundColor: Colors.orange,
        ),
      );
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
  title: const Text('Quét mã QR'),
  backgroundColor: Colors.black,
  actions: [
  // NÚT ĐÈN FLASH – CHẠY NGON 100% VỚI MOBILE_SCANNER 5.2.3 → 6.x
  ValueListenableBuilder(
    valueListenable: controller,
    builder: (context, state, child) {
      return IconButton(
        icon: Icon(
          state.torchState == TorchState.on ? Icons.flash_on : Icons.flash_off,
          color: state.torchState == TorchState.on ? Colors.yellow : Colors.white,
        ),
        onPressed: () => controller.toggleTorch(),
      );
    },
  ),

  // NÚT ĐẢO CAMERA
  IconButton(
    icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
    onPressed: () => controller.switchCamera(),
  ),
],
),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final String? code = barcode.rawValue;
                if (code != null && !_isProcessing) {
                  _handleQRCode(code);
                  break;
                }
              }
            },
          ),
          
          // Khung quét
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          
          // Hướng dẫn
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              child: const Text(
                'Đưa mã QR vào khung để quét',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  backgroundColor: Colors.black54,
                ),
              ),
            ),
          ),
          
          // Loading
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}