import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class CloudinaryUpload {
  static const String _cloudName = 'dorcxchuf';
  static const String _apiKey = '889137245574349';
  static const String _apiSecret = 'UQARnH8trtIbeFP7Oowva3ILF9M';

  /// Holds the last upload error message for UI display/debug.
  static String? lastErrorMessage;

  static Uri _uploadUriFor({required bool isPdf}) => Uri.parse(
    'https://api.cloudinary.com/v1_1/$_cloudName/${isPdf ? 'raw' : 'image'}/upload',
  );

  static bool _isPdfName(String fileName) =>
      fileName.toLowerCase().trim().endsWith('.pdf');

  static MediaType _contentTypeForName(String fileName, {required bool isPdf}) {
    if (isPdf) return MediaType('application', 'pdf');
    final name = fileName.toLowerCase().trim();
    if (name.endsWith('.png')) return MediaType('image', 'png');
    if (name.endsWith('.jpg') || name.endsWith('.jpeg')) {
      return MediaType('image', 'jpeg');
    }
    return MediaType('image', 'jpeg');
  }

  static String _sanitizeFileName(String fileName) {
    final trimmed = fileName.trim();
    if (trimmed.isEmpty) {
      return 'upload_${DateTime.now().millisecondsSinceEpoch}';
    }
    return trimmed.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  }

  static String _generateSignature(Map<String, String> params) {
    final sorted = params.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final paramString = sorted.map((e) => '${e.key}=${e.value}').join('&');
    final toSign = '$paramString$_apiSecret';
    return sha1.convert(utf8.encode(toSign)).toString();
  }

  static Future<String?> uploadAuto({
    required Uint8List bytes,
    required String folder,
    required String fileName,
  }) {
    final safeName = _sanitizeFileName(fileName);
    return uploadBytes(
      bytes: bytes,
      folder: folder,
      fileName: safeName,
      isPdf: _isPdfName(safeName),
    );
  }

  static Future<String?> uploadBytes({
    required Uint8List bytes,
    required String folder,
    required String fileName,
    bool isPdf = false,
  }) async {
    lastErrorMessage = null;
    try {
      if (bytes.isEmpty) {
        lastErrorMessage = 'Selected file is empty.';
        return null;
      }

      final safeName = _sanitizeFileName(fileName);
      final inferredIsPdf = isPdf || _isPdfName(safeName);
      final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000)
          .toString();
      final signParams = {'folder': folder, 'timestamp': timestamp};
      final signature = _generateSignature(signParams);

      final request =
          http.MultipartRequest('POST', _uploadUriFor(isPdf: inferredIsPdf))
            ..fields['api_key'] = _apiKey
            ..fields['timestamp'] = timestamp
            ..fields['signature'] = signature
            ..fields['folder'] = folder
            ..files.add(
              http.MultipartFile.fromBytes(
                'file',
                bytes,
                filename: safeName,
                contentType: _contentTypeForName(
                  safeName,
                  isPdf: inferredIsPdf,
                ),
              ),
            );

      final streamed = await request.send();
      final resp = await http.Response.fromStream(streamed);

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return data['secure_url']?.toString();
      }

      try {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final err = data['error'];
        if (err is Map<String, dynamic>) {
          final msg = err['message']?.toString();
          if (msg != null && msg.trim().isNotEmpty) {
            lastErrorMessage = 'Upload failed: $msg';
          }
        }
      } catch (_) {
        // ignore parse failure and fallback to generic message below.
      }

      lastErrorMessage ??= 'Upload failed (HTTP ${resp.statusCode}).';
      return null;
    } catch (e) {
      lastErrorMessage = 'Upload failed: $e';
      return null;
    }
  }
}
