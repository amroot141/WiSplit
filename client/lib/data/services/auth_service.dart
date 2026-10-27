import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/local_database.dart';
import '../models/user_session_model.dart';

class AuthService {
  static const String _supabaseUrl = 'https://pmkwpizzpfxykhrumoge.supabase.co/auth/v1';
  static const String _supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBta3dwaXp6cGZ4eWtocnVtb2dlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMwODczODUsImV4cCI6MjEwODY2MzM4NX0.NYW0lOY1zJIrlIHT-dS7nx_iNyzPtYRT7RguP38ygj0';

  final http.Client _httpClient;

  AuthService({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  Map<String, String> get _headers => {
        'apikey': _supabaseAnonKey,
        'Authorization': 'Bearer $_supabaseAnonKey',
        'Content-Type': 'application/json',
      };

  /// Retrieves the active logged-in user from local SQLite
  Future<UserSession?> getActiveSession() async {
    final db = await LocalDatabase.instance.database;
    final rows = await db.query(
      'user_session',
      where: 'is_logged_in = 1',
      limit: 1,
    );
    if (rows.isNotEmpty) {
      return UserSession.fromMap(rows.first);
    }
    return null;
  }

  /// Persists session in local SQLite
  Future<void> saveSession(UserSession session) async {
    final db = await LocalDatabase.instance.database;
    await db.transaction((txn) async {
      // Mark all old sessions as logged out
      await txn.update('user_session', {'is_logged_in': 0});
      // Insert or replace current session
      await txn.insert(
        'user_session',
        session.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  /// Clears active session on logout
  Future<void> clearSession() async {
    final db = await LocalDatabase.instance.database;
    await db.update('user_session', {'is_logged_in': 0});
  }

  /// Restores cloud backed-up groups and expenses into local SQLite
  Future<void> restoreCloudBackup(Map<String, dynamic> userMeta) async {
    try {
      final db = await LocalDatabase.instance.database;

      // 1. Restore Groups
      final groupsRaw = userMeta['groups_backup'];
      if (groupsRaw is List) {
        for (final item in groupsRaw) {
          if (item is Map) {
            final groupMap = Map<String, dynamic>.from(item);
            await db.insert(
              'cached_groups',
              groupMap,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
      }

      // 2. Restore Expenses
      final expensesRaw = userMeta['expenses_backup'];
      if (expensesRaw is List) {
        for (final item in expensesRaw) {
          if (item is Map) {
            final expMap = Map<String, dynamic>.from(item);
            await db.insert(
              'cached_expenses',
              expMap,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
      }
    } catch (_) {}
  }

  /// Uploads local SQLite snapshot (groups & expenses) to Supabase user_metadata
  Future<void> syncAccountDataToCloud() async {
    try {
      final session = await getActiveSession();
      if (session == null || session.accessToken == null || session.accessToken!.isEmpty) {
        return;
      }

      final db = await LocalDatabase.instance.database;
      final groups = await db.query('cached_groups');
      final expenses = await db.query('cached_expenses');

      final uri = Uri.parse('$_supabaseUrl/user');
      await _httpClient.put(
        uri,
        headers: {
          'apikey': _supabaseAnonKey,
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'data': {
            'groups_backup': groups,
            'expenses_backup': expenses,
          },
        }),
      );
    } catch (_) {}
  }

  /// Pulls latest cloud snapshot and restores missing data
  Future<void> syncAccountDataFromCloud() async {
    try {
      final session = await getActiveSession();
      if (session == null || session.accessToken == null || session.accessToken!.isEmpty) {
        return;
      }

      final uri = Uri.parse('$_supabaseUrl/user');
      final response = await _httpClient.get(
        uri,
        headers: {
          'apikey': _supabaseAnonKey,
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        final userMeta = data['user_metadata'] as Map<String, dynamic>?;
        if (userMeta != null) {
          await restoreCloudBackup(userMeta);
        }
      }
    } catch (_) {}
  }

  /// Real Supabase GoTrue Sign Up
  Future<UserSession> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final uri = Uri.parse('$_supabaseUrl/signup');
    final response = await _httpClient.post(
      uri,
      headers: _headers,
      body: jsonEncode({
        'email': email,
        'password': password,
        'data': {'full_name': fullName},
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final user = data['user'] ?? data;
      final userId = user['id'] as String? ?? const Uuid().v4();
      final accessToken = data['access_token'] as String?;
      final refreshToken = data['refresh_token'] as String?;

      final session = UserSession(
        userId: userId,
        email: email,
        fullName: fullName,
        accessToken: accessToken,
        refreshToken: refreshToken,
        isLoggedIn: accessToken != null,
      );

      if (session.isLoggedIn) {
        await saveSession(session);
      }
      return session;
    } else {
      final msg = data['msg'] ?? data['error_description'] ?? data['message'] ?? 'Sign up failed';
      throw Exception(msg);
    }
  }

  /// Real Supabase GoTrue Sign In
  Future<UserSession> signIn({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('$_supabaseUrl/token?grant_type=password');
    final response = await _httpClient.post(
      uri,
      headers: _headers,
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final user = data['user'] as Map<String, dynamic>;
      final userMeta = user['user_metadata'] as Map<String, dynamic>?;
      final fullName = userMeta?['full_name'] as String? ?? email.split('@').first;
      final userId = user['id'] as String;

      final session = UserSession(
        userId: userId,
        email: email,
        fullName: fullName,
        accessToken: data['access_token'] as String?,
        refreshToken: data['refresh_token'] as String?,
        isLoggedIn: true,
      );

      await saveSession(session);
      if (userMeta != null) {
        await restoreCloudBackup(userMeta);
      }
      return session;
    } else {
      final msg = data['error_description'] ?? data['msg'] ?? data['message'] ?? 'Invalid credentials';
      throw Exception(msg);
    }
  }

  /// Verify 6-digit email signup OTP
  Future<UserSession> verifyOtp({
    required String email,
    required String token,
  }) async {
    final uri = Uri.parse('$_supabaseUrl/verify');
    
    // First try with type: 'signup'
    var response = await _httpClient.post(
      uri,
      headers: _headers,
      body: jsonEncode({
        'type': 'signup',
        'email': email,
        'token': token,
      }),
    );

    // If signup type fails, retry with type: 'email' (Magic link / email OTP)
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final retry = await _httpClient.post(
        uri,
        headers: _headers,
        body: jsonEncode({
          'type': 'email',
          'email': email,
          'token': token,
        }),
      );
      if (retry.statusCode >= 200 && retry.statusCode < 300) {
        response = retry;
      }
    }

    final data = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final user = (data['user'] as Map<String, dynamic>?) ?? data;
      final userMeta = user['user_metadata'] as Map<String, dynamic>?;
      final fullName = userMeta?['full_name'] as String? ?? email.split('@').first;
      final userId = (user['id'] as String?) ?? const Uuid().v4();

      final session = UserSession(
        userId: userId,
        email: email,
        fullName: fullName,
        accessToken: data['access_token'] as String?,
        refreshToken: data['refresh_token'] as String?,
        isLoggedIn: true,
      );

      await saveSession(session);
      if (userMeta != null) {
        await restoreCloudBackup(userMeta);
      }
      return session;
    } else {
      final msg = data['msg'] ?? data['error_description'] ?? data['message'] ?? 'OTP verification failed';
      throw Exception(msg);
    }
  }

  /// Resend verification code
  Future<void> resendOtp({required String email}) async {
    final uri = Uri.parse('$_supabaseUrl/resend');
    final response = await _httpClient.post(
      uri,
      headers: _headers,
      body: jsonEncode({
        'type': 'signup',
        'email': email,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final data = jsonDecode(response.body);
      final msg = data['msg'] ?? data['message'] ?? 'Failed to resend code';
      throw Exception(msg);
    }
  }

  /// Create local guest account (instant access, 100% offline & reliable)
  Future<UserSession> continueAsGuest({String name = 'User'}) async {
    final guestId = const Uuid().v4();
    final session = UserSession(
      userId: guestId,
      email: '${name.toLowerCase().replaceAll(' ', '')}@local.wisplit',
      fullName: name,
      isLoggedIn: true,
    );

    await saveSession(session);
    return session;
  }
}
