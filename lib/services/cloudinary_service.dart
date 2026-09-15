import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
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
    if (!await file.exists()) {
      throw const CloudinaryException('لم يتم العثور على الصورة.', stage: 'file');
    }
    final extension = path.split('.').last.toLowerCase();
    if (!allowedExtensions.contains(extension)) {
      throw const CloudinaryException('صيغة الصورة غير مدعومة. استخدم JPG أو PNG أو WEBP.', stage: 'validation');
    }
    final size = await file.length();
    if (size > maxBytes) {
      throw const CloudinaryException('حجم الصورة يجب ألا يتجاوز 10 ميجابايت.', stage: 'validation');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload'),
    )
      ..fields['upload_preset'] = uploadPreset
      ..fields['folder'] = folder
      ..files.add(await http.MultipartFile.fromPath('file', path));

    try {
      final response = await request.send();
      final body = await response.stream.bytesToString();
      final decoded = _decode(body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _debug('upload', response.statusCode, decoded);
        throw CloudinaryException(_safeMessage(decoded), statusCode: response.statusCode, stage: 'upload');
      }
      final secureUrl = decoded['secure_url']?.toString();
      final publicId = decoded['public_id']?.toString();
      if (secureUrl == null || secureUrl.isEmpty || publicId == null || publicId.isEmpty) {
        _debug('response', response.statusCode, decoded);
        throw const CloudinaryException('استجابة رفع الصورة غير صالحة.', stage: 'response');
      }
      return CloudinaryUploadResult(url: secureUrl, publicId: publicId);
    } on CloudinaryException {
      rethrow;
    } on SocketException catch (error) {
      _debug('network', null, error.toString());
      throw const CloudinaryException('تعذر الاتصال بخادم الصور.', stage: 'network');
    } on http.ClientException catch (error) {
      _debug('network', null, error.toString());
      throw const CloudinaryException('تعذر الاتصال بخادم الصور.', stage: 'network');
    }
  }

  static Map<String, dynamic> _decode(String body) {
    try {
      final value = jsonDecode(body);
      return value is Map<String, dynamic> ? value : <String, dynamic>{'raw': body};
    } catch (_) {
      return <String, dynamic>{'raw': body};
    }
  }

  static String _safeMessage(Map<String, dynamic> data) {
    final error = data['error'];
    if (error is Map) return error['message']?.toString() ?? 'Cloudinary upload failed';
    return data['message']?.toString() ?? 'Cloudinary upload failed';
  }

  static void _debug(String stage, int? status, Object response) {
    if (kDebugMode) {
      debugPrint('Cloudinary [$stage] status=${status ?? '-'} response=$response');
    }
  }
}

class CloudinaryException implements Exception {
  final String message;
  final int? statusCode;
  final String stage;
  const CloudinaryException(this.message, {this.statusCode, this.stage = 'unknown'});
  @override
  String toString() => message;
}
