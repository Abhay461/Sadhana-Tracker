import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../utils/security_utils.dart';

class CloudinaryService {
  // Loaded from environment variables at build time for production
  static const String cloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
    defaultValue: 'dxm9zgkv2',
  );
  static const String uploadPreset = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
    defaultValue: 'sadhana_track',
  );

  static Future<String> uploadToCloudinary(File file) async {
    return _doUpload(file);
  }

  static Future<String> uploadImage(File file) async {
    return _doUpload(file);
  }

  static Future<String> _doUpload(File file) async {
    // Validate file exists
    if (!await file.exists()) {
      throw Exception('File does not exist');
    }

    // Validate file size (max 5 MB)
    final fileSize = await file.length();
    if (fileSize > SecurityUtils.maxUploadFileSize) {
      throw Exception('File is too large. Maximum size is 5 MB.');
    }

    // Validate file type
    if (!SecurityUtils.isValidImageFile(file.path)) {
      throw Exception('Invalid file type. Only JPG, PNG, GIF, and WebP are allowed.');
    }

    final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');

    // Try with primary uploadPreset (e.g. sadhana_track), fallback to ml_default if needed
    List<String> presetsToTry = [uploadPreset, 'ml_default'];

    for (String preset in presetsToTry) {
      try {
        final request = http.MultipartRequest('POST', url)
          ..fields['upload_preset'] = preset
          ..files.add(await http.MultipartFile.fromPath('file', file.path));

        final streamedResponse = await request.send().timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw Exception('Upload timed out. Please try again.');
          },
        );
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          final Map<String, dynamic> responseData = json.decode(response.body);
          final secureUrl = responseData['secure_url'] as String?;
          if (secureUrl != null && secureUrl.isNotEmpty) {
            print('✅ [CLOUDINARY SUCCESS] Uploaded to: $secureUrl');
            return secureUrl;
          }
        } else {
          print('❌ [CLOUDINARY ERROR] Preset $preset (${response.statusCode}): ${response.body}');
        }
      } catch (e) {
        print('❌ [CLOUDINARY EXCEPTION] Preset $preset: $e');
      }
    }

    throw Exception('Upload failed. Please ensure Unsigned Upload preset ("sadhana_track" or "ml_default") is enabled in Cloudinary Settings.');
  }
}
