import 'dart:math';
import 'package:location/location.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final Location _location = Location();
  LocationData? _currentPosition;
  bool _isLocationEnabled = false;
  
  // Getters
  LocationData? get currentPosition => _currentPosition;
  bool get isLocationEnabled => _isLocationEnabled;
  double? get latitude => _currentPosition?.latitude;
  double? get longitude => _currentPosition?.longitude;

  // 위치 공유 설정 로드
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isLocationEnabled = prefs.getBool('location_sharing_enabled') ?? false;
    
    if (_isLocationEnabled) {
      await getCurrentLocation();
    }
  }

  // 위치 공유 설정 토글
  Future<bool> toggleLocationSharing(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('location_sharing_enabled', enabled);
    _isLocationEnabled = enabled;
    
    if (enabled) {
      return await getCurrentLocation() != null;
    }
    
    _currentPosition = null;
    return true;
  }

  // 위치 권한 확인 및 요청
  Future<bool> checkAndRequestPermission() async {
    bool serviceEnabled;
    PermissionStatus permissionGranted;

    // 위치 서비스 활성화 확인
    serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        print('🔴 위치 서비스가 비활성화됨');
        return false;
      }
    }

    // 권한 확인
    permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        print('🔴 위치 권한이 거부됨');
        return false;
      }
    }

    return true;
  }

  // 현재 위치 가져오기
  Future<LocationData?> getCurrentLocation() async {
    try {
      final hasPermission = await checkAndRequestPermission();
      if (!hasPermission) return null;

      _currentPosition = await _location.getLocation();
      
      print('🟢 위치 획득: ${_currentPosition?.latitude}, ${_currentPosition?.longitude}');
      return _currentPosition;
    } catch (e) {
      print('🔴 위치 획득 실패: $e');
      return null;
    }
  }

  // 두 좌표 간의 거리 계산 (Haversine 공식, km 단위)
  static double calculateDistance(
    double lat1, double lon1,
    double lat2, double lon2,
  ) {
    const double earthRadius = 6371; // 지구 반지름 (km)
    
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }

  static double _toRadians(double degree) {
    return degree * pi / 180;
  }

  // 거리를 사용자 친화적인 문자열로 변환
  static String formatDistance(double distanceKm) {
    if (distanceKm < 1) {
      return '1km 이내';
    } else if (distanceKm < 5) {
      return '약 ${distanceKm.round()}km';
    } else if (distanceKm < 10) {
      return '약 5~10km';
    } else if (distanceKm < 30) {
      return '약 10~30km';
    } else if (distanceKm < 50) {
      return '약 30~50km';
    } else if (distanceKm < 100) {
      return '약 50~100km';
    } else {
      return '100km 이상';
    }
  }

  // 상대방과의 거리 계산
  String? getDistanceFrom(double? partnerLat, double? partnerLon) {
    if (_currentPosition == null || partnerLat == null || partnerLon == null) {
      return null;
    }

    if (_currentPosition!.latitude == null || _currentPosition!.longitude == null) {
      return null;
    }

    final distance = calculateDistance(
      _currentPosition!.latitude!,
      _currentPosition!.longitude!,
      partnerLat,
      partnerLon,
    );

    return formatDistance(distance);
  }
  
  // 위치 정보를 Map으로 반환 (서버 전송용)
  Map<String, dynamic>? getLocationData() {
    if (_currentPosition == null || !_isLocationEnabled) {
      return null;
    }
    
    if (_currentPosition!.latitude == null || _currentPosition!.longitude == null) {
      return null;
    }
    
    return {
      'latitude': _currentPosition!.latitude,
      'longitude': _currentPosition!.longitude,
    };
  }
}
