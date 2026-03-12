// lib/screens/face_checkin_screen.dart
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';

class FaceCheckinScreen extends StatefulWidget {
  const FaceCheckinScreen({super.key});

  @override
  State<FaceCheckinScreen> createState() => _FaceCheckinScreenState();
}

class _FaceCheckinScreenState extends State<FaceCheckinScreen> {
  CameraController? _controller;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  bool _isProcessing = false;
  String _message = 'Đang khởi động camera...';

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    // REQUEST PERMISSION CAMERA TRƯỚC
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      setState(() => _message = 'Cần cấp quyền camera để tiếp tục!');
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cần quyền Camera'),
            content: const Text('App cần quyền truy cập camera để chấm công bằng khuôn mặt. Vui lòng cấp quyền trong Cài đặt.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hủy'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  openAppSettings();
                },
                child: const Text('Mở Cài đặt'),
              ),
            ],
          ),
        );
      }
      return;
    }

    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,// đảm bảo cam trước để nhận diện khuôn mặt 
        orElse: () => cameras.first,
      );

      _controller = CameraController(frontCamera, ResolutionPreset.high);// chuẩn bị cấu hình camera, độ phân giải cao
      await _controller!.initialize();// khởi tạo camera

      if (mounted) {
        setState(() => _message = 'Nhìn vào camera để chấm công');
        _startFaceDetection();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _message = 'Lỗi khởi động camera: $e');
      }
    }
  }

  void _startFaceDetection() async { // nếu k có lệnh này không xử lí dc hình ảnh 
    _controller!.startImageStream((image) async {
      if (_isProcessing) return;
      _isProcessing = true;

      try {
        final inputImage = InputImage.fromBytes(
          bytes: image.planes[0].bytes,
          metadata: InputImageMetadata(
            size: Size(image.width.toDouble(), image.height.toDouble()),
            rotation: InputImageRotationValue.fromRawValue(
              _controller!.description.sensorOrientation,
            ) ?? InputImageRotation.rotation0deg,
            format: InputImageFormat.yuv420,
            bytesPerRow: image.planes[0].bytesPerRow,
          ),
        );

        final faces = await _faceDetector.processImage(inputImage);
        if (faces.isNotEmpty && faces.length == 1) {
          final face = faces.first;
          final descriptor = _extractDescriptor(face);
          if (descriptor.length >= 8) {
            await _verifyAndCheckin(descriptor);
          }
        }
      } catch (e) {
        debugPrint('Lỗi face detection: $e');
      }

      _isProcessing = false;
    });
  }

  List<double> _extractDescriptor(Face face) {
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
      if (landmark != null) {
        descriptor.add(landmark.position.x.toDouble());
        descriptor.add(landmark.position.y.toDouble());
      }
    }
    return descriptor;
  }

  double _euclideanDistance(List<double> a, List<double> b) {
    double sum = 0;
    for (int i = 0; i < a.length; i++) {
      final dx = (a[i] - b[i]).toDouble();
      sum += pow(dx, 2).toDouble();
    }
    return sqrt(sum);
  }

  // ===== HÀM ĐÃ ĐƯỢC CẬP NHẬT THÊM GEOFENCING =====
    Future<void> _verifyAndCheckin(List<double> currentDescriptor) async {
    try {
      // ===== BƯỚC 1: XÁC THỰC KHUÔN MẶT TRƯỚC TIÊN =====
      final userInfo = await ApiService.getUserInfo();
      final userId = userInfo['userId'];
      if (userId == null) {
        _showResult('Không lấy được thông tin người dùng!', Colors.red);
        return;
      }

      final profile = await ApiService.getUserProfile();
      final savedDescriptor = profile?['faceDescriptor'] as List<dynamic>?;

      if (savedDescriptor == null || savedDescriptor.isEmpty) {
        _showResult('Chưa đăng ký khuôn mặt! Vui lòng đăng ký trước.', Colors.red);
        return;
      }

      final faceDistance = _euclideanDistance(
        currentDescriptor,
        savedDescriptor.map((e) => double.parse(e.toString())).toList(),
      );

      if (faceDistance >= 90) {
        _showResult('Khuôn mặt không khớp với dữ liệu đã lưu!', Colors.red);
        return; // DỪNG LUÔN, KHÔNG HỎI GPS NỮA
      }

      // Nếu khuôn mặt khớp → mới tiến hành kiểm tra vị trí
      setState(() {
        _message = 'Khuôn mặt hợp lệ! Đang kiểm tra vị trí...';
      });

      // ===== BƯỚC 2: KIỂM TRA VỊ TRÍ GPS =====
      final hasPermission = await LocationService.checkAndRequestLocationPermission();
      if (!hasPermission) {
        _showResult('Vui lòng bật GPS và cấp quyền vị trí!', Colors.red);
        return;
      }

      final position = await LocationService.getCurrentPosition();
      if (position == null) {
        _showResult('Không thể lấy vị trí GPS. Kiểm tra kết nối!', Colors.red);
        return;
      }

      final inRange = LocationService.isInOfficeRange(position);
      final distance = LocationService.getDistanceFromOffice(position).round();

      if (!inRange) {
        _showResult(
          'Bạn đang ở ngoài vùng chấm công!\n(Cách văn phòng khoảng $distance mét)',
          Colors.red,
        );
        return;
      }

      setState(() {
        _message = 'Vị trí hợp lệ ($distance mét từ văn phòng). Đang chấm công...';
      });

      // ===== BƯỚC 3: GỌI API CHẤM CÔNG =====
      final result = await ApiService.checkin(
        platform: 'camera',
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (result != null && result['success'] == true) {
        _showResult(
          result['message'] ?? 'Chấm công thành công bằng khuôn mặt! ✅',
          Colors.green,
        );
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) Navigator.pop(context, true);
      } else {
        final errorMsg = result?['message'] ?? 'Chấm công thất bại!';
        _showResult(errorMsg, Colors.red);
      }
    } catch (e) {
      debugPrint('Lỗi: $e');
      _showResult('Lỗi không xác định: $e', Colors.red);
    }
  }

  void _showResult(String text, Color color) {
    if (mounted) {
      setState(() => _message = text);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text), backgroundColor: color),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chấm công bằng khuôn mặt')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(_message, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Chấm công bằng khuôn mặt')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller!),
          Center(
            child: Container(
              width: 300,
              height: 400,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.cyanAccent, width: 6),
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            left: 20,
            right: 20,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _manualCaptureAndCheckin,
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : const Icon(Icons.camera_alt, size: 32),
                  label: Text(
                    _isProcessing ? 'Đang xử lý...' : 'Chụp & Chấm công',
                    style: const TextStyle(fontSize: 20),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigoAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // NÚT CHỤP THỦ CÔNG (giữ nguyên)
  Future<void> _manualCaptureAndCheckin() async {
    if (_isProcessing || _controller == null) return;

    setState(() {
      _isProcessing = true;
      _message = 'Đang xử lý khuôn mặt...';
    });

    try {
      await _controller!.stopImageStream();

      final xFile = await _controller!.takePicture();
      final inputImage = InputImage.fromFilePath(xFile.path);
      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        _showResult('Không phát hiện khuôn mặt!', Colors.red);
        _startFaceDetection();
        return;
      }
      if (faces.length > 1) {
        _showResult('Chỉ được 1 khuôn mặt thôi!', Colors.orange);
        _startFaceDetection();
        return;
      }

      final face = faces.first;
      final descriptor = _extractDescriptor(face);

      if (descriptor.length < 8) {
        _showResult('Nhìn thẳng và không che mặt!', Colors.red);
        _startFaceDetection();
        return;
      }

      await _verifyAndCheckin(descriptor);

      _startFaceDetection();
    } catch (e) {
      _showResult('Lỗi camera: $e', Colors.red);
      try {
        _startFaceDetection();
      } catch (_) {}
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _message = 'Nhìn vào camera hoặc bấm nút chụp';
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _faceDetector.close();
    super.dispose();
  }
}