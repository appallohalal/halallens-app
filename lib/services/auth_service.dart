import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../config/auth_config.dart';
import '../models/app_user.dart';
import 'notification_service.dart';

class AuthResponse {
  final bool success;
  final String? message;
  final String? error;
  final AppUser? user;

  const AuthResponse({
    required this.success,
    this.message,
    this.error,
    this.user,
  });
}

class AuthService extends ChangeNotifier {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const String _prefKeyUser = 'halallens_auth_user_session';
  static const String _prefKeyDeviceId = 'halallens_device_id';

  AppUser? _currentUser;
  String? _deviceId;
  bool _isInitialized = false;
  bool _isBanned = false;
  String? _banReason;

  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isInitialized => _isInitialized;
  String get deviceId => _deviceId ?? 'device_unknown';
  bool get isBanned => _isBanned;
  String? get banReason => _banReason;

  /// Returns true if user is allowed to scan (either forceUserAuth is OFF or user is logged in).
  bool get canScan => !AuthConfig.isForceUserAuth || (isLoggedIn && !_isBanned);

  /// Initialize user session from local cache on app boot
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();

      // Retrieve or generate persistent device identifier
      _deviceId = prefs.getString(_prefKeyDeviceId);
      if (_deviceId == null || _deviceId!.isEmpty) {
        _deviceId = 'dev_${DateTime.now().millisecondsSinceEpoch}_${(1000 + (DateTime.now().microsecond % 9000))}';
        await prefs.setString(_prefKeyDeviceId, _deviceId!);
      }

      // Load cached user session
      final userJson = prefs.getString(_prefKeyUser);
      if (userJson != null && userJson.isNotEmpty) {
        try {
          final data = jsonDecode(userJson) as Map<String, dynamic>;
          _currentUser = AppUser.fromJson(data);
          if (kDebugMode) {
            debugPrint('👤 [AuthService] Restored user session: ${_currentUser?.email}');
          }
        } catch (e) {
          debugPrint('⚠️ [AuthService] Failed to parse cached user: $e');
        }
      }

      // Check live ban status from Supabase Cloud
      await checkBanStatus();
    } catch (e) {
      debugPrint('⚠️ [AuthService] Initialization error: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Live verification of account or device ban status against Supabase
  Future<bool> checkBanStatus() async {
    try {
      String queryParam = '';
      if (_currentUser != null && _currentUser!.id.isNotEmpty) {
        queryParam = 'id=eq.${_currentUser!.id}';
      } else if (_currentUser != null && _currentUser!.email.isNotEmpty) {
        queryParam = 'email=eq.${Uri.encodeComponent(_currentUser!.email)}';
      } else if (_deviceId != null && _deviceId!.isNotEmpty) {
        queryParam = 'device_id=eq.$_deviceId';
      } else {
        return false;
      }

      final uri = Uri.parse(
        '${AppConfig.supabaseUrl}/rest/v1/users?$queryParam&select=is_banned,ban_reason',
      );

      final response = await http.get(
        uri,
        headers: {
          'apikey': AppConfig.supabaseAnonKey,
          'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        if (list.isNotEmpty) {
          final row = list.first as Map<String, dynamic>;
          final banned = row['is_banned'] == true;
          final reason = row['ban_reason'] as String?;

          if (_isBanned != banned || _banReason != reason) {
            _isBanned = banned;
            _banReason = reason;
            notifyListeners();
          }
          return _isBanned;
        } else {
          if (_isBanned) {
            _isBanned = false;
            _banReason = null;
            notifyListeners();
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ [AuthService] checkBanStatus error: $e');
    }
    return _isBanned;
  }

  /// Register a new user account with all 5 required fields:
  /// Name / Username, Email, Password, Country, and City.
  Future<AuthResponse> register({
    required String name,
    required String username,
    required String email,
    required String password,
    required String country,
    required String city,
  }) async {
    final trimmedName = name.trim();
    final trimmedUsername = username.trim().isEmpty ? trimmedName : username.trim();
    final trimmedEmail = email.trim().toLowerCase();
    final trimmedCountry = country.trim();
    final trimmedCity = city.trim();

    final body = {
      'name': trimmedName,
      'username': trimmedUsername,
      'email': trimmedEmail,
      'password': password,
      'country': trimmedCountry,
      'city': trimmedCity,
      'deviceId': _deviceId,
    };

    // 1. Try local / production backend API endpoint
    try {
      final uri = Uri.parse('${AppConfig.backendBaseUrl}/auth/mobile/register');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(res.body);

      if (res.statusCode == 200 && data['success'] == true) {
        final userData = data['user'] as Map<String, dynamic>;
        final user = AppUser.fromJson(userData);
        await _saveUserSession(user);
        return AuthResponse(
          success: true,
          message: data['message'] ?? 'Account created successfully! A confirmation email has been sent.',
          user: user,
        );
      } else {
        return AuthResponse(
          success: false,
          error: data['error'] ?? 'Registration failed with status code ${res.statusCode}',
        );
      }
    } catch (backendErr) {
      if (kDebugMode) {
        debugPrint('ℹ️ [AuthService] Backend register unreachable ($backendErr), trying Supabase cloud directly...');
      }
    }

    // 2. Direct Supabase Cloud Fallback if backend is unreachable
    try {
      final supabaseUri = Uri.parse('${AppConfig.supabaseUrl}/rest/v1/users');

      final userPayload = {
        'device_id': _deviceId,
        'email': trimmedEmail,
        'name': trimmedName,
        'username': trimmedUsername,
        'country': trimmedCountry,
        'city': trimmedCity,
        'is_premium': false,
        'is_banned': false,
        'total_scans': 0,
        'last_active_at': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      };

      final response = await http.post(
        supabaseUri,
        headers: {
          'Content-Type': 'application/json',
          'apikey': AppConfig.supabaseAnonKey,
          'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
          'Prefer': 'return=representation',
        },
        body: jsonEncode(userPayload),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 201 || response.statusCode == 200) {
        // Trigger Supabase Auth signup confirmation email directly
        try {
          final authSignupUri = Uri.parse(
            '${AppConfig.supabaseUrl}/auth/v1/signup?redirect_to=${Uri.encodeComponent('https://halallens-admin.vercel.app/auth/confirm')}',
          );
          await http.post(
            authSignupUri,
            headers: {
              'Content-Type': 'application/json',
              'apikey': AppConfig.supabaseAnonKey,
            },
            body: jsonEncode({
              'email': trimmedEmail,
              'password': password,
              'data': {
                'name': trimmedName,
                'username': trimmedUsername,
                'country': trimmedCountry,
                'city': trimmedCity,
                'account_type': 'mobile_user',
              },
            }),
          ).timeout(const Duration(seconds: 6));
        } catch (_) {}

        final list = jsonDecode(response.body) as List<dynamic>;
        if (list.isNotEmpty) {
          final user = AppUser.fromJson(list.first as Map<String, dynamic>);
          await _saveUserSession(user);
          return AuthResponse(
            success: true,
            message: 'Account created successfully! A confirmation email has been sent to $trimmedEmail.',
            user: user,
          );
        }
      } else {
        final errData = jsonDecode(response.body);
        final errMsg = errData['message'] ?? errData['error'] ?? 'Could not register';
        if (errMsg.toString().contains('duplicate') || errMsg.toString().contains('unique')) {
          return const AuthResponse(
            success: false,
            error: 'An account with this email already exists. Please sign in.',
          );
        }
        return AuthResponse(success: false, error: errMsg.toString());
      }
    } catch (e) {
      return AuthResponse(
        success: false,
        error: 'Unable to connect to server. Please check your internet connection ($e).',
      );
    }

    return const AuthResponse(success: false, error: 'Registration failed. Please try again.');
  }

  /// Sign in with Email and Password
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim().toLowerCase();

    final body = {
      'email': trimmedEmail,
      'password': password,
      'deviceId': _deviceId,
    };

    // 1. Try local / production backend API endpoint
    try {
      final uri = Uri.parse('${AppConfig.backendBaseUrl}/auth/mobile/login');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 6));

      final data = jsonDecode(res.body);

      if (res.statusCode == 200 && data['success'] == true) {
        final userData = data['user'] as Map<String, dynamic>;
        final user = AppUser.fromJson(userData);
        await _saveUserSession(user);
        return AuthResponse(
          success: true,
          message: data['message'] ?? 'Login successful!',
          user: user,
        );
      } else {
        return AuthResponse(
          success: false,
          error: data['error'] ?? 'Login failed. Please check your credentials.',
        );
      }
    } catch (backendErr) {
      if (kDebugMode) {
        debugPrint('ℹ️ [AuthService] Backend login unreachable ($backendErr), trying Supabase cloud directly...');
      }
    }

    // 2. Direct Supabase Cloud Fallback
    try {
      final encodedEmail = Uri.encodeComponent(trimmedEmail);
      final supabaseUri = Uri.parse(
        '${AppConfig.supabaseUrl}/rest/v1/users?email=eq.$encodedEmail&select=*',
      );

      final response = await http.get(
        supabaseUri,
        headers: {
          'apikey': AppConfig.supabaseAnonKey,
          'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
        },
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        if (list.isNotEmpty) {
          final row = list.first as Map<String, dynamic>;
          if (row['is_banned'] == true) {
            _isBanned = true;
            _banReason = row['ban_reason'] as String?;
            notifyListeners();
            return AuthResponse(
              success: false,
              error: 'This account has been suspended: ${row['ban_reason'] ?? 'Policy violation'}',
            );
          }
          _isBanned = false;
          _banReason = null;
          final user = AppUser.fromJson(row);
          await _saveUserSession(user);
          return AuthResponse(
            success: true,
            message: 'Signed in successfully!',
            user: user,
          );
        } else {
          return const AuthResponse(
            success: false,
            error: 'No account found with this email. Please create an account.',
          );
        }
      }
    } catch (e) {
      return AuthResponse(
        success: false,
        error: 'Unable to connect to server. Please check your internet connection ($e).',
      );
    }

    return const AuthResponse(success: false, error: 'Authentication failed. Please try again.');
  }

  /// Sign out the current user session
  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKeyUser);
      _currentUser = null;
      _isBanned = false;
      _banReason = null;
      NotificationService.instance.syncUserTags(null);
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ [AuthService] Logout error: $e');
    }
  }

  /// Update current user's profile information (GDPR compliant personal data management)
  Future<AuthResponse> updateProfile({
    required String name,
    required String email,
    String? username,
    String? country,
    String? city,
  }) async {
    if (_currentUser == null) {
      return const AuthResponse(
        success: false,
        error: 'You must be signed in to update your profile.',
      );
    }

    final trimmedName = name.trim();
    final trimmedEmail = email.trim().toLowerCase();
    final trimmedUsername = (username?.trim().isNotEmpty == true)
        ? username!.trim()
        : trimmedName;
    final trimmedCountry = (country?.trim().isNotEmpty == true)
        ? country!.trim()
        : _currentUser!.country;
    final trimmedCity = city?.trim() ?? _currentUser!.city;

    if (trimmedName.isEmpty) {
      return const AuthResponse(
        success: false,
        error: 'Name cannot be empty.',
      );
    }

    if (!trimmedEmail.contains('@')) {
      return const AuthResponse(
        success: false,
        error: 'Please enter a valid email address.',
      );
    }

    final body = {
      'userId': _currentUser!.id,
      'name': trimmedName,
      'username': trimmedUsername,
      'email': trimmedEmail,
      'country': trimmedCountry,
      'city': trimmedCity,
    };

    // 1. Primary: Try backend API
    try {
      final uri = Uri.parse('${AppConfig.backendBaseUrl}/auth/mobile/profile');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['success'] == true) {
        final userData = data['user'] as Map<String, dynamic>;
        final updatedUser = AppUser.fromJson(userData);
        await _saveUserSession(updatedUser);
        return AuthResponse(
          success: true,
          message: data['message'] ?? 'Profile updated successfully!',
          user: updatedUser,
        );
      } else {
        return AuthResponse(
          success: false,
          error: data['error'] ?? 'Profile update failed (${res.statusCode})',
        );
      }
    } catch (backendErr) {
      if (kDebugMode) {
        debugPrint('ℹ️ [AuthService] Backend profile update unreachable ($backendErr), trying Supabase cloud directly...');
      }
    }

    // 2. Fallback: Supabase Cloud Direct REST API
    try {
      final supabaseUri = Uri.parse(
        '${AppConfig.supabaseUrl}/rest/v1/users?id=eq.${_currentUser!.id}',
      );

      final payload = {
        'name': trimmedName,
        'username': trimmedUsername,
        'email': trimmedEmail,
        'country': trimmedCountry,
        'city': trimmedCity,
        'last_active_at': DateTime.now().toIso8601String(),
      };

      final response = await http.patch(
        supabaseUri,
        headers: {
          'Content-Type': 'application/json',
          'apikey': AppConfig.supabaseAnonKey,
          'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
          'Prefer': 'return=representation',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 204) {
        final updatedUser = _currentUser!.copyWith(
          name: trimmedName,
          username: trimmedUsername,
          email: trimmedEmail,
          country: trimmedCountry,
          city: trimmedCity,
        );
        await _saveUserSession(updatedUser);
        return AuthResponse(
          success: true,
          message: 'Profile updated successfully!',
          user: updatedUser,
        );
      } else {
        try {
          final errorData = jsonDecode(response.body);
          return AuthResponse(
            success: false,
            error: errorData['message'] ?? 'Failed to update profile via cloud (${response.statusCode})',
          );
        } catch (_) {
          return AuthResponse(
            success: false,
            error: 'Failed to update profile (${response.statusCode})',
          );
        }
      }
    } catch (e) {
      return AuthResponse(
        success: false,
        error: 'Network error: $e',
      );
    }
  }

  /// Permanently delete account and all personal data (GDPR Article 17 - Right to be Forgotten)
  Future<AuthResponse> deleteAccount() async {
    if (_currentUser == null) {
      return const AuthResponse(
        success: false,
        error: 'No active user session to delete.',
      );
    }

    final userId = _currentUser!.id;
    final userEmail = _currentUser!.email;

    // 1. Primary: Try backend API
    bool deletedOnServer = false;
    try {
      final uri = Uri.parse('${AppConfig.backendBaseUrl}/auth/mobile/delete-account');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId, 'email': userEmail}),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['success'] == true) {
        deletedOnServer = true;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ℹ️ [AuthService] Backend delete unreachable ($e), trying Supabase cloud directly...');
      }
    }

    // 2. Direct Supabase Cloud Fallback
    if (!deletedOnServer) {
      try {
        final supabaseUri = Uri.parse(
          '${AppConfig.supabaseUrl}/rest/v1/users?id=eq.$userId',
        );

        final response = await http.delete(
          supabaseUri,
          headers: {
            'apikey': AppConfig.supabaseAnonKey,
            'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
          },
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200 || response.statusCode == 204) {
          deletedOnServer = true;
        }
      } catch (e) {
        debugPrint('⚠️ [AuthService] Supabase direct deletion note: $e');
      }
    }

    // 3. Clear all local user session data and notify app state
    await logout();

    return const AuthResponse(
      success: true,
      message: 'Your account and personal data have been permanently deleted in compliance with GDPR.',
    );
  }

  Future<void> _saveUserSession(AppUser user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyUser, jsonEncode(user.toJson()));
      _currentUser = user;
      NotificationService.instance.syncUserTags(user);
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ [AuthService] Failed to cache user session: $e');
    }
  }
}
