import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  // Firebase Storage는 나중에 설정 후 사용
  // final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();
  final Uuid _uuid = const Uuid();
  
  bool _firebaseEnabled = false;

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

  // 이미지 업로드 (Firebase 설정 전에는 로컬 경로 반환)
  Future<String?> uploadImage(File file, {String? folder}) async {
    try {
      if (!_firebaseEnabled) {
        // Firebase 미설정시 로컬 파일 경로 반환
        print('⚠️ Firebase Storage 미설정 - 로컬 경로 사용');
        return file.path;
      }
      
      // TODO: Firebase Storage 설정 후 아래 코드 활성화
      // final String fileName = '${_uuid.v4()}.jpg';
      // final String path = folder != null ? '$folder/$fileName' : 'chat_images/$fileName';
      // final Reference ref = _storage.ref().child(path);
      // final UploadTask uploadTask = ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
      // final TaskSnapshot snapshot = await uploadTask;
      // return await snapshot.ref.getDownloadURL();
      
      return file.path;
    } catch (e) {
      print('이미지 업로드 오류: $e');
      return null;
    }
  }

  // 이미지 삭제
  Future<bool> deleteImage(String imageUrl) async {
    try {
      if (!_firebaseEnabled) {
        print('⚠️ Firebase Storage 미설정');
        return true;
      }
      
      // TODO: Firebase Storage 설정 후 활성화
      // final Reference ref = _storage.refFromURL(imageUrl);
      // await ref.delete();
      return true;
    } catch (e) {
      print('이미지 삭제 오류: $e');
      return false;
    }
  }

  // 프로필 이미지 업로드
  Future<String?> uploadProfileImage(File file, String userId) async {
    return uploadImage(file, folder: 'profile_images/$userId');
  }
}
