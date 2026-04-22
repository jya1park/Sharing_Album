import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/photo.dart';
import 'auth_service.dart';

class ApiService {
  static final String _base = AppConfig.baseUrl;

  static Map<String, String> get _authHeaders {
    final headers = <String, String>{};
    if (AuthService.token != null) {
      headers['Authorization'] = 'Bearer ${AuthService.token}';
    }
    return headers;
  }

  /// Fetch list of months that have photos
  static Future<List<String>> getMonths() async {
    final response = await http.get(
      Uri.parse('$_base/photos/months'),
      headers: _authHeaders,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<String>.from(data['months']);
    }
    throw Exception('Failed to load months: ${response.statusCode}');
  }

  /// Fetch photos for a given month (YYYY-MM)
  static Future<List<Photo>> getPhotos(String month) async {
    final response = await http.get(
      Uri.parse('$_base/photos/?month=$month'),
      headers: _authHeaders,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['photos'] as List)
          .map((json) => Photo.fromJson(json))
          .toList();
    }
    throw Exception('Failed to load photos: ${response.statusCode}');
  }

  /// Fetch recently uploaded photos
  static Future<List<Photo>> getRecent({int limit = 50}) async {
    final response = await http.get(
      Uri.parse('$_base/photos/recent?limit=$limit'),
      headers: _authHeaders,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List;
      return data.map((json) => Photo.fromJson(json)).toList();
    }
    throw Exception('Failed to load recent: ${response.statusCode}');
  }

  /// Fetch favorited photos
  static Future<List<Photo>> getFavorites() async {
    final response = await http.get(
      Uri.parse('$_base/photos/favorites'),
      headers: _authHeaders,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List;
      return data.map((json) => Photo.fromJson(json)).toList();
    }
    throw Exception('Failed to load favorites: ${response.statusCode}');
  }

  /// Toggle favorite status
  static Future<Photo> toggleFavorite(String photoId) async {
    final response = await http.put(
      Uri.parse('$_base/photos/$photoId/favorite'),
      headers: _authHeaders,
    );
    if (response.statusCode == 200) {
      return Photo.fromJson(jsonDecode(response.body));
    }
    throw Exception('Toggle favorite failed: ${response.statusCode}');
  }

  /// Upload a photo/video file with progress callback
  static Future<Photo> uploadPhoto(
    File file, {
    List<String>? visibleTo,
    void Function(double progress)? onProgress,
  }) async {
    final dio = Dio();
    dio.options.headers['Authorization'] = 'Bearer ${AuthService.token}';

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path, filename: file.path.split('/').last),
      if (visibleTo != null && visibleTo.isNotEmpty) 'visible_to': visibleTo.join(','),
    });

    try {
      final response = await dio.post(
        '$_base/photos/upload',
        data: formData,
        onSendProgress: (sent, total) {
          if (total > 0 && onProgress != null) {
            onProgress(sent / total);
          }
        },
      );

      if (response.statusCode == 201) {
        return Photo.fromJson(response.data);
      }
      throw Exception('Upload failed: ${response.statusCode}');
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw DuplicatePhotoException();
      }
      throw Exception('Upload failed: ${e.message}');
    }
  }

  static Future<Photo> updateVisibility(String photoId, List<String> visibleTo) async {
    final response = await http.put(
      Uri.parse('$_base/photos/$photoId/visibility'),
      headers: {
        ..._authHeaders,
        'Content-Type': 'application/json',
      },
      body: jsonEncode(visibleTo),
    );
    if (response.statusCode == 200) {
      return Photo.fromJson(jsonDecode(response.body));
    }
    throw Exception('Visibility update failed: ${response.statusCode}');
  }

  /// Delete a photo by ID
  static Future<void> deletePhoto(String photoId) async {
    final response = await http.delete(
      Uri.parse('$_base/photos/$photoId'),
      headers: _authHeaders,
    );
    if (response.statusCode != 200) {
      throw Exception('Delete failed: ${response.statusCode}');
    }
  }

  /// Build full URL for an image
  static String imageUrl(String path) => '$_base$path';
}

class DuplicatePhotoException implements Exception {
  @override
  String toString() => '이미 업로드된 사진입니다';
}
