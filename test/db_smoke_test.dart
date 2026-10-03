import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mobile/database.dart';
import 'package:mobile/qr_payload.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('recovers half-created db, login and register work', () async {
    final dir = await databaseFactory.getDatabasesPath();
    final path = p.join(dir, 'smartqr.db');
    await databaseFactory.deleteDatabase(path);

    // Recreate the state the old buggy onCreate left behind:
    // tables exist + seed users, queue insert crashed, user_version still 0.
    try {
      await openDatabase(
        path,
        version: 1,
        onCreate: (db, version) async {
          await db.execute(
            "CREATE TABLE users(id INTEGER PRIMARY KEY AUTOINCREMENT, student_id TEXT UNIQUE NOT NULL, full_name TEXT NOT NULL, email TEXT, contact TEXT, password TEXT NOT NULL, role TEXT NOT NULL DEFAULT 'student')",
          );
          await db.execute(
            'CREATE TABLE queue(id INTEGER PRIMARY KEY AUTOINCREMENT, queue_no TEXT NOT NULL, student_id TEXT NOT NULL, student_name TEXT NOT NULL, service TEXT NOT NULL, time TEXT NOT NULL, status TEXT NOT NULL DEFAULT \'WAITING\', purpose TEXT, counter TEXT)',
          );
          await db.insert('users', {
            'student_id': '2025-00123',
            'full_name': 'Juan Dela Cruz',
            'password': 'password123',
            'role': 'student',
          });
          throw StateError('old crash');
        },
      );
      fail('old onCreate should have thrown');
    } catch (_) {
      // expected
    }

    // Login with the seeded demo student.
    final user = await DatabaseHelper.instance.login('2025-00123', 'password123');
    expect(user, isNotNull);
    expect(user!['role'], 'student');
    expect(
      await DatabaseHelper.instance.login('2025-00123', 'wrong'),
      isNull,
    );

    // The interrupted seed still ends up with every demo account.
    expect(await DatabaseHelper.instance.login('STAFF001', 'password123'), isNotNull);
    expect(await DatabaseHelper.instance.login('ADMIN001', 'password123'), isNotNull);

    // Register a new account, then log in with it.
    expect(
      await DatabaseHelper.instance.register(
        studentId: '2025-99999',
        fullName: 'Test Student',
        email: 'test@school.edu',
        contact: '09170000000',
        password: 'secret123',
      ),
      isNull,
    );
    final created = await DatabaseHelper.instance.login('2025-99999', 'secret123');
    expect(created, isNotNull);
    expect(created!['full_name'], 'Test Student');

    // Duplicate student id is rejected.
    expect(
      await DatabaseHelper.instance.register(
        studentId: '2025-99999',
        fullName: 'Dup',
        email: 'd@d.com',
        contact: '0',
        password: 'secret123',
      ),
      isNotNull,
    );

    // Queue starts empty: no static/demo tickets are pre-loaded.
    expect(await DatabaseHelper.instance.getActiveQueue(), isEmpty);
    expect((await DatabaseHelper.instance.getQueueStats())['total'], 0);

    final queueNo = await DatabaseHelper.instance.generateQueueNo();
    expect(RegExp(r'^A\d{3}$').hasMatch(queueNo), isTrue);

    final rowId = await DatabaseHelper.instance.joinQueue(
      studentId: '2025-99999',
      studentName: 'Test Student',
      service: 'Registrar',
      time: '11:00 AM',
      purpose: 'Request Transcript',
    );
    expect(rowId, greaterThan(0));

    // The ticket now shows up as real database data everywhere.
    final last = await DatabaseHelper.instance.getLastTicketForStudent('2025-99999');
    expect(last, isNotNull);
    expect(last!['queue_no'], queueNo);
    expect(last['created_at'], isNotNull);

    final active = await DatabaseHelper.instance.getActiveQueue();
    expect(active, hasLength(1));
    expect(active.first.containsKey('queue_no'), isTrue);

    final stats = await DatabaseHelper.instance.getQueueStats();
    expect(stats['total'], 1);
    expect(stats['waiting'], 1);
  });

  test('services and counters are editable reference data', () async {
    final services = await DatabaseHelper.instance.getServices();
    expect(services.map((r) => r['name']), contains('Registrar'));
    expect(kServiceList.every((name) =>
        services.any((r) => r['name'] == name)), isTrue);

    expect(await DatabaseHelper.instance.addService('Registrar'), isNotNull);
    expect(await DatabaseHelper.instance.addService('   '), isNotNull);
    expect(await DatabaseHelper.instance.addService('Scholarship Office'), isNull);
    final withNew = await DatabaseHelper.instance.getServices();
    expect(withNew.map((r) => r['name']), contains('Scholarship Office'));

    final added =
        withNew.firstWhere((r) => r['name'] == 'Scholarship Office');
    await DatabaseHelper.instance.deleteService(added['id'] as int);
    final afterDelete = await DatabaseHelper.instance.getServices();
    expect(afterDelete.map((r) => r['name']), isNot(contains('Scholarship Office')));

    final counters = await DatabaseHelper.instance.getCounters();
    expect(counters.map((r) => r['name']), contains('Counter 1'));
    expect(await DatabaseHelper.instance.addCounter('Counter 1'), isNotNull);
    expect(await DatabaseHelper.instance.addCounter('Counter 4'), isNull);
    final withCounter = await DatabaseHelper.instance.getCounters();
    expect(withCounter.map((r) => r['name']), contains('Counter 4'));
    await DatabaseHelper.instance
        .deleteCounter(withCounter.firstWhere((r) => r['name'] == 'Counter 4')['id'] as int);
  });

  test('staff counter assignment and daily reports read real rows', () async {
    final staff = await DatabaseHelper.instance.getStaffUsers();
    expect(staff, isNotEmpty);
    expect(staff.every((s) => s['counter'] != null), isTrue);

    await DatabaseHelper.instance.assignCounter(staff.first['id'] as int, 'Counter 2');
    final refreshed = await DatabaseHelper.instance.getStaffUsers();
    expect(
      refreshed.firstWhere((s) => s['id'] == staff.first['id'])['counter'],
      'Counter 2',
    );

    final trend = await DatabaseHelper.instance.getHourlyTrend();
    expect(trend, hasLength(6));
    final daily = await DatabaseHelper.instance.getDailyCounts(7);
    expect(daily, hasLength(7));
    expect(daily.last['label'], isNotEmpty);

    // The ticket joined in the previous test was created just now.
    final today = await DatabaseHelper.instance.getTodayStats();
    expect(today['waiting'], 1);
    expect(
      today['total'],
      (today['waiting'] ?? 0) +
          (today['serving'] ?? 0) +
          (today['done'] ?? 0) +
          (today['cancelled'] ?? 0),
    );

    final history = await DatabaseHelper.instance.getQueueHistory();
    expect(history, isNotEmpty);
    final waitingOnly =
        await DatabaseHelper.instance.getQueueHistory(status: 'CANCELLED');
    expect(waitingOnly, isEmpty);
  });
}
