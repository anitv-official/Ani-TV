import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class CloudinaryUploadResult {
  final String url;
  final String publicId;
  const CloudinaryUploadResult({required this.url, required this.publicId});
}

class CloudinaryService {
  CloudinaryService._();
  static const cloudName = 'mjozpfyi';
  static const uploadPreset = 'anitv_community';
  static const folder = 'anitv/community/posts';
  static const maxBytes = 10 * 1024 * 1024;
  static const allowedExtensions = {'jpg', 'jpeg', 'png', 'webp'};

  static Future<CloudinaryUploadResult> uploadPostImage(String path) async {
    final file = File(path);
    if (!await file.exists()) throw const CloudinaryException('لم يتم العثور على الصورة.');
    final size = await file.length();
    if (size > maxBytes) throw const CloudinaryException('حجم الصورة يجب ألا يتجاوز 10 ميجابايت.');
    final extension = path.split('.').last.toLowerCase();
    if (!allowedExtensions.contains(extension)) throw const CloudinaryException('صيغة الصورة غير مدعومة. استخدم JPG أو PNG أو WEBP.');
    final request = http.MultipartRequest('POST', Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload'))
      ..fields['upload_preset'] = uploadPreset
      ..fields['folder'] = folder
      ..files.add(await http.MultipartFile.fromPath('file', path));
    final response = await request.send();
    final body = await response.stream.bytesToString();
    if (response.statusCode < 200 || response.statusCode >= 300) throw const CloudinaryException('تعذر رفع الصورة. حاول مرة أخرى.');
    final data = jsonDecode(body);
    if (data is! Map || data['secure_url'] == null || data['public_id'] == null) throw const CloudinaryException('استجابة رفع الصورة غير صالحة.');
    return CloudinaryUploadResult(url: data['secure_url'].toString(), publicId: data['public_id'].toString());
  }
}

class CloudinaryException implements Exception {
  final String message;
  const CloudinaryException(this.message);
  @override String toString() => message;
}
