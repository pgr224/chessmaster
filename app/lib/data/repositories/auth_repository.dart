import 'dart:convert';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../models/user_model.dart';

import 'package:uuid/uuid.dart';

class AuthRepository {
  final Dio _dio;
  static const _tokenKey = 'auth_token';
  static const _userKey = 'user_data';
  static const _deviceIdKey = 'device_id';
  static final RegExp _usernamePattern = RegExp(r'^[a-zA-Z0-9_]{2,30}$');
  final _uuid = const Uuid();

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
      rawId = 'web_${_uuid.v4()}';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      final android = await info.androidInfo;
      rawId = '${android.id}:${android.model}:${android.brand}';
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = await info.iosInfo;
      rawId = ios.identifierForVendor ?? '${ios.model}:${ios.systemVersion}';
    } else {
      rawId = 'desktop_${_uuid.v4()}';
    }

    // Hash the raw ID for privacy
    final hash = sha256.convert(utf8.encode(rawId)).toString();
    await prefs.setString(_deviceIdKey, hash);
    return hash;
  }

  Future<UserModel?> getCurrentUser({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    
    // Even if we have a token, if we want to refresh or if we only have deviceId, 
    // try to silent login to get latest user data
    if (token == null || forceRefresh) {
      try {
        final user = await login();
        return user;
      } catch (_) {
        if (!forceRefresh) return null;
      }
    }

    final userData = prefs.getString(_userKey);
    if (token == null || userData == null) return null;
    
    try {
      final json = jsonDecode(userData) as Map<String, dynamic>;
      return UserModel.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<UserModel> login() async {
    final deviceId = await getDeviceId();
    final response = await _dio.post(
      '/api/auth/login',
      data: {'deviceId': deviceId},
    );

    final rawToken = (response.data['token'] ?? response.data['accessToken']) as String;
    final token = _normalizeToken(rawToken);
    final userId = response.data['userId'] as String;

    _dio.options.headers['Authorization'] = 'Bearer $token';

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);

    final profile = _resolveRegisteredUser(
      responseData: response.data as Map<String, dynamic>,
      userId: userId,
      fallbackUsername: (response.data['username'] ?? 'User') as String,
      deviceId: deviceId,
    );

    await prefs.setString(_userKey, jsonEncode(profile.toJson()));
    return profile;
  }

  Future<bool> checkUsername(String username) async {
    try {
      final response = await _dio.get('/api/auth/check-username', queryParameters: {'username': username});
      return response.data['available'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<UserModel> register({required String username, String? avatarPath}) async {
    final normalizedUsername = _normalizeUsername(username);
    if (!_usernamePattern.hasMatch(normalizedUsername)) {
      throw Exception('Username must be 2-30 characters and use only letters, numbers, or underscore.');
    }

    final deviceId = await getDeviceId();

    final response = await _dio.post(
      '/api/auth/register',
      data: {'username': normalizedUsername, 'deviceId': deviceId},
      options: Options(validateStatus: (status) {
        if (status == null) return false;
        return status >= 200 && status < 500;
      }),
    );

    if (response.statusCode == 400) {
      throw Exception(_extractValidationMessage(response.data));
    }

    if (response.statusCode == 409) {
      final recovered = await _recoverFromRegisterConflict(
        responseData: response.data,
        fallbackUsername: normalizedUsername,
        deviceId: deviceId,
      );
      if (recovered != null) return recovered;

      throw Exception(_extractConflictMessage(response.data));
    }

    final rawToken = (response.data['token'] ?? response.data['accessToken']) as String;
    final token = _normalizeToken(rawToken);
    final userId = response.data['userId'] as String;

    // Store token & basic user info locally
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);

    // Prefer user payload from register response to avoid an immediate follow-up
    // profile request that may 401 while auth propagation is still in flight.
    _dio.options.headers['Authorization'] = 'Bearer $token';
    final profile = _resolveRegisteredUser(
      responseData: response.data as Map<String, dynamic>,
      userId: userId,
      fallbackUsername: normalizedUsername,
      deviceId: deviceId,
    );

    final userJson = jsonEncode(profile.toJson());
    await prefs.setString(_userKey, userJson);
    return profile;
  }

  Future<UserModel?> _recoverFromRegisterConflict({
    required dynamic responseData,
    required String fallbackUsername,
    required String deviceId,
  }) async {
    if (responseData is! Map<String, dynamic>) return null;

    final tokenValue = responseData['token'] ?? responseData['accessToken'];
    final userIdValue = responseData['userId'] ?? (responseData['user'] is Map<String, dynamic> ? responseData['user']['id'] : null);

    if (tokenValue is String) {
      final prefs = await SharedPreferences.getInstance();
      final token = _normalizeToken(tokenValue);
      await prefs.setString(_tokenKey, token);
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }

    final userId = userIdValue is String ? userIdValue : '';
    final resolved = _resolveRegisteredUser(
      responseData: responseData,
      userId: userId,
      fallbackUsername: fallbackUsername,
      deviceId: deviceId,
    );

    if (resolved.id.isEmpty) return null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(resolved.toJson()));
    return resolved;
  }

  String _extractConflictMessage(dynamic responseData) {
    if (responseData is Map<String, dynamic>) {
      final candidates = [responseData['message'], responseData['error'], responseData['detail']];
      for (final value in candidates) {
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
    }
    return 'Account already exists for this device or username. Please use a different username or continue with your existing account.';
  }

  String _extractValidationMessage(dynamic responseData) {
    if (responseData is Map<String, dynamic>) {
      final details = responseData['details'];
      if (details is Map<String, dynamic>) {
        final fieldErrors = details['fieldErrors'];
        if (fieldErrors is Map<String, dynamic>) {
          final usernameErrors = fieldErrors['username'];
          if (usernameErrors is List && usernameErrors.isNotEmpty && usernameErrors.first is String) {
            return usernameErrors.first as String;
          }
        }
      }

      final candidates = [responseData['message'], responseData['error'], responseData['detail']];
      for (final value in candidates) {
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
    }
    return 'Invalid registration data. Use 2-30 characters with letters, numbers, or underscore.';
  }

  String _normalizeUsername(String username) {
    final trimmed = username.trim();
    final underscored = trimmed.replaceAll(RegExp(r'\s+'), '_');
    return underscored.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
  }

  Future<UserModel> updateProfile({
    required String userId,
    String? username,
    String? avatarPath,
    String? localAvatar,
    bool? isGhibli,
  }) async {
    final response = await _dio.put(
      '/api/profile/$userId',
      data: {
        if (username != null) 'username': username,
        if (avatarPath != null) 'avatarUrl': avatarPath,
        if (isGhibli != null) 'isGhibli': isGhibli,
        if (localAvatar != null) 'localAvatar': localAvatar,
      },
    );
    
    final updatedData = response.data as Map<String, dynamic>;
    
    // Merge local data
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString(_userKey);
    final current = userData != null ? jsonDecode(userData) : {};

    updatedData['local_avatar'] = localAvatar ?? current['local_avatar'];
    updatedData['is_ghibli'] = isGhibli ?? current['is_ghibli'] ?? false;

    final updated = UserModel.fromJson(updatedData);
    await prefs.setString(_userKey, jsonEncode(updated.toJson()));
    return updated;
  }

  Future<void> updatePracticeDifficulty(String userId, double difficulty) async {
    try {
      await _dio.put(
        '/api/profile/$userId/difficulty',
        data: {'practiceDifficulty': difficulty},
      );
      
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString(_userKey);
      if (userData != null) {
        final current = jsonDecode(userData) as Map<String, dynamic>;
        final stats = current['stats'] as Map<String, dynamic>? ?? {};
        stats['practice_difficulty'] = difficulty;
        current['stats'] = stats;
        await prefs.setString(_userKey, jsonEncode(current));
      }
    } catch (_) {}
  }

  UserModel _resolveRegisteredUser({
    required Map<String, dynamic> responseData,
    required String userId,
    required String fallbackUsername,
    required String deviceId,
  }) {
    final embeddedUser = responseData['user'];
    if (embeddedUser is Map<String, dynamic>) {
      return UserModel.fromJson(embeddedUser);
    }

    return UserModel(
      id: userId,
      username: fallbackUsername,
      avatarUrl: null,
      xp: 0,
      isOnline: true,
      stats: const UserStats(),
      deviceId: deviceId,
    );
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    _dio.options.headers.remove('Authorization');
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final storedToken = prefs.getString(_tokenKey);
    if (storedToken == null) return null;

    final normalized = _normalizeToken(storedToken);
    if (normalized != storedToken) {
      await prefs.setString(_tokenKey, normalized);
    }
    return normalized;
  }

  String _normalizeToken(String token) {
    return token.replaceFirst(RegExp(r'^Bearer\s+', caseSensitive: false), '').trim();
  }

  /// Debug/cleanup method: Remove ALL user session & device data
  /// WARNING: This clears auth token, user profile, and device fingerprint
  /// User will need to enter new username/re-authenticate on next launch
  /// Used for testing session persistence across app restarts
  Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);    // Clear auth token
    await prefs.remove(_userKey);     // Clear user profile
    await prefs.remove(_deviceIdKey); // Clear device fingerprint
    _dio.options.headers.remove('Authorization');
  }
}
