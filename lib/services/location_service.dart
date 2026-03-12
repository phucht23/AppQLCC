// lib/services/location_service.dart
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  // Tọa độ văn phòng và bán kính cho phép
  static const double officeLat = 10.86767;   // Phân khu đào tạo E1
  static const double officeLng = 106.97150;
  static const double officeRadius = 1000;      // 200 mét (cùng với GEOFENCE_RADIUS)

  // Kiểm tra và yêu cầu quyền vị trí
  static Future<bool> checkAndRequestLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  // Lấy vị trí hiện tại
  static Future<Position?> getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      print('Lỗi lấy vị trí: $e');
      return null;
    }
  }

  // Kiểm tra có trong bán kính không (frontend kiểm tra trước cho UX tốt)
  static bool isInOfficeRange(Position position) {
    double distanceInMeters = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      officeLat,
      officeLng,
    );
    return distanceInMeters <= officeRadius;
  }

  // Trả về khoảng cách để hiển thị
  static double getDistanceFromOffice(Position position) {
    return Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      officeLat,
      officeLng,
    );
  }
}