import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

class AuthService {
  static const _tokenKey = 'auth_token';
  static const _userIdKey = 'auth_user_id';
  static const _userNameKey = 'auth_user_name';

  static String? _token;
  static String? _userId;
  static String? _userName;

  static String? get token => _token;
  static String? get userId => _userId;
  static String? get userName => _userName;
  static bool get isLoggedIn => _token != null;

  /// Load saved auth state from SharedPreferences
  static Future<bool> loadSavedAuth() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    _userId = prefs.getString(_userIdKey);
    _userName = prefs.getString(_userNameKey);

    if (_token == null) return false;

    // Verify token is still valid
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/auth/me'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (response.statusCode == 200) {
        return true;
      }
    } catch (_) {}

    // Token invalid, clear saved state
    await _clearAuth();
    return false;
  }

  /// Register a new user
  static Future<void> register(String name, String password) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'password': password}),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      await _saveAuth(data['access_token'], data['user_id'], data['name']);
    } else if (response.statusCode == 409) {
      throw AuthException('이미 사용 중인 이름입니다');
    } else {
      final detail = _parseError(response.body);
      throw AuthException(detail);
    }
  }

  /// Login with existing credentials
  static Future<void> login(String name, String password) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await _saveAuth(data['access_token'], data['user_id'], data['name']);
    } else if (response.statusCode == 401) {
      throw AuthException('이름 또는 비밀번호가 올바르지 않습니다');
    } else {
      final detail = _parseError(response.body);
      throw AuthException(detail);
    }
  }

  /// Logout and clear saved auth
  static Future<void> logout() async {
    await _clearAuth();
  }

  static Future<void> _saveAuth(String token, String userId, String name) async {
    _token = token;
    _userId = userId;
    _userName = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userIdKey, userId);
    await prefs.setString(_userNameKey, name);
  }

  static Future<void> _clearAuth() async {
    _token = null;
    _userId = null;
    _userName = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_userNameKey);
  }

  static String _parseError(String body) {
    try {
      final data = jsonDecode(body);
      return data['detail'] ?? '알 수 없는 오류';
    } catch (_) {
      return '서버 오류';
    }
  }
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}
