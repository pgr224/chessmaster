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
  static const _lastUsernameKey = 'last_logged_out_username';
  static const _explicitLogoutKey = 'is_explicit_logout';
  static final RegExp _usernamePattern = RegExp(r'^[a-zA-Z0-9_]{3,30}$');
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

  /// Read ONLY from local cache — never touches network.
  /// This is the safe fallback when network is unavailable.
  Future<UserModel?> getCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString(_userKey);
    if (userData == null) return null;
    try {
      final Map<String, dynamic> data = jsonDecode(userData);
      return UserModel.fromJson(data);
    } catch (e) {
      print('User session decode error: $e');
      return null;
    }
  }

  Future<UserModel?> getCurrentUser({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);

    // If we have a token and don't need refresh, just return cached data
    if (token != null && !forceRefresh) {
      return getCachedUser();
    }

    // No token or force refresh — try server login
    if (token == null || forceRefresh) {
      final isExplicitLogout = prefs.getBool(_explicitLogoutKey) ?? false;
      if (isExplicitLogout && !forceRefresh) {
        // User explicitly logged out, don't auto-login unless forced
        return null;
      }

      try {
        final user = await login();
        return user;
      } catch (_) {
        // Server unreachable or device not registered.
        // Fall through to check locally cached data below.
      }
    }

    // Final fallback: return whatever is in local cache
    return getCachedUser();
  }

  Future<UserModel> login() async {
    final deviceId = await getDeviceId();
    final response = await _dio.post(
      '/api/auth/login',
      data: {'deviceId': deviceId},
      options: Options(
        validateStatus: (status) => status == 200 || status == 404,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ),
    );

    if (response.statusCode == 404) {
      // Not a real error, just means user needs to register
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
      );
    }

    final rawToken =
        (response.data['token'] ?? response.data['accessToken']) as String;
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
    
    // Success! Clear logout flag and store last username for potential future use
    await prefs.setBool(_explicitLogoutKey, false);
    await prefs.setString(_lastUsernameKey, profile.username);
    
    return profile;
  }

  Future<bool> checkUsername(String username) async {
    try {
      final response = await _dio.get('/api/auth/check-username',
          queryParameters: {'username': username});
      return response.data['available'] == true;
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    return {};
  }

  /// Check username availability with detailed rate limit information
  Future<Map<String, dynamic>> checkUsernameAvailability(String username) async {
    try {
      final normalized = username.trim();
      final response = await _dio.get(
        '/api/profile/check-username/$normalized',
        options: Options(
          validateStatus: (_) => true,
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      
      final data = _asMap(response.data);
      if (response.statusCode == 200) {
        return {
          'available': data['available'] == true,
          'canChangeNow': data['canChangeNow'] == true,
          'remainingLifetimeChanges': data['remainingLifetimeChanges'] ?? 3,
          'nextChangeTime': data['nextChangeTime'],
          'reason': data['reason'],
        };
      } else {
        return {
          'available': null,
          'error': data['error'] ?? 'Check failed',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      return {
        'available': null,
        'error': 'Network error',
      };
    }
  }

  Future<UserModel> register(
      {required String username, String? avatarPath}) async {
    final normalizedUsername = _normalizeUsername(username);
    if (!_usernamePattern.hasMatch(normalizedUsername)) {
      throw Exception(
          'Username must be 3-30 characters and use only letters, numbers, or underscore.');
    }

    final deviceId = await getDeviceId();

    final response = await _dio.post(
      '/api/auth/register',
      data: {'username': normalizedUsername, 'deviceId': deviceId},
      options: Options(
        validateStatus: (status) {
          if (status == null) return false;
          return status >= 200 && status < 500;
        },
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
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

    final rawToken =
        (response.data['token'] ?? response.data['accessToken']) as String;
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
    
    // Success! Clear logout flag and store last username
    await prefs.setBool(_explicitLogoutKey, false);
    await prefs.setString(_lastUsernameKey, profile.username);

    return profile;
  }

  Future<UserModel?> _recoverFromRegisterConflict({
    required dynamic responseData,
    required String fallbackUsername,
    required String deviceId,
  }) async {
    if (responseData is! Map<String, dynamic>) return null;

    final tokenValue = responseData['token'] ?? responseData['accessToken'];
    final userIdValue = responseData['userId'] ??
        (responseData['user'] is Map<String, dynamic>
            ? responseData['user']['id']
            : null);

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
      final candidates = [
        responseData['message'],
        responseData['error'],
        responseData['detail']
      ];
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
          if (usernameErrors is List &&
              usernameErrors.isNotEmpty &&
              usernameErrors.first is String) {
            return usernameErrors.first as String;
          }
        }
      }

      final candidates = [
        responseData['message'],
        responseData['error'],
        responseData['detail']
      ];
      for (final value in candidates) {
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
    }
    return 'Invalid registration data. Use 3-30 characters with letters, numbers, or underscore.';
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
      options: Options(
        validateStatus: (status) {
          if (status == null) return false;
          return status >= 200 && status < 500;
        },
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
      ),
    );

    // Handle specific error responses for username changes
    if (response.statusCode == 429) {
      // Cooldown active
      final error = response.data as Map<String, dynamic>;
      final cooldownRemainingMs = error['cooldownRemainingMs'] as int?;
      final nextChangeTime = error['nextChangeTime'] as int?;
      throw Exception(
        'COOLDOWN_ACTIVE::${cooldownRemainingMs ?? 0}::${nextChangeTime ?? 0}'
      );
    } else if (response.statusCode == 403) {
      // Lifetime limit reached or other auth error
      final error = response.data as Map<String, dynamic>;
      final errorType = error['error'] as String?;
      if (errorType == 'LIFETIME_LIMIT_REACHED') {
        throw Exception('LIFETIME_LIMIT_REACHED');
      }
      throw Exception('Permission denied');
    } else if (response.statusCode == 409) {
      throw Exception('Username already taken');
    } else if (response.statusCode != 200) {
      final error = response.data as Map<String, dynamic>?;
      final errorMsg = error?['error'] ?? 'Failed to update profile';
      throw Exception(errorMsg);
    }

    final updatedData = response.data as Map<String, dynamic>;
    final prefs = await SharedPreferences.getInstance();

    if (updatedData.containsKey('token') && updatedData['token'] != null) {
      final token = _normalizeToken(updatedData['token'] as String);
      await prefs.setString(_tokenKey, token);
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }

    // Merge local data
    final userData = prefs.getString(_userKey);
    final current = userData != null ? jsonDecode(userData) : {};

    updatedData['local_avatar'] = localAvatar ?? current['local_avatar'];
    updatedData['is_ghibli'] = isGhibli ?? current['is_ghibli'] ?? false;

    final updated = UserModel.fromJson(updatedData);
    await prefs.setString(_userKey, jsonEncode(updated.toJson()));
    return updated;
  }

  Future<void> updateXPProgress({
    required String userId,
    required int xpDelta,
    required Map<String, dynamic> statUpdates,
    bool isOnlineMatch = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString(_userKey);
    if (userData == null) return;

    try {
      final dynamic decoded = jsonDecode(userData);
      if (decoded is! Map<String, dynamic>) return;

      final current = decoded;
      final currentStats = current['stats'] as Map<String, dynamic>? ?? {};

      // Update local data first (for instant feedback/offline play)
      current['xp'] = (current['xp'] as int? ?? 0) + xpDelta;
      statUpdates.forEach((key, value) {
        if (value is int) {
          currentStats[key] = (currentStats[key] as int? ?? 0) + value;
        } else {
          currentStats[key] = value;
        }
      });
      current['stats'] = currentStats;
      await prefs.setString(_userKey, jsonEncode(current));

      // Push to server
      await _dio.post(
        '/api/profile/$userId/xp',
        data: {
          'xpDelta': xpDelta,
          'stats': statUpdates,
          'isOnlineMatch': isOnlineMatch,
        },
      );
    } catch (_) {
      // Silent fail for network, data is already saved locally in prefs
    }
  }

  Future<void> updatePracticeDifficulty(
      String userId, double difficulty) async {
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

  Future<bool> donateXP(
      {required String recipientId, required int amount, int? requestId}) async {
    try {
      if (amount <= 0) {
        throw Exception('Donation amount must be greater than 0.');
      }

      final response = await _dio.post(
        '/api/profile/xp/transfer',
        data: {
          'recipientId': recipientId,
          'amount': amount,
          if (requestId != null) 'requestId': requestId,
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        final userData = prefs.getString(_userKey);
        if (userData != null) {
          final dynamic decoded = jsonDecode(userData);
          if (decoded is Map<String, dynamic>) {
            final Map<String, dynamic> current = decoded;
            final statsJson =
                (current['stats'] as Map<String, dynamic>?) ?? <String, dynamic>{};
            final donationStats = response.data['donorDonationStats'] as Map<String, dynamic>?;
            final donorXpRaw = response.data['donorXp'];

            final serverDonorXp = donorXpRaw is num
                ? donorXpRaw.toInt()
                : ((current['xp'] as num?)?.toInt() ?? 0) - amount;

            current['xp'] = serverDonorXp;
            if (donationStats != null) {
              statsJson['daily_donated_xp'] =
                  (donationStats['dailyDonatedXP'] as num?)?.toInt() ??
                      (statsJson['daily_donated_xp'] as int? ?? 0);
              statsJson['total_donated_xp'] =
                  (donationStats['totalDonatedXP'] as num?)?.toInt() ??
                      (statsJson['total_donated_xp'] as int? ?? 0);
              statsJson['last_donation_date'] =
                  donationStats['lastDonationDate']?.toString();
            }
            current['stats'] = statsJson;
            await prefs.setString(_userKey, jsonEncode(current));
          }
        }

        // Best-effort server re-sync to keep all game modes and boards consistent.
        try {
          await getCurrentUser(forceRefresh: true);
        } catch (_) {}
        return true;
      }
    } catch (e) {
      print('Failed to donate XP: $e');
      rethrow;
    }
    return false;
  }

  Future<bool> broadcastXPRequest({required int amount}) async {
    try {
      final response = await _dio.post(
        '/api/profile/xp/broadcast-request',
        data: {'amount': amount},
      );
      return response.statusCode == 200 && response.data['success'] == true;
    } catch (e) {
      print('Failed to broadcast XP request: $e');
    }
    return false;
  }

  Future<List<dynamic>> getActiveBroadcastRequests() async {
    try {
      final response = await _dio.get('/api/profile/xp/broadcast-requests');
      if (response.statusCode == 200) {
        return response.data['requests'] as List<dynamic>;
      }
    } catch (e) {
      print('Failed to fetch broadcast requests: $e');
    }
    return [];
  }

  Future<List<UserModel>> getLeaderboard({int limit = 100}) async {
    try {
      final response = await _dio.get(
        '/api/leaderboard',
        queryParameters: {'limit': limit},
      );
      if (response.statusCode == 200) {
        final List data = response.data['leaderboard'] as List;
        return data.map((json) => UserModel.fromJson(json)).toList();
      }
    } catch (e) {
      print('Failed to fetch leaderboard: $e');
    }
    return [];
  }

  Future<bool> requestXP({required int amount}) async {
    try {
      final response = await _dio.post(
        '/api/profile/xp/request',
        data: {'amount': amount},
      );
      return response.statusCode == 200 && response.data['success'] == true;
    } catch (e) {
      print('Failed to request XP: $e');
      return false;
    }
  }

  Future<bool> requestXPFromFriend(
      {required String friendUserId, required int amount}) async {
    try {
      final response = await _dio.post(
        '/api/profile/xp/request',
        data: {
          'amount': amount,
          'targetUserId': friendUserId,
        },
      );
      return response.statusCode == 200 && response.data['success'] == true;
    } catch (e) {
      print('Failed to send direct XP request: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getXpRequestById(int requestId) async {
    try {
      final response = await _dio.get('/api/profile/xp/request/$requestId');
      if (response.statusCode == 200 && response.data['success'] == true) {
        return Map<String, dynamic>.from(response.data['request'] as Map);
      }
    } catch (e) {
      print('Failed to fetch XP request: $e');
    }
    return null;
  }

  Future<bool> respondToXpRequest(
      {required int requestId, required String action}) async {
    try {
      final response = await _dio.post(
        '/api/profile/xp/request/$requestId/respond',
        data: {'action': action},
      );
      return response.statusCode == 200 && response.data['success'] == true;
    } catch (e) {
      print('Failed to respond to XP request: $e');
      return false;
    }
  }

  Future<bool> sendFriendRequest({required String friendUserId}) async {
    try {
      final response = await _dio.post(
        '/api/profile/xp/friends/request',
        data: {'friendUserId': friendUserId},
      );
      return response.statusCode == 200 && response.data['success'] == true;
    } catch (e) {
      print('Failed to send friend request: $e');
      return false;
    }
  }

  Future<bool> unlockAchievement({
    required String userId,
    required String achievementId,
    required int points,
  }) async {
    try {
      final response = await _dio.post(
        '/api/profile/$userId/unlock-achievement',
        data: {
          'achievementId': achievementId,
          'points': points,
        },
      );
      return response.statusCode == 200 && response.data['success'] == true;
    } catch (e) {
      print('Failed to unlock achievement on server: $e');
      return false;
    }
  }

  Future<bool> respondToFriendRequest(
      {required String friendUserId, required String action}) async {
    try {
      final response = await _dio.post(
        '/api/profile/xp/friends/$friendUserId/respond',
        data: {'action': action},
      );
      return response.statusCode == 200 && response.data['success'] == true;
    } catch (e) {
      print('Failed to respond to friend request: $e');
      return false;
    }
  }

  Future<List<dynamic>> getFriends() async {
    try {
      final response = await _dio.get('/api/profile/xp/friends');
      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['friends'] as List<dynamic>;
      }
    } catch (e) {
      print('Failed to fetch friends: $e');
    }
    return [];
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
    
    // Store last username before clearing user data
    final userData = prefs.getString(_userKey);
    if (userData != null) {
      try {
        final data = jsonDecode(userData);
        if (data['username'] != null) {
          await prefs.setString(_lastUsernameKey, data['username']);
        }
      } catch (_) {}
    }

    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    await prefs.setBool(_explicitLogoutKey, true); // Mark as explicitly logged out
    _dio.options.headers.remove('Authorization');
  }

  Future<String?> getLastLoggedOutUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastUsernameKey);
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
    return token
        .replaceFirst(RegExp(r'^Bearer\s+', caseSensitive: false), '')
        .trim();
  }

  /// Reset all numerical stats, XP, and Elos for the current user.
  Future<UserModel?> resetUserStats() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString(_userKey);
    if (userData == null) return null;

    try {
      final Map<String, dynamic> current = jsonDecode(userData);
      final String userId = current['id'] as String;

      // Reset locally
      current['xp'] = 0;
      current['stats'] = const UserStats().toJson();
      await prefs.setString(_userKey, jsonEncode(current));

      // Reset on server
      await _dio.post('/api/profile/$userId/reset-stats');

      // Mark as reset for the new system
      await prefs.setBool('system_reset_v2', true);

      return UserModel.fromJson(current);
    } catch (e) {
      print('Reset stats error: $e');
      return null;
    }
  }

  /// Check and perform one-time systemic reset if needed
  Future<void> checkSystemicReset() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyReset = prefs.getBool('system_reset_v2') ?? false;
    if (!alreadyReset) {
      await resetUserStats();
    }
  }

  /// Debug/cleanup method: Remove ALL user session & device data
  /// WARNING: This clears auth token, user profile, and device fingerprint
  /// User will need to enter new username/re-authenticate on next launch
  /// Used for testing session persistence across app restarts
  Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey); // Clear auth token
    await prefs.remove(_userKey); // Clear user profile
    await prefs.remove(_deviceIdKey); // Clear device fingerprint
    await prefs.remove('system_reset_v2'); // Clear reset flag
    _dio.options.headers.remove('Authorization');
  }
}
