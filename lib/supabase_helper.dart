import 'package:supabase_flutter/supabase_flutter.dart';

import 'database.dart';

/// Online database backed by Supabase (Postgres + Auth).
///
/// Every screen still talks to [DatabaseHelper.instance]; this is simply the
/// implementation that runs when the app is online, so students, staff and
/// admin all read and write the same rows from any device.
class SupabaseHelper extends DatabaseHelper {
  static const String supabaseUrl = 'https://udguqspqinhosklbecju.supabase.co';

  /// The publishable key is safe to ship inside the app: Row Level Security
  /// is what actually protects the data. Never put a secret key here.
  static const String supabasePublishableKey =
      'sb_publishable_ld6gkMKx1lxleC2C62utUA_SYZXXtFQ';

  SupabaseClient get _db => Supabase.instance.client;

  /// Supabase Auth needs an email address, but the login screen asks for a
  /// Student ID. Deriving the address means the login form is unchanged and
  /// no lookup (which would leak emails to signed-out callers) is needed.
  static String authEmailFor(String studentId) =>
      '${studentId.trim()}@smartqr.app';

  // ---------- Users ----------

  @override
  Future<Map<String, dynamic>?> login(String studentId, String password) async {
    try {
      final res = await _db.auth.signInWithPassword(
        email: authEmailFor(studentId),
        password: password,
      );
      final uid = res.user?.id;
      if (uid == null) return null;
      return await _profileFor(uid);
    } on AuthException {
      // Wrong password, unknown account or unconfirmed email: the login screen
      // shows one generic message for all of them, exactly as before.
      return null;
    }
  }

  Future<Map<String, dynamic>?> _profileFor(String uid) async {
    final rows =
        await _db.from('users').select().eq('auth_uid', uid).limit(1);
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  @override
  Future<String?> register({
    required String studentId,
    required String fullName,
    required String email,
    required String contact,
    required String password,
  }) async {
    final trimmed = studentId.trim();
    if (trimmed.isEmpty) return 'Student ID cannot be empty.';

    // Signed-out callers see no rows through RLS, so a real duplicate surfaces
    // below as an auth error rather than from this probe. It is still worth
    // catching while a session exists (e.g. registering over a stale session).
    final existing =
        await _db.from('users').select('id').eq('student_id', trimmed).limit(1);
    if (existing.isNotEmpty) return 'Student ID already registered.';

    try {
      final cred = await _db.auth.signUp(
        email: authEmailFor(trimmed),
        password: password,
        data: {'student_id': trimmed, 'full_name': fullName},
      );

      // Email confirmation must be off for this to hold; with it on there is
      // no session yet and the profile cannot be written under RLS.
      final uid = cred.user?.id;
      if (uid == null || cred.session == null) {
        return 'Account could not be activated. Please contact the registrar.';
      }

      await _db.from('users').insert({
        'auth_uid': uid,
        'student_id': trimmed,
        'full_name': fullName,
        'email': email,
        'contact': contact,
        'role': 'student',
      });

      // Registration used to leave you on the sign-in screen; keep that by
      // dropping the session the sign-up just created.
      await _db.auth.signOut();
      return null;
    } on AuthException catch (e) {
      if (e.message.contains('already')) return 'Student ID already registered.';
      return e.message;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getStaffUsers() async {
    final rows = await _db
        .from('users')
        .select()
        .or('role.eq.staff,role.eq.admin')
        .order('id', ascending: true);
    return rows;
  }

  @override
  Future<void> assignCounter(int userId, String? counter) async {
    await _db.from('users').update({'counter': counter}).eq('id', userId);
  }

  // ---------- Account management ----------

  @override
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final rows = await _db.from('users').select().order('id', ascending: true);
    return rows;
  }

  /// Account creation is done by a Postgres function rather than from here:
  /// the publishable key deliberately cannot write to `auth.users`, so the
  /// function checks `app_role() = 'admin'` before creating anything.
  @override
  Future<String?> adminCreateUser({
    required String studentId,
    required String fullName,
    required String email,
    required String contact,
    required String password,
    required String role,
    String? counter,
  }) async {
    final trimmed = studentId.trim();
    if (trimmed.isEmpty) return 'Student ID cannot be empty.';
    if (!DatabaseHelper.roles.contains(role)) return 'Invalid role.';
    if (password.length < 6) return 'Password must be at least 6 characters.';
    if (email.trim().isEmpty) return 'Email address cannot be empty.';
    return _call('app_create_user', {
      'p_student_id': trimmed,
      'p_full_name': fullName,
      'p_email': email,
      'p_contact': contact,
      'p_password': password,
      'p_role': role,
      'p_counter': counter,
    });
  }

  @override
  Future<String?> adminUpdateUser({
    required int userId,
    required String fullName,
    required String email,
    required String contact,
    required String role,
    String? counter,
    String? newPassword,
  }) async {
    if (!DatabaseHelper.roles.contains(role)) return 'Invalid role.';
    if (newPassword != null && newPassword.isNotEmpty && newPassword.length < 6) {
      return 'Password must be at least 6 characters.';
    }
    return _call('app_update_user', {
      'p_user_id': userId,
      'p_full_name': fullName,
      'p_email': email,
      'p_contact': contact,
      'p_role': role,
      'p_counter': counter,
      'p_new_password':
          (newPassword == null || newPassword.isEmpty) ? null : newPassword,
    });
  }

  @override
  Future<String?> adminDeleteUser(int userId) =>
      _call('app_delete_user', {'p_user_id': userId});

  /// Runs an admin-gated rpc. Returns null on success or the database's own
  /// message (already written for a person to read) on failure.
  Future<String?> _call(String fn, Map<String, dynamic> params) async {
    try {
      await _db.rpc(fn, params: params);
      return null;
    } on PostgrestException catch (e) {
      return e.message;
    } on AuthException catch (e) {
      return e.message;
    }
  }

  // ---------- Services ----------

  @override
  Future<List<Map<String, dynamic>>> getServices() async {
    final rows = await _db.from('services').select().order('name');
    return rows;
  }

  @override
  Future<String?> addService(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Service name cannot be empty.';
    final existing =
        await _db.from('services').select('id').eq('name', trimmed).limit(1);
    if (existing.isNotEmpty) return 'That service already exists.';
    await _db.from('services').insert({'name': trimmed});
    return null;
  }

  @override
  Future<void> deleteService(int id) async {
    await _db.from('services').delete().eq('id', id);
  }

  // ---------- Counters ----------

  @override
  Future<List<Map<String, dynamic>>> getCounters() async {
    final rows = await _db.from('counters').select().order('name');
    return rows;
  }

  @override
  Future<String?> addCounter(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Counter name cannot be empty.';
    final existing =
        await _db.from('counters').select('id').eq('name', trimmed).limit(1);
    if (existing.isNotEmpty) return 'That counter already exists.';
    await _db.from('counters').insert({'name': trimmed});
    return null;
  }

  @override
  Future<void> deleteCounter(int id) async {
    await _db.from('counters').delete().eq('id', id);
  }

  // ---------- Queue ----------

  /// Backed by a Postgres sequence, so two devices requesting a ticket at the
  /// same instant get different numbers. SQLite's read-then-write version
  /// could not promise that.
  @override
  Future<String> generateQueueNo() async {
    final dynamic no = await _db.rpc('next_queue_no');
    return no as String;
  }

  @override
  Future<int> joinQueue({
    required String studentId,
    required String studentName,
    required String service,
    required String time,
    required String purpose,
    String? counter,
  }) async {
    final queueNo = await generateQueueNo();
    final row = await _db.from('queue').insert({
      'queue_no': queueNo,
      'student_id': studentId,
      'student_name': studentName,
      'service': service,
      'time': time,
      'status': 'WAITING',
      'purpose': purpose,
      'counter': counter,
      'created_at': DateTime.now().toIso8601String(),
    }).select('id').single();
    return row['id'] as int;
  }

  @override
  Future<Map<String, dynamic>?> getLastTicketForStudent(String studentId) async {
    final rows = await _db
        .from('queue')
        .select()
        .eq('student_id', studentId)
        .inFilter('status', ['WAITING', 'SERVING'])
        .order('id')
        .limit(1);
    return rows.isEmpty ? null : rows.first;
  }

  @override
  Future<List<Map<String, dynamic>>> getActiveQueue() async {
    final rows = await _db
        .from('queue')
        .select()
        .inFilter('status', ['WAITING', 'SERVING'])
        .order('id', ascending: true);
    return rows;
  }

  @override
  Future<List<Map<String, dynamic>>> getQueueForStudent(String studentId) async {
    final rows = await _db
        .from('queue')
        .select()
        .eq('student_id', studentId)
        .order('id');
    return rows;
  }

  @override
  Future<List<Map<String, dynamic>>> getNowServing() async {
    final rows = await _db
        .from('queue')
        .select()
        .eq('status', 'SERVING')
        .order('id', ascending: true);
    return rows;
  }

  @override
  Future<List<Map<String, dynamic>>> getQueueHistory({String? status}) async {
    var query = _db.from('queue').select();
    if (status != null) query = query.eq('status', status);
    final rows = await query.order('id');
    return rows;
  }

  @override
  Future<void> updateStatus(int id, String status, {String? counter}) async {
    final values = <String, dynamic>{'status': status};
    if (counter != null) values['counter'] = counter;
    await _db.from('queue').update(values).eq('id', id);
  }

  @override
  Future<int> clearCompletedHistory() async {
    final removed = await _db
        .from('queue')
        .delete()
        .inFilter('status', ['DONE', 'CANCELLED'])
        .select('id');
    return removed.length;
  }

  @override
  Future<void> callNext(String counter) async {
    // Prefer a student waiting for this exact counter (chosen by scanning the
    // counter's QR code), otherwise take the next one in line.
    var next = await _db
        .from('queue')
        .select()
        .eq('status', 'WAITING')
        .eq('counter', counter)
        .order('id', ascending: true)
        .limit(1);
    if (next.isEmpty) {
      next = await _db
          .from('queue')
          .select()
          .eq('status', 'WAITING')
          .order('id', ascending: true)
          .limit(1);
    }
    if (next.isEmpty) return;
    await updateStatus(next.first['id'] as int, 'SERVING', counter: counter);
  }

  @override
  Future<void> completeCurrent(String counter) async {
    await _db
        .from('queue')
        .update({'status': 'DONE'})
        .eq('status', 'SERVING')
        .eq('counter', counter);
  }

  @override
  Future<Map<String, int>> getQueueStats() async {
    final rows = await _db.from('queue').select('status');
    var waiting = 0, serving = 0, done = 0, cancelled = 0;
    for (final row in rows) {
      switch (row['status'] as String? ?? '') {
        case 'WAITING':
          waiting++;
        case 'SERVING':
          serving++;
        case 'DONE':
          done++;
        case 'CANCELLED':
          cancelled++;
      }
    }
    return {
      'waiting': waiting,
      'serving': serving,
      'done': done,
      'cancelled': cancelled,
      'total': waiting + serving + done + cancelled,
    };
  }

  @override
  Future<Map<String, int>> getServiceBreakdown() async {
    final rows = await _db.from('queue').select('service');
    final counts = <String, int>{};
    for (final row in rows) {
      final service = row['service'] as String? ?? '';
      counts[service] = (counts[service] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return {for (final e in sorted) e.key: e.value};
  }

  @override
  Future<Map<String, int>> getTodayStats() async {
    final rows = await _db
        .from('queue')
        .select('status')
        .like('created_at', '${todayPrefix()}%');

    const keys = ['WAITING', 'SERVING', 'DONE', 'CANCELLED'];
    final stats = {for (final key in keys) key.toLowerCase(): 0};
    for (final row in rows) {
      final status = row['status'] as String? ?? '';
      final index = keys.indexOf(status);
      if (index != -1) stats[keys[index].toLowerCase()] = stats[keys[index].toLowerCase()]! + 1;
    }
    return {
      ...stats,
      'total': stats.values.fold<int>(0, (a, b) => a + b),
    };
  }

  @override
  Future<List<int>> getHourlyTrend({
    List<int> starts = const [7, 9, 11, 13, 15, 17],
    int span = 2,
  }) async {
    final rows = await _db
        .from('queue')
        .select('created_at')
        .like('created_at', '${todayPrefix()}%');

    final counts = List<int>.filled(starts.length, 0);
    for (final row in rows) {
      final createdAt = DateTime.tryParse(row['created_at']?.toString() ?? '');
      if (createdAt == null) continue;
      for (var i = 0; i < starts.length; i++) {
        if (createdAt.hour >= starts[i] && createdAt.hour < starts[i] + span) {
          counts[i]++;
          break;
        }
      }
    }
    return counts;
  }

  @override
  Future<List<Map<String, dynamic>>> getDailyCounts(int days) async {
    final today = DateTime.now();
    final daysBack = <DateTime>[];
    for (var i = days - 1; i >= 0; i--) {
      daysBack.add(DateTime(today.year, today.month, today.day - i));
    }

    final rows = await _db
        .from('queue')
        .select('created_at')
        .gte('created_at', daysBack.first.toIso8601String());

    final counts = List<int>.filled(days, 0);
    for (final row in rows) {
      final createdAt = DateTime.tryParse(row['created_at']?.toString() ?? '');
      if (createdAt == null) continue;
      final day = DateTime(createdAt.year, createdAt.month, createdAt.day);
      final index = daysBack.indexWhere((d) => d == day);
      if (index != -1) counts[index]++;
    }

    const monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return [
      for (var i = 0; i < days; i++)
        {
          'label': '${monthNames[daysBack[i].month - 1]} ${daysBack[i].day}',
          'count': counts[i],
        },
    ];
  }
}
