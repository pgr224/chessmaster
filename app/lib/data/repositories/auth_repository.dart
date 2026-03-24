import 'dart:convert';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_ce/hive.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/user_model.dart';

class AuthRepository {
  final Dio _dio;
  static const _tokenKey = 'auth_token';
  static const _userKey = 'user_data';
  static const _deviceIdKey = 'device_id';

  AuthRepository(this._dio);

  /// Generate a deterministic device fingerprint
  Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check if we already have a stored device ID
    final stored = prefs.getString(_deviceIdKey);
    if (stored != null) return stored;

    // Generate new fingerprint
    final info = DeviceInfoPlugin();
    String rawId;

    if (kIsWeb) {
      rawId = 'web_${DateTime.now().millisecondsSinceEpoch}';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      final android = await info.androidInfo;
      rawId = '${android.id}:${android.model}:${android.brand}';
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = await info.iosInfo;
      rawId = ios.identifierForVendor ?? '${ios.model}:${ios.systemVersion}';
    } else {
      rawId = 'desktop_${DateTime.now().millisecondsSinceEpoch}';
    }

    // Hash the raw ID for privacy
    final hash = sha256.convert(utf8.encode(rawId)).toString();
    await prefs.setString(_deviceIdKey, hash);
    return hash;
  }

  Future<UserModel?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final userData = prefs.getString(_userKey);
    
    if (token == null || userData == null) return null;
    
    try {
      final json = jsonDecode(userData) as Map<String, dynamic>;
      return UserModel.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<UserModel> register({required String username, String? avatarPath}) async {
    final deviceId = await getDeviceId();
    
    final response = await _dio.post(
      '/api/auth/register',
      data: {'username': username, 'deviceId': deviceId},
    );

    final token = response.data['token'] as String;
    final userId = response.data['userId'] as String;

    // Store token & basic user info locally
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);

    // Fetch full profile
    _dio.options.headers['Authorization'] = 'Bearer $token';
    final profile = await _fetchProfile(userId);

    final userJson = jsonEncode(profile.toJson());
    await prefs.setString(_userKey, userJson);
    return profile;
  }

  Future<UserModel> updateProfile({
    required String userId,
    String? username,
    String? avatarPath,
  }) async {
    final response = await _dio.put(
      '/api/profile/$userId',
      data: {
        if (username != null) 'username': username,
        if (avatarPath != null) 'avatarUrl': avatarPath,
      },
    );
    return UserModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<UserModel> _fetchProfile(String userId) async {
    final response = await _dio.get('/api/profile/$userId');
    return UserModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    _dio.options.headers.remove('Authorization');
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }
}
