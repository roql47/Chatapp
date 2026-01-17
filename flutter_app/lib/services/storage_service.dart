import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import '../config/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  final ImagePicker _picker = ImagePicker();

  // 갤러리에서 이미지 선택
  Future<File?> pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 80,
      );
      
      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      print('이미지 선택 오류: $e');
      return null;
    }
  }

  // 카메라로 이미지 촬영
  Future<File?> pickImageFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 80,
      );
      
      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      print('카메라 촬영 오류: $e');
      return null;
    }
  }

  // 토큰 가져오기
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // 채팅 이미지 업로드 (서버로)
  Future<String?> uploadImage(File file, {String? folder}) async {
    try {
      final token = await _getToken();
      if (token == null) {
        print('⚠️ 토큰 없음 - 업로드 불가');
        return null;
      }

      final uri = Uri.parse('${AppConfig.serverUrl}/api/upload/chat');
      final request = http.MultipartRequest('POST', uri);
      
      request.headers['Authorization'] = 'Bearer $token';
      
      // 파일 확장자 확인
      final extension = file.path.split('.').last.toLowerCase();
      final mimeType = _getMimeType(extension);
      
      request.files.add(await http.MultipartFile.fromPath(
        'image',
        file.path,
        contentType: MediaType('image', mimeType),
      ));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final imageUrl = '${AppConfig.serverUrl}${data['imageUrl']}';
        print('✅ 이미지 업로드 성공: $imageUrl');
        return imageUrl;
      } else {
        print('❌ 이미지 업로드 실패: ${response.body}');
        return null;
      }
    } catch (e) {
      print('이미지 업로드 오류: $e');
      return null;
    }
  }

  // 프로필 이미지 업로드
  Future<String?> uploadProfileImage(File file, String userId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        print('⚠️ 토큰 없음 - 업로드 불가');
        return null;
      }

      final uri = Uri.parse('${AppConfig.serverUrl}/api/upload/profile');
      final request = http.MultipartRequest('POST', uri);
      
      request.headers['Authorization'] = 'Bearer $token';
      
      final extension = file.path.split('.').last.toLowerCase();
      final mimeType = _getMimeType(extension);
      
      request.files.add(await http.MultipartFile.fromPath(
        'image',
        file.path,
        contentType: MediaType('image', mimeType),
      ));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final imageUrl = '${AppConfig.serverUrl}${data['imageUrl']}';
        print('✅ 프로필 이미지 업로드 성공: $imageUrl');
        return imageUrl;
      } else {
        print('❌ 프로필 이미지 업로드 실패: ${response.body}');
        return null;
      }
    } catch (e) {
      print('프로필 이미지 업로드 오류: $e');
      return null;
    }
  }

  // 이미지 삭제
  Future<bool> deleteImage(String imageUrl) async {
    // 서버 측에서 자동 관리하므로 클라이언트에서는 true 반환
    return true;
  }
  
  // MIME 타입 결정
  String _getMimeType(String extension) {
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'jpeg';
      case 'png':
        return 'png';
      case 'gif':
        return 'gif';
      case 'webp':
        return 'webp';
      default:
        return 'jpeg';
    }
  }
}
