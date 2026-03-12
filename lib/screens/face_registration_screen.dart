// lib/screens/face_registration_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import '../services/api_service.dart';
import 'dart:async';

class FaceRegistrationScreen extends StatefulWidget {
  final String userId;
  const FaceRegistrationScreen({required this.userId, super.key});

  @override
  State<FaceRegistrationScreen> createState() => _FaceRegistrationScreenState();
}

class _FaceRegistrationScreenState extends State<FaceRegistrationScreen> {
  CameraController? _controller;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  bool _isProcessing = false;
  String _message = 'Đang khởi động camera...';

  // SỬ DỤNG BASEURL TỪ ApiService ĐỂ TRÁNH HARD CODE
  // Xóa dòng static const String baseUrl = 'http://172.20.10.3:3000';

  @override
  void initState() {
    super.initState();
    _checkPermissionAndInitCamera();
  }

  Future<void> _checkPermissionAndInitCamera() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      _initCamera();
    } else {
      if (mounted) {
        setState(() => _message = 'Vui lòng cấp quyền Camera');
        _showSnackBar('Cần quyền Camera để đăng ký khuôn mặt', Colors.red);
      }
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _message = 'Không tìm thấy camera');
        return;
      }

      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _controller = CameraController(frontCamera, ResolutionPreset.high);
      await _controller!.initialize();

      if (mounted) {
        setState(() => _message = 'Đưa khuôn mặt vào khung và bấm nút chụp');
      }
    } catch (e) {
      if (mounted) setState(() => _message = 'Lỗi khởi động camera: $e');
    }
  }

  Future<void> _registerFace() async {
    if (_isProcessing || _controller == null || !_controller!.value.isInitialized) return;

    setState(() {
      _isProcessing = true;
      _message = 'Đang xử lý khuôn mặt...\n(Vui lòng giữ yên, có thể mất 10-30 giây)';
    });

    try {
      // Dừng stream để giảm lag khi chụp
      //await _controller!.stopImageStream();

      final xFile = await _controller!.takePicture();
      final inputImage = InputImage.fromFilePath(xFile.path);

      // TĂNG TIMEOUT LÊN 30 GIÂY + CATCH LỖI RIÊNG
      final faces = await _faceDetector.processImage(inputImage).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('Xử lý khuôn mặt quá lâu');
        },
      );

      if (faces.isEmpty) {
        _showSnackBar('Không phát hiện khuôn mặt!\nHãy đưa mặt vào khung rõ hơn', Colors.red);
        return;
      }
      if (faces.length > 1) {
        _showSnackBar('Chỉ được 1 khuôn mặt thôi!', Colors.orange);
        return;
      }

      final face = faces.first;
      List<double> descriptor = [];

      final types = [
        FaceLandmarkType.leftEye,
        FaceLandmarkType.rightEye,
        FaceLandmarkType.noseBase,
        FaceLandmarkType.leftMouth,
        FaceLandmarkType.rightMouth,
      ];

      for (final type in types) {
        final landmark = face.landmarks[type];
        if (landmark == null) {
          _showSnackBar('Mặt nghiêng quá hoặc che khuất!\nCần thấy rõ 2 mắt + mũi + miệng', Colors.red);
          return;
        }
        descriptor.add(landmark.position.x.toDouble());
        descriptor.add(landmark.position.y.toDouble());
      }

      if (descriptor.length != 10) {
        _showSnackBar('Dữ liệu khuôn mặt không đủ, thử lại!', Colors.red);
        return;
      }

      // LẤY TOKEN TỪ ApiService (an toàn hơn)
      final token = await ApiService.getToken();
      if (token == null || token.isEmpty) {
        _showSnackBar('Không tìm thấy token! Vui lòng đăng nhập lại', Colors.red);
        return;
      }

      // SỬ DỤNG ApiService.baseUrl THAY VÌ HARD CODE
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/user/register-face'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'faceDescriptor': descriptor,
        }),
      );

      if (response.statusCode == 200) {
        _showSnackBar('Đăng ký khuôn mặt THÀNH CÔNG!', Colors.green);
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) Navigator.pop(context, true);
      } else {
        _showSnackBar('Lỗi server: ${response.statusCode}\n${response.body}', Colors.red);
      }
    } on TimeoutException catch (_) {
      _showSnackBar(
        'Xử lý quá lâu!\n'
        'Vui lòng thử lại với:\n'
        '- Ánh sáng tốt hơn\n'
        '- Nhìn thẳng camera\n'
        '- Giữ mặt yên trong khung',
        Colors.orange,
      );
    } catch (e) {
      debugPrint('Lỗi đăng ký khuôn mặt: $e');
      _showSnackBar('Lỗi kết nối hoặc xử lý: $e', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _message = 'Đưa khuôn mặt vào khung và bấm nút chụp';
        });
      }
      // Khởi động lại stream nếu cần (nếu bạn có stream như face_checkin)
      // await _controller!.startImageStream(...);
    }
  }

  void _showSnackBar(String text, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: color,
        duration: const Duration(seconds: 6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Đăng ký khuôn mặt')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(_message, style: const TextStyle(fontSize: 18), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Đăng ký khuôn mặt')),
      body: Stack(
        children: [
          CameraPreview(_controller!),
          Center(
            child: Container(
              width: 300,
              height: 400,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.lightGreenAccent, width: 6),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Center(
                child: Text(
                  'Đặt mặt vào đây',
                  style: TextStyle(color: Colors.white, fontSize: 20, shadows: [
                    Shadow(blurRadius: 10, color: Colors.black)
                  ]),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            left: 20,
            right: 20,
            child: Column(
              children: [
                Text(_message, style: const TextStyle(color: Colors.white, fontSize: 18, shadows: [
                  Shadow(blurRadius: 10, color: Colors.black)
                ]), textAlign: TextAlign.center),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _registerFace,
                  icon: _isProcessing
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Icon(Icons.camera_alt, size: 30),
                  label: Text(_isProcessing ? 'Đang xử lý...' : 'Chụp & Đăng ký', style: const TextStyle(fontSize: 18)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _faceDetector.close();
    super.dispose();
  }
}