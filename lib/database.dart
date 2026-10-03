import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'qr_payload.dart';

/// Storage backend every screen talks to.
///
/// Screens only ever call [instance], so swapping that field swaps the whole
/// database. It defaults to [SqliteDatabaseHelper] (what the tests configure
/// around); `main()` replaces it with `SupabaseHelper` so the running app
/// shares one online database across devices.
abstract class DatabaseHelper {
  /// Swappable backend. Defaults to on-device SQLite, so tests and offline
  /// runs need no configuration at all.
  static DatabaseHelper instance = SqliteDatabaseHelper();

  static const int schemaVersion = 2;

  /// The only roles an account may hold.
  static const List<String> roles = ['student', 'staff', 'admin'];

  // ---------- Users ----------

  Future<Map<String, dynamic>?> login(String studentId, String password);

  Future<String?> register({
    required String studentId,
    required String fullName,
    required String email,
    required String contact,
    required String password,
  });

  Future<List<Map<String, dynamic>>> getStaffUsers();

  Future<void> assignCounter(int userId, String? counter);

  // ---------- Account management (admin "Manage Users" panel) ----------

  /// Every account, ordered by id.
  Future<List<Map<String, dynamic>>> getAllUsers();

  /// Creates an account holding [role]. Returns null on success, otherwise a
  /// message safe to show the admin.
  Future<String?> adminCreateUser({
    required String studentId,
    required String fullName,
    required String email,
    required String contact,
    required String password,
    required String role,
    String? counter,
  });

  /// Updates an account's profile and, when [newPassword] is non-empty, its
  /// password. Returns null on success, otherwise a message for the admin.
  Future<String?> adminUpdateUser({
    required int userId,
    required String fullName,
    required String email,
    required String contact,
    required String role,
    String? counter,
    String? newPassword,
  });

  /// Removes an account entirely, including its sign-in credentials.
  /// Returns null on success, otherwise a message for the admin.
  Future<String?> adminDeleteUser(int userId);

  // ---------- Services ----------

  Future<List<Map<String, dynamic>>> getServices();

  Future<String?> addService(String name);

  Future<void> deleteService(int id);

  // ---------- Counters ----------

  Future<List<Map<String, dynamic>>> getCounters();

  Future<String?> addCounter(String name);

  Future<void> deleteCounter(int id);

  // ---------- Queue ----------

  /// Must be atomic: two devices requesting a ticket at the same moment may
  /// never receive the same number.
  Future<String> generateQueueNo();

  Future<int> joinQueue({
    required String studentId,
    required String studentName,
    required String service,
    required String time,
    required String purpose,
    String? counter,
  });

  Future<Map<String, dynamic>?> getLastTicketForStudent(String studentId);

  Future<List<Map<String, dynamic>>> getActiveQueue();

  Future<List<Map<String, dynamic>>> getQueueForStudent(String studentId);

  Future<List<Map<String, dynamic>>> getNowServing();

  Future<List<Map<String, dynamic>>> getQueueHistory({String? status});

  Future<void> updateStatus(int id, String status, {String? counter});

  Future<int> clearCompletedHistory();

  Future<void> callNext(String counter);

  Future<void> completeCurrent(String counter);

  Future<Map<String, int>> getQueueStats();

  Future<Map<String, int>> getServiceBreakdown();

  /// Stats for tickets created today only.
  Future<Map<String, int>> getTodayStats();

  /// Requests created today, bucketed into two-hour windows starting at 7 AM.
  Future<List<int>> getHourlyTrend({
    List<int> starts = const [7, 9, 11, 13, 15, 17],
    int span = 2,
  });

  /// Requests created on each of the last [days] days, oldest first.
  Future<List<Map<String, dynamic>>> getDailyCounts(int days);

  // ---------- Shared behaviour every backend inherits ----------

  Future<void> cancelTicket(int id) => updateStatus(id, 'CANCELLED');

  /// Hands the counter to [id]: whoever is currently served there is finished
  /// first, then the requested ticket starts.
  Future<void> serveTicket(int id, String counter) async {
    await completeCurrent(counter);
    await updateStatus(id, 'SERVING', counter: counter);
  }

  /// `2026-10-02` for right now, used to scope `created_at` to today.
  String todayPrefix([DateTime? now]) {
    final d = now ?? DateTime.now();
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }
}

/// On-device SQLite database. This is the implementation the tests run
/// against, so it keeps every behaviour of the original single-class helper.
class SqliteDatabaseHelper extends DatabaseHelper {
  static Database? _database;

  /// Demo accounts only. Queue rows, services and counters are real records
  /// created by the app itself, never pre-seeded.
  static const List<Map<String, String>> _seedUsers = [
    {
      'student_id': '2025-00123',
      'full_name': 'Juan Dela Cruz',
      'email': 'juan.delacruz@school.edu',
      'contact': '09171234567',
      'password': 'password123',
      'role': 'student',
    },
    {
      'student_id': 'STAFF001',
      'full_name': 'Juan Staff',
      'email': 'staff@school.edu',
      'contact': '09171234568',
      'password': 'password123',
      'role': 'staff',
    },
    {
      'student_id': 'ADMIN001',
      'full_name': 'Admin User',
      'email': 'admin@school.edu',
      'contact': '09171234569',
      'password': 'password123',
      'role': 'admin',
    },
  ];

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'smartqr.db');
    return openDatabase(
      path,
      version: DatabaseHelper.schemaVersion,
      onCreate: _createDb,
      onUpgrade: _upgradeDb,
    );
  }

  Future<void> _createDb(Database db, int version) async {
    await _createTables(db);
    await _insertSeedUsers(db);
    await _seedReferenceData(db);
    await _assignMissingCounters(db);
  }

  Future<void> _upgradeDb(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await _createTables(db);

      if (!await _hasColumn(db, 'users', 'counter')) {
        await db.execute('ALTER TABLE users ADD COLUMN counter TEXT');
      }
      if (!await _hasColumn(db, 'queue', 'created_at')) {
        await db.execute('ALTER TABLE queue ADD COLUMN created_at TEXT');
      }

      // The old schema pre-loaded fake queue tickets; drop them so only real
      // requests remain.
      await db.delete(
        'queue',
        where: 'queue_no IN (?,?,?,?,?,?)',
        whereArgs: ['A022', 'A023', 'A024', 'A025', 'A026', 'A027'],
      );
      await _backfillCreatedAt(db);

      await _insertSeedUsers(db);
      await _seedReferenceData(db);
      await _assignMissingCounters(db);
    }
  }

  /// Every staff/admin account works at a counter; give the ones created
  /// before counters were tracked the first available one.
  Future<void> _assignMissingCounters(Database db) async {
    await db.rawUpdate(
      "UPDATE users SET counter = ? WHERE counter IS NULL AND role IN ('staff', 'admin')",
      [kCounterList.first],
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id TEXT UNIQUE NOT NULL,
        full_name TEXT NOT NULL,
        email TEXT,
        contact TEXT,
        password TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'student',
        counter TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS queue(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        queue_no TEXT NOT NULL,
        student_id TEXT NOT NULL,
        student_name TEXT NOT NULL,
        service TEXT NOT NULL,
        time TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'WAITING',
        purpose TEXT,
        counter TEXT,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS services(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS counters(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT UNIQUE NOT NULL
      )
    ''');
  }

  Future<void> _insertSeedUsers(Database db) async {
    for (final user in _seedUsers) {
      await db.insert('users', user, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  /// Reference data (offered services + service counters). Idempotent, so an
  /// interrupted first run simply finishes on the next launch.
  Future<void> _seedReferenceData(Database db) async {
    for (final name in kServiceList) {
      await db.insert('services', {'name': name},
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    for (final name in kCounterList) {
      await db.insert('counters', {'name': name},
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _backfillCreatedAt(Database db) async {
    final rows = await db.query('queue', columns: ['id', 'time', 'created_at']);
    final today = DateTime.now();
    for (final row in rows) {
      if (row['created_at'] != null) continue;
      final parsed = _parseTimeOnDate(row['time'] as String? ?? '', today);
      await db.update(
        'queue',
        {'created_at': parsed.toIso8601String()},
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
  }

  /// Turns a stored `10:20 AM` label into a DateTime on [day].
  DateTime _parseTimeOnDate(String time, DateTime day) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$', caseSensitive: false)
        .firstMatch(time.trim());
    if (match == null) return day;
    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final period = match.group(3)!.toUpperCase();
    if (period == 'PM' && hour != 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;
    return DateTime(day.year, day.month, day.day, hour, minute);
  }

  Future<bool> _hasColumn(Database db, String table, String column) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    return info.any((row) => row['name'] == column);
  }

  // ---------- Users ----------

  @override
  Future<Map<String, dynamic>?> login(String studentId, String password) async {
    final db = await database;
    final rows = await db.query(
      'users',
      where: 'student_id = ? AND password = ?',
      whereArgs: [studentId, password],
      limit: 1,
    );
    // A plain copy: sqflite rows are read-only, but Session keeps the signed-in
    // user around and screens update fields such as `counter`.
    return rows.isEmpty ? null : Map<String, dynamic>.from(rows.first);
  }

  @override
  Future<String?> register({
    required String studentId,
    required String fullName,
    required String email,
    required String contact,
    required String password,
  }) async {
    final db = await database;
    final existing = await db.query(
      'users',
      where: 'student_id = ?',
      whereArgs: [studentId],
    );
    if (existing.isNotEmpty) return 'Student ID already registered.';

    await db.insert('users', {
      'student_id': studentId,
      'full_name': fullName,
      'email': email,
      'contact': contact,
      'password': password,
      'role': 'student',
    });
    return null;
  }

  @override
  Future<List<Map<String, dynamic>>> getStaffUsers() async {
    final db = await database;
    return db.query(
      'users',
      where: "role IN ('staff', 'admin')",
      orderBy: 'id ASC',
    );
  }

  @override
  Future<void> assignCounter(int userId, String? counter) async {
    final db = await database;
    await db.update(
      'users',
      {'counter': counter},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final db = await database;
    return db.query('users', orderBy: 'id ASC');
  }

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

    final db = await database;
    final existing =
        await db.query('users', where: 'student_id = ?', whereArgs: [trimmed]);
    if (existing.isNotEmpty) return 'Student ID already registered.';

    await db.insert('users', {
      'student_id': trimmed,
      'full_name': fullName,
      'email': email,
      'contact': contact,
      'password': password,
      'role': role,
      'counter': counter,
    });
    return null;
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

    final db = await database;
    final values = <String, Object?>{
      'full_name': fullName,
      'email': email,
      'contact': contact,
      'role': role,
      'counter': counter,
    };
    if (newPassword != null && newPassword.isNotEmpty) {
      values['password'] = newPassword;
    }
    await db.update('users', values, where: 'id = ?', whereArgs: [userId]);
    return null;
  }

  @override
  Future<String?> adminDeleteUser(int userId) async {
    final db = await database;
    await db.delete('users', where: 'id = ?', whereArgs: [userId]);
    return null;
  }

  // ---------- Services ----------

  @override
  Future<List<Map<String, dynamic>>> getServices() async {
    final db = await database;
    return db.query('services', orderBy: 'name ASC');
  }

  @override
  Future<String?> addService(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Service name cannot be empty.';
    final db = await database;
    final existing =
        await db.query('services', where: 'name = ?', whereArgs: [trimmed]);
    if (existing.isNotEmpty) return 'That service already exists.';
    await db.insert('services', {'name': trimmed});
    return null;
  }

  @override
  Future<void> deleteService(int id) async {
    final db = await database;
    await db.delete('services', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- Counters ----------

  @override
  Future<List<Map<String, dynamic>>> getCounters() async {
    final db = await database;
    return db.query('counters', orderBy: 'name ASC');
  }

  @override
  Future<String?> addCounter(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Counter name cannot be empty.';
    final db = await database;
    final existing =
        await db.query('counters', where: 'name = ?', whereArgs: [trimmed]);
    if (existing.isNotEmpty) return 'That counter already exists.';
    await db.insert('counters', {'name': trimmed});
    return null;
  }

  @override
  Future<void> deleteCounter(int id) async {
    final db = await database;
    await db.delete('counters', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- Queue ----------

  @override
  Future<String> generateQueueNo() async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT queue_no FROM queue ORDER BY id DESC LIMIT 1",
    );
    if (result.isEmpty) return 'A001';
    final last = result.first['queue_no'] as String;
    final num = int.tryParse(last.substring(1)) ?? 0;
    return 'A${(num + 1).toString().padLeft(3, '0')}';
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
    final db = await database;
    final queueNo = await generateQueueNo();
    return db.insert('queue', {
      'queue_no': queueNo,
      'student_id': studentId,
      'student_name': studentName,
      'service': service,
      'time': time,
      'status': 'WAITING',
      'purpose': purpose,
      'counter': counter,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<Map<String, dynamic>?> getLastTicketForStudent(String studentId) async {
    final db = await database;
    final rows = await db.query(
      'queue',
      where: "student_id = ? AND status IN ('WAITING', 'SERVING')",
      whereArgs: [studentId],
      orderBy: 'id DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  @override
  Future<List<Map<String, dynamic>>> getActiveQueue() async {
    final db = await database;
    return db.query(
      'queue',
      where: "status IN ('WAITING', 'SERVING')",
      orderBy: 'id ASC',
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getQueueForStudent(String studentId) async {
    final db = await database;
    return db.query(
      'queue',
      where: 'student_id = ?',
      whereArgs: [studentId],
      orderBy: 'id DESC',
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getNowServing() async {
    final db = await database;
    return db.query(
      'queue',
      where: "status = 'SERVING'",
      orderBy: 'id ASC',
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getQueueHistory({String? status}) async {
    final db = await database;
    return db.query(
      'queue',
      where: status == null ? null : 'status = ?',
      whereArgs: status == null ? null : [status],
      orderBy: 'id DESC',
    );
  }

  @override
  Future<void> updateStatus(int id, String status, {String? counter}) async {
    final db = await database;
    final values = <String, Object?>{'status': status};
    if (counter != null) values['counter'] = counter;
    await db.update(
      'queue',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<int> clearCompletedHistory() async {
    final db = await database;
    return db.delete(
      'queue',
      where: "status IN ('DONE', 'CANCELLED')",
    );
  }

  @override
  Future<void> callNext(String counter) async {
    final db = await database;
    // Prefer a student waiting for this exact counter (chosen by scanning
    // the counter's QR code), otherwise take the next one in line.
    var next = await db.query(
      'queue',
      where: "status = 'WAITING' AND counter = ?",
      whereArgs: [counter],
      orderBy: 'id ASC',
      limit: 1,
    );
    if (next.isEmpty) {
      next = await db.query(
        'queue',
        where: "status = 'WAITING'",
        orderBy: 'id ASC',
        limit: 1,
      );
    }
    if (next.isEmpty) return;
    await db.update(
      'queue',
      {'status': 'SERVING', 'counter': counter},
      where: 'id = ?',
      whereArgs: [next.first['id']],
    );
  }

  @override
  Future<void> completeCurrent(String counter) async {
    final db = await database;
    await db.update(
      'queue',
      {'status': 'DONE'},
      where: "status = 'SERVING' AND counter = ?",
      whereArgs: [counter],
    );
  }

  @override
  Future<Map<String, int>> getQueueStats() async {
    final db = await database;
    final waiting = Sqflite.firstIntValue(
          await db.rawQuery("SELECT COUNT(*) FROM queue WHERE status = 'WAITING'"),
        ) ??
        0;
    final serving = Sqflite.firstIntValue(
          await db.rawQuery("SELECT COUNT(*) FROM queue WHERE status = 'SERVING'"),
        ) ??
        0;
    final done = Sqflite.firstIntValue(
          await db.rawQuery("SELECT COUNT(*) FROM queue WHERE status = 'DONE'"),
        ) ??
        0;
    final cancelled = Sqflite.firstIntValue(
          await db.rawQuery("SELECT COUNT(*) FROM queue WHERE status = 'CANCELLED'"),
        ) ??
        0;
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
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT service, COUNT(*) as count FROM queue GROUP BY service ORDER BY count DESC',
    );
    final result = <String, int>{};
    for (final row in rows) {
      result[row['service'] as String] = (row['count'] as int?) ?? 0;
    }
    return result;
  }

  /// Stats for tickets created today only.
  @override
  Future<Map<String, int>> getTodayStats() async {
    final db = await database;
    final rows = await db.rawQuery(
      "SELECT status, COUNT(*) AS count FROM queue WHERE created_at LIKE ? GROUP BY status",
      ['${todayPrefix()}%'],
    );
    const keys = ['WAITING', 'SERVING', 'DONE', 'CANCELLED'];
    final stats = {for (final key in keys) key.toLowerCase(): 0};
    for (final row in rows) {
      final status = row['status'] as String? ?? '';
      final index = keys.indexOf(status);
      if (index != -1) stats[keys[index].toLowerCase()] = row['count'] as int? ?? 0;
    }
    return {
      ...stats,
      'total': stats.values.fold<int>(0, (a, b) => a + b),
    };
  }

  /// Requests created today, bucketed into two-hour windows starting at 7 AM.
  @override
  Future<List<int>> getHourlyTrend({
    List<int> starts = const [7, 9, 11, 13, 15, 17],
    int span = 2,
  }) async {
    final db = await database;
    final prefix = todayPrefix();
    final rows = await db.query(
      'queue',
      columns: ['created_at'],
      where: 'created_at LIKE ?',
      whereArgs: ['$prefix%'],
    );

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

  /// Requests created on each of the last [days] days, oldest first.
  @override
  Future<List<Map<String, dynamic>>> getDailyCounts(int days) async {
    final db = await database;
    final rows = await db.query('queue', columns: ['created_at']);

    final today = DateTime.now();
    final daysBack = <DateTime>[];
    for (var i = days - 1; i >= 0; i--) {
      daysBack.add(DateTime(today.year, today.month, today.day - i));
    }
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

class Session {
  static Map<String, dynamic>? user;

  static String get studentId => (user?['student_id'] as String?) ?? '';
  static String get fullName => (user?['full_name'] as String?) ?? '';
  static String get role => (user?['role'] as String?) ?? 'student';

  /// Counter the signed-in staff member works at.
  static String get counter =>
      (user?['counter'] as String?) ?? kCounterList.first;

  static void clear() => user = null;
}
