import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';

import '../../core/database/local_database.dart';
import '../models/expense_models.dart';
import '../models/group_model.dart';
import 'auth_service.dart';

class CloudSyncService {
  static final CloudSyncService instance = CloudSyncService._init();
  CloudSyncService._init({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  factory CloudSyncService({http.Client? httpClient}) {
    if (httpClient != null) {
      return CloudSyncService._init(httpClient: httpClient);
    }
    return instance;
  }

  final http.Client _httpClient;

  static const String _supabaseBaseUrl = 'https://pmkwpizzpfxykhrumoge.supabase.co';
  static const String _supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBta3dwaXp6cGZ4eWtocnVtb2dlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMwODczODUsImV4cCI6MjEwODY2MzM4NX0.NYW0lOY1zJIrlIHT-dS7nx_iNyzPtYRT7RguP38ygj0';

  Future<Map<String, String>> _headers() async {
    final session = await AuthService().getActiveSession();
    final token = session?.accessToken;
    return {
      'apikey': _supabaseAnonKey,
      'Authorization': 'Bearer ${token ?? _supabaseAnonKey}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Prefer': 'resolution=merge-duplicates,return=representation',
    };
  }

  /// Canonical invite code from group ID (e.g. WS-8A9F2B)
  static String formatInviteCode(String groupId) {
    final clean = groupId.replaceAll('-', '').toUpperCase();
    final prefix = clean.length >= 6 ? clean.substring(0, 6) : clean;
    return 'WS-$prefix';
  }

  /// Cleans and extracts the raw code from user input
  static String normalizeCode(String input) {
    String clean = input.trim();
    if (clean.toUpperCase().startsWith('WS-')) {
      clean = clean.substring(3);
    }
    return clean.replaceAll('-', '').trim();
  }

  /// Encodes group metadata into a compact URL-safe token
  static String encodeGroupToken(GroupModel group) {
    final payload = {
      'id': group.id,
      'name': group.name,
      'description': group.description,
      'currency': group.currency,
      'created_by': group.createdBy,
      'members': group.members,
      'created_at': group.createdAt.toIso8601String(),
    };
    return 'WS-T-${base64Url.encode(utf8.encode(jsonEncode(payload)))}';
  }

  /// Attempts to decode a compact group token
  static GroupModel? decodeGroupToken(String token) {
    try {
      String raw = token.trim();
      if (raw.startsWith('WS-T-')) {
        raw = raw.substring(5);
      }
      final jsonStr = utf8.decode(base64Url.decode(raw));
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return GroupModel(
        id: map['id'] as String,
        name: map['name'] as String,
        description: (map['description'] as String?) ?? '',
        currency: (map['currency'] as String?) ?? 'INR',
        createdBy: (map['created_by'] as String?) ?? '',
        members: (map['members'] as List?)?.map((e) => e.toString()).toList() ?? [],
        createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Publishes or updates a group in Supabase cloud
  Future<void> publishGroup(GroupModel group) async {
    try {
      final headers = await _headers();
      final inviteCode = formatInviteCode(group.id);

      // 1. Try upserting to shared_groups
      final uri = Uri.parse('$_supabaseBaseUrl/rest/v1/shared_groups');
      final body = jsonEncode({
        'id': group.id,
        'invite_code': inviteCode,
        'name': group.name,
        'description': group.description,
        'currency': group.currency,
        'created_by': group.createdBy,
        'members_json': jsonEncode(group.members),
        'created_at': group.createdAt.toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      await _httpClient
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 4));
    } catch (_) {
      // Offline or table not configured; fallback safely
    }
  }

  /// Finds a group by invite code (e.g. "WS-8A9F" or "8A9F" or compact token)
  Future<GroupModel?> findGroupByInviteCode(String inputCode) async {
    final trimmed = inputCode.trim();
    if (trimmed.isEmpty) return null;

    // 1. Check if input is a compact self-contained token
    if (trimmed.startsWith('WS-T-') || trimmed.length > 30 && !trimmed.contains('-')) {
      final decoded = decodeGroupToken(trimmed);
      if (decoded != null) return decoded;
    }

    // 2. Check local database first (if user is already in this group or created it)
    final localDb = await LocalDatabase.instance.database;
    final clean = normalizeCode(trimmed).toLowerCase();

    final localRows = await localDb.query('cached_groups');
    for (final r in localRows) {
      final g = GroupModel.fromMap(r);
      final gClean = normalizeCode(g.id).toLowerCase();
      final gCodeClean = normalizeCode(formatInviteCode(g.id)).toLowerCase();
      if (gClean.startsWith(clean) || gCodeClean == clean || clean.startsWith(gCodeClean)) {
        return g;
      }
    }

    // 3. Query Supabase PostgREST shared_groups
    try {
      final headers = await _headers();
      final fullInviteCode = 'WS-${clean.toUpperCase()}';

      // Query shared_groups by invite_code or id prefix
      final uri = Uri.parse(
        '$_supabaseBaseUrl/rest/v1/shared_groups?or=(invite_code.eq.$fullInviteCode,invite_code.ilike.*$clean*,id.ilike.*$clean*)',
      );

      final resp = await _httpClient
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 5));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final List list = jsonDecode(resp.body) as List;
        if (list.isNotEmpty) {
          final item = list.first as Map<String, dynamic>;
          List<String> members = [];
          if (item['members_json'] != null) {
            try {
              final decoded = jsonDecode(item['members_json'] as String);
              if (decoded is List) {
                members = decoded.map((e) => e.toString()).toList();
              }
            } catch (_) {}
          }

          return GroupModel(
            id: item['id'] as String,
            name: item['name'] as String,
            description: (item['description'] as String?) ?? '',
            currency: (item['currency'] as String?) ?? 'INR',
            createdBy: (item['created_by'] as String?) ?? '',
            members: members,
            createdAt: DateTime.tryParse(item['created_at']?.toString() ?? '') ?? DateTime.now(),
          );
        }
      }
    } catch (_) {}

    // 4. Query public.groups table fallback
    try {
      final headers = await _headers();
      final uri = Uri.parse(
        '$_supabaseBaseUrl/rest/v1/groups?id=ilike.$clean*',
      );

      final resp = await _httpClient
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 5));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final List list = jsonDecode(resp.body) as List;
        if (list.isNotEmpty) {
          final item = list.first as Map<String, dynamic>;
          return GroupModel(
            id: item['id'] as String,
            name: item['name'] as String,
            description: (item['description'] as String?) ?? '',
            currency: (item['currency'] as String?) ?? 'INR',
            createdBy: (item['created_by'] as String?) ?? '',
            members: [],
            createdAt: DateTime.tryParse(item['created_at']?.toString() ?? '') ?? DateTime.now(),
          );
        }
      }
    } catch (_) {}

    return null;
  }

  /// Joins a group with the given invite code, adds the user, and syncs expenses
  Future<GroupModel?> joinGroupWithCode({
    required String inviteCode,
    required String newMemberName,
    required String currentUserId,
  }) async {
    final group = await findGroupByInviteCode(inviteCode);
    if (group == null) return null;

    final trimmedMember = newMemberName.trim().isEmpty ? 'Member' : newMemberName.trim();
    final updatedMembers = Set<String>.from(group.members);
    updatedMembers.add(trimmedMember);
    if (currentUserId.isNotEmpty && !updatedMembers.contains(currentUserId)) {
      // Also ensure current user ID or name is recognized
      updatedMembers.add(trimmedMember);
    }

    final updatedGroup = group.copyWith(members: updatedMembers.toList());

    // 1. Save group locally in SQLite
    final db = await LocalDatabase.instance.database;
    await db.insert(
      'cached_groups',
      updatedGroup.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // 2. Push updated members back to cloud so other person sees them
    await publishGroup(updatedGroup);

    // 3. Fetch and import any existing expenses for this group
    await pullGroupExpenses(updatedGroup.id);

    // 4. Account backup
    AuthService().syncAccountDataToCloud();

    return updatedGroup;
  }

  /// Pulls the latest cloud expenses for a group and inserts missing ones into local SQLite
  Future<List<Expense>> pullGroupExpenses(String groupId) async {
    final db = await LocalDatabase.instance.database;
    final List<Expense> fetched = [];

    // 1. Try pulling from shared_groups.expenses_json
    try {
      final headers = await _headers();
      final uri = Uri.parse('$_supabaseBaseUrl/rest/v1/shared_groups?id=eq.$groupId&select=expenses_json');
      final resp = await _httpClient.get(uri, headers: headers).timeout(const Duration(seconds: 4));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final list = jsonDecode(resp.body) as List;
        if (list.isNotEmpty) {
          final expRaw = list.first['expenses_json'];
          if (expRaw is String && expRaw.isNotEmpty) {
            final decoded = jsonDecode(expRaw) as List;
            for (final item in decoded) {
              if (item is Map) {
                final exp = Expense.fromJson(Map<String, dynamic>.from(item));
                fetched.add(exp);
              }
            }
          }
        }
      }
    } catch (_) {}

    // 2. Try pulling from public.expenses table
    if (fetched.isEmpty) {
      try {
        final headers = await _headers();
        final uri = Uri.parse('$_supabaseBaseUrl/rest/v1/expenses?group_id=eq.$groupId&select=*');
        final resp = await _httpClient.get(uri, headers: headers).timeout(const Duration(seconds: 4));

        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          final list = jsonDecode(resp.body) as List;
          for (final item in list) {
            if (item is Map) {
              final exp = Expense.fromJson(Map<String, dynamic>.from(item));
              fetched.add(exp);
            }
          }
        }
      } catch (_) {}
    }

    // Merge into local SQLite
    if (fetched.isNotEmpty) {
      await db.transaction((txn) async {
        for (final exp in fetched) {
          await txn.insert(
            'cached_expenses',
            {
              'id': exp.id,
              'group_id': exp.groupId,
              'paid_by': exp.paidBy,
              'amount': exp.amount,
              'currency': exp.currency,
              'description': exp.description,
              'split_type': exp.splitType.toJson(),
              'created_at': exp.createdAt.toIso8601String(),
              'splits_json': jsonEncode(exp.splits.map((s) => s.toJson()).toList()),
              'is_synced': 1,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
    }

    return fetched;
  }

  /// Syncs an individual group with cloud (checks for new members or expenses added by other users)
  Future<bool> syncGroup(String groupId) async {
    try {
      final db = await LocalDatabase.instance.database;
      final localRows = await db.query(
        'cached_groups',
        where: 'id = ?',
        whereArgs: [groupId],
        limit: 1,
      );

      if (localRows.isEmpty) return false;
      final localGroup = GroupModel.fromMap(localRows.first);

      // 1. Fetch remote group metadata
      final headers = await _headers();
      final uri = Uri.parse('$_supabaseBaseUrl/rest/v1/shared_groups?id=eq.$groupId');
      final resp = await _httpClient.get(uri, headers: headers).timeout(const Duration(seconds: 4));

      bool changed = false;

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final list = jsonDecode(resp.body) as List;
        if (list.isNotEmpty) {
          final item = list.first as Map<String, dynamic>;
          List<String> remoteMembers = [];
          if (item['members_json'] != null) {
            try {
              final decoded = jsonDecode(item['members_json'] as String);
              if (decoded is List) {
                remoteMembers = decoded.map((e) => e.toString()).toList();
              }
            } catch (_) {}
          }

          // Union of members
          final mergedMembers = {...localGroup.members, ...remoteMembers}.toList();
          if (mergedMembers.length != localGroup.members.length) {
            final updated = localGroup.copyWith(members: mergedMembers);
            await db.update(
              'cached_groups',
              updated.toMap(),
              where: 'id = ?',
              whereArgs: [groupId],
            );
            changed = true;
          }
        }
      }

      // 2. Fetch remote expenses
      final newExpenses = await pullGroupExpenses(groupId);
      if (newExpenses.isNotEmpty) {
        changed = true;
      }

      return changed;
    } catch (_) {
      return false;
    }
  }

  /// Publishes a newly added or updated expense to cloud shared_groups so other members receive it
  Future<void> publishExpense(String groupId, Expense expense) async {
    try {
      final db = await LocalDatabase.instance.database;
      final allExpenses = await db.query(
        'cached_expenses',
        where: 'group_id = ?',
        whereArgs: [groupId],
      );

      final expList = allExpenses.map((r) {
        final splitsList = (jsonDecode(r['splits_json'] as String) as List)
            .map((s) => ExpenseSplit.fromJson(s as Map<String, dynamic>))
            .toList();

        return Expense(
          id: r['id'] as String,
          groupId: r['group_id'] as String,
          paidBy: r['paid_by'] as String,
          amount: (r['amount'] as num).toDouble(),
          currency: r['currency'] as String,
          description: r['description'] as String,
          splitType: SplitType.fromJson(r['split_type'] as String),
          createdAt: DateTime.parse(r['created_at'] as String),
          splits: splitsList,
          isSynced: true,
        );
      }).toList();

      final headers = await _headers();
      final uri = Uri.parse('$_supabaseBaseUrl/rest/v1/shared_groups?id=eq.$groupId');
      final body = jsonEncode({
        'expenses_json': jsonEncode(expList.map((e) => e.toJson()).toList()),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      await _httpClient
          .patch(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 4));
    } catch (_) {}
  }

  /// Synchronizes all user groups and expenses with cloud
  Future<void> syncAllGroups() async {
    try {
      final db = await LocalDatabase.instance.database;
      final groups = await db.query('cached_groups');

      for (final g in groups) {
        final id = g['id'] as String;
        await syncGroup(id);
      }
    } catch (_) {}
  }
}
