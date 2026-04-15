import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

class AuthService {
  static const _tokenKey = 'auth_token';
  static const _userIdKey = 'auth_user_id';
  static const _userNameKey = 'auth_user_name';
  static const _nicknameKey = 'auth_nickname';
  static const _roleKey = 'auth_role';
  static const _canUploadKey = 'auth_can_upload';
  static const _canDeleteKey = 'auth_can_delete';
  static const _canDownloadKey = 'auth_can_download';

  static String? _token;
  static String? _userId;
  static String? _userName;
  static String? _nickname;
  static String _role = 'member';
  static bool _canUpload = true;
  static bool _canDelete = true;
  static bool _canDownload = true;

  static String? get token => _token;
  static String? get userId => _userId;
  static String? get userName => _userName;
  static String? get nickname => _nickname;
  static String get role => _role;
  static bool get isAdmin => _role == 'admin';
  static bool get canUpload => _canUpload;
  static bool get canDelete => _canDelete;
  static bool get canDownload => _canDownload;
  static bool get isLoggedIn => _token != null;

  static Future<bool> loadSavedAuth() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    _userId = prefs.getString(_userIdKey);
    _userName = prefs.getString(_userNameKey);
    _nickname = prefs.getString(_nicknameKey);
    _role = prefs.getString(_roleKey) ?? 'member';
    _canUpload = prefs.getBool(_canUploadKey) ?? true;
    _canDelete = prefs.getBool(_canDeleteKey) ?? true;
    _canDownload = prefs.getBool(_canDownloadKey) ?? true;

    if (_token == null) return false;

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/auth/me'),
        headers: {'Authorization': 'Bearer $_token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _nickname = data['nickname'] ?? _nickname;
        _role = data['role'] ?? _role;
        _canUpload = data['can_upload'] ?? _canUpload;
        _canDelete = data['can_delete'] ?? _canDelete;
        _canDownload = data['can_download'] ?? _canDownload;
        await _savePrefs();
        return true;
      }
    } catch (_) {}

    await _clearAuth();
    return false;
  }

  static Future<void> register(String name, String nickname, String password) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'nickname': nickname, 'password': password}),
    );

    if (response.statusCode == 201) {
      await _applyTokenResponse(jsonDecode(response.body));
    } else if (response.statusCode == 409) {
      throw AuthException('이미 사용 중인 아이디입니다');
    } else {
      throw AuthException(_parseError(response.body));
    }
  }

  static Future<void> login(String name, String password) async {
    final response = await http.post(
      Uri.parse('${AppConfig.baseUrl}/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'password': password}),
    );

    if (response.statusCode == 200) {
      await _applyTokenResponse(jsonDecode(response.body));
    } else if (response.statusCode == 401) {
      throw AuthException('아이디 또는 비밀번호가 올바르지 않습니다');
    } else {
      throw AuthException(_parseError(response.body));
    }
  }

  static Future<List<Map<String, dynamic>>> getUsers() async {
    final response = await http.get(
      Uri.parse('${AppConfig.baseUrl}/auth/users'),
      headers: {'Authorization': 'Bearer $_token'},
    );
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(response.body));
    }
    throw AuthException('멤버 목록을 불러올 수 없습니다');
  }

  static Future<void> updatePermission(String userId, Map<String, bool> perms) async {
    final response = await http.put(
      Uri.parse('${AppConfig.baseUrl}/auth/users/$userId/permissions'),
      headers: {
        'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(perms),
    );
    if (response.statusCode != 200) {
      throw AuthException(_parseError(response.body));
    }
  }

  static Future<void> logout() async {
    await _clearAuth();
  }

  static Future<void> _applyTokenResponse(Map<String, dynamic> data) async {
    _token = data['access_token'];
    _userId = data['user_id'];
    _userName = data['name'];
    _nickname = data['nickname'];
    _role = data['role'] ?? 'member';
    _canUpload = data['can_upload'] ?? true;
    _canDelete = data['can_delete'] ?? true;
    _canDownload = data['can_download'] ?? true;
    await _savePrefs();
  }

  static Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (_token != null) await prefs.setString(_tokenKey, _token!);
    if (_userId != null) await prefs.setString(_userIdKey, _userId!);
    if (_userName != null) await prefs.setString(_userNameKey, _userName!);
    if (_nickname != null) await prefs.setString(_nicknameKey, _nickname!);
    await prefs.setString(_roleKey, _role);
    await prefs.setBool(_canUploadKey, _canUpload);
    await prefs.setBool(_canDeleteKey, _canDelete);
    await prefs.setBool(_canDownloadKey, _canDownload);
  }

  static Future<void> _clearAuth() async {
    _token = null;
    _userId = null;
    _userName = null;
    _nickname = null;
    _role = 'member';
    _canUpload = true;
    _canDelete = true;
    _canDownload = true;
    final prefs = await SharedPreferences.getInstance();
    for (final key in [_tokenKey, _userIdKey, _userNameKey, _nicknameKey, _roleKey]) {
      await prefs.remove(key);
    }
    for (final key in [_canUploadKey, _canDeleteKey, _canDownloadKey]) {
      await prefs.remove(key);
    }
  }

  static String _parseError(String body) {
    try {
      return (jsonDecode(body)['detail'] ?? '알 수 없는 오류').toString();
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
