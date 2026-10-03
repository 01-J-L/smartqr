import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mobile/database.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('v1 database upgrades to v2 without keeping demo tickets', () async {
    final base = await databaseFactory.getDatabasesPath();
    await databaseFactory.setDatabasesPath(p.join(base, 'migration'));
    final path = p.join(await databaseFactory.getDatabasesPath(), 'smartqr.db');
    await databaseFactory.deleteDatabase(path);

    // Rebuild a version-1 database exactly as the old app shipped it:
    // no services/counters tables, no users.counter, no queue.created_at,
    // plus the demo queue rows that used to be seeded.
    final old = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
          "CREATE TABLE users(id INTEGER PRIMARY KEY AUTOINCREMENT, student_id TEXT UNIQUE NOT NULL, full_name TEXT NOT NULL, email TEXT, contact TEXT, password TEXT NOT NULL, role TEXT NOT NULL DEFAULT 'student')",
        );
        await db.execute(
          "CREATE TABLE queue(id INTEGER PRIMARY KEY AUTOINCREMENT, queue_no TEXT NOT NULL, student_id TEXT NOT NULL, student_name TEXT NOT NULL, service TEXT NOT NULL, time TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'WAITING', purpose TEXT, counter TEXT)",
        );
        await db.insert('users', {
          'student_id': '2025-00123',
          'full_name': 'Juan Dela Cruz',
          'password': 'password123',
          'role': 'student',
        });
        await db.insert('users', {
          'student_id': 'STAFF001',
          'full_name': 'Juan Staff',
          'password': 'password123',
          'role': 'staff',
        });
        // A real ticket created before the upgrade...
        await db.insert('queue', {
          'queue_no': 'A030',
          'student_id': '2025-00123',
          'student_name': 'Juan Dela Cruz',
          'service': 'Registrar',
          'time': '9:15 AM',
          'status': 'DONE',
          'purpose': 'Request Transcript',
        });
        // ...and the demo rows that must not survive.
        await db.insert('queue', {
          'queue_no': 'A025',
          'student_id': '2025-00123',
          'student_name': 'Juan Dela Cruz',
          'service': 'Registrar',
          'time': '10:30 AM',
          'status': 'WAITING',
        });
        await db.insert('queue', {
          'queue_no': 'A026',
          'student_id': '2025-00127',
          'student_name': 'Pedro Cruz',
          'service': "Dean's Office",
          'time': '10:35 AM',
          'status': 'WAITING',
        });
      },
    );
    expect(await old.getVersion(), 1);
    await old.close();

    // DatabaseHelper opens the same file at version 2, so onUpgrade runs.
    final staff = await DatabaseHelper.instance.login('STAFF001', 'password123');
    expect(staff, isNotNull);
    expect(staff!['counter'], isNotNull,
        reason: 'existing staff must be given an assigned counter');

    final active = await DatabaseHelper.instance.getActiveQueue();
    expect(active, isEmpty, reason: 'seeded demo tickets are removed');

    final history = await DatabaseHelper.instance.getQueueHistory();
    expect(history, hasLength(1), reason: 'real tickets are preserved');
    final kept = history.first;
    expect(kept['queue_no'], 'A030');
    expect(kept['created_at'], isNotNull,
        reason: 'created_at is backfilled from the stored time label');
    final createdAt = DateTime.parse(kept['created_at'] as String);
    expect(createdAt.hour, 9);
    expect(createdAt.minute, 15);

    final services = await DatabaseHelper.instance.getServices();
    expect(services, isNotEmpty);
    final counters = await DatabaseHelper.instance.getCounters();
    expect(counters.map((r) => r['name']), contains('Counter 1'));

    await databaseFactory.deleteDatabase(path);
  });
}
