import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/photo.dart';

class ApiService {
  static final String _base = AppConfig.baseUrl;

  /// Fetch list of months that have photos
  static Future<List<String>> getMonths() async {
    final response = await http.get(Uri.parse('$_base/photos/months'));
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
  static Future<List<Photo>> getRecent({int limit = 20}) async {
    final response = await http.get(
      Uri.parse('$_base/photos/recent?limit=$limit'),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List;
      return data.map((json) => Photo.fromJson(json)).toList();
    }
    throw Exception('Failed to load recent: ${response.statusCode}');
  }

  /// Fetch favorited photos
  static Future<List<Photo>> getFavorites() async {
    final response = await http.get(Uri.parse('$_base/photos/favorites'));
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
    );
    if (response.statusCode == 200) {
      return Photo.fromJson(jsonDecode(response.body));
    }
    throw Exception('Toggle favorite failed: ${response.statusCode}');
  }

  /// Upload a photo file
  static Future<Photo> uploadPhoto(File file) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_base/photos/upload'),
    );
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 201) {
      return Photo.fromJson(jsonDecode(response.body));
    }
    if (response.statusCode == 409) {
      throw DuplicatePhotoException();
    }
    throw Exception('Upload failed: ${response.statusCode} ${response.body}');
  }

  /// Delete a photo by ID
  static Future<void> deletePhoto(String photoId) async {
    final response = await http.delete(
      Uri.parse('$_base/photos/$photoId'),
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
