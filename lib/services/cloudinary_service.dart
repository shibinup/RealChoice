import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'dart:convert';

/// Client-side Cloudinary upload service using unsigned upload presets.
///
/// Credentials are loaded from [.env] via [flutter_dotenv] – never hard-coded.
/// No Cloud Functions or backend required.
///
/// Setup:
///   1. Create an **unsigned** upload preset in Cloudinary Dashboard
///      (Settings → Upload → Upload presets → Add upload preset → Signing mode: Unsigned).
///   2. Add to .env:
///        CLOUDINARY_CLOUD_NAME=your_cloud_name
///        CLOUDINARY_UPLOAD_PRESET=your_unsigned_preset
class CloudinaryService {
  static const _uuid = Uuid();

  /// Cloudinary cloud name from .env
  static String get _cloudName =>
      dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';

  /// Unsigned upload preset name from .env
  static String get _uploadPreset =>
      dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '';

  /// Base upload URL for images
  static String get _imageUploadUrl =>
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload';

  /// Base upload URL for videos
  static String get _videoUploadUrl =>
      'https://api.cloudinary.com/v1_1/$_cloudName/video/upload';

  // ---------------------------------------------------------------------------
  // Public helpers
  // ---------------------------------------------------------------------------

  /// Upload a single image file to Cloudinary.
  ///
  /// [folder] – Cloudinary destination folder (e.g. `cars/car123/photos`).
  /// Returns the secure CDN URL of the uploaded file.
  static Future<String> uploadImage(File file, {required String folder}) {
    final publicId = '$folder/${_uuid.v4()}';
    return _upload(
      file: file,
      uploadUrl: _imageUploadUrl,
      publicId: publicId,
    );
  }

  /// Upload a single video file to Cloudinary.
  ///
  /// [folder] – Cloudinary destination folder.
  /// Returns the secure CDN URL of the uploaded file.
  static Future<String> uploadVideo(File file, {required String folder}) {
    final publicId = '$folder/${_uuid.v4()}';
    return _upload(
      file: file,
      uploadUrl: _videoUploadUrl,
      publicId: publicId,
    );
  }

  // ---------------------------------------------------------------------------
  // Core upload (multipart form upload – no signature needed for unsigned preset)
  // ---------------------------------------------------------------------------


  static Future<String> _upload({
    required File file,
    required String uploadUrl,
    required String publicId,
  }) async {
    final cloudName = _cloudName;
    final preset = _uploadPreset;

    print('========== CLOUDINARY UPLOAD START ==========');

    try {
      // STEP 1: Check configuration
      print('Cloud name: $cloudName');
      print('Upload preset: $preset');
      print('Upload URL: $uploadUrl');
      print('Public ID: $publicId');

      if (cloudName.isEmpty) {
        throw Exception('CLOUDINARY_CLOUD_NAME is empty.');
      }

      if (preset.isEmpty) {
        throw Exception('CLOUDINARY_UPLOAD_PRESET is empty.');
      }

      // STEP 2: Check file
      print('File path: ${file.path}');

      final exists = await file.exists();
      print('File exists: $exists');

      if (!exists) {
        throw Exception('Selected file does not exist.');
      }

      final fileSize = await file.length();
      print('File size: $fileSize bytes');

      // STEP 3: Create multipart request
      print('Creating multipart request...');

      final request = http.MultipartRequest(
        'POST',
        Uri.parse(uploadUrl),
      );

      request.fields['upload_preset'] = preset;
      request.fields['public_id'] = publicId;

      final multipartFile = await http.MultipartFile.fromPath(
        'file',
        file.path,
      );

      request.files.add(multipartFile);

      print('Multipart request created successfully.');
      print('Sending request to Cloudinary...');

      // STEP 4: Send request
      final streamed = await request.send().timeout(
        const Duration(minutes: 5),
      );

      print('Cloudinary HTTP status: ${streamed.statusCode}');
      print('Response headers: ${streamed.headers}');

      // STEP 5: Read response
      final body = await streamed.stream.bytesToString().timeout(
        const Duration(minutes: 2),
      );

      print('Cloudinary response body: $body');

      // STEP 6: Check response
      if (streamed.statusCode < 200 ||
          streamed.statusCode >= 300) {
        throw Exception(
          'Cloudinary upload failed '
              '[${streamed.statusCode}]: $body',
        );
      }

      // STEP 7: Decode response
      final json = jsonDecode(body) as Map<String, dynamic>;

      final url = json['secure_url'] as String?;

      if (url == null || url.isEmpty) {
        throw Exception('Cloudinary response missing secure_url.');
      }

      print('UPLOAD SUCCESS!');
      print('Uploaded file URL: $url');
      print('========== CLOUDINARY UPLOAD END ==========');

      return url;
    } catch (e, stackTrace) {
      print('========== CLOUDINARY UPLOAD FAILED ==========');
      print('Error type: ${e.runtimeType}');
      print('Error message: $e');
      print('Stack trace: $stackTrace');
      print('========== END ERROR ==========');

      rethrow;
    }
  }

}
