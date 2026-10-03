import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mobile/database.dart';
import 'package:mobile/qr_payload.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('staff QR payload round-trips and rejects junk', () {
    final raw = encodeQueueQr(counter: 'Counter 3', service: 'Clinic');
    expect(raw, 'SMARTQR|Counter 3|Clinic');

    final payload = decodeQueueQr(raw);
    expect(payload, isNotNull);
    expect(payload!.counter, 'Counter 3');
    expect(payload.service, 'Clinic');

    // Tolerates padding and a service containing the separator.
    final padded = decodeQueueQr('  SMARTQR | Counter 1 | A | B  ');
    expect(padded, isNotNull);
    expect(padded!.service, 'A | B');

    expect(decodeQueueQr(null), isNull);
    expect(decodeQueueQr('hello world'), isNull);
    expect(decodeQueueQr('OTHERAPP|Counter 1|Clinic'), isNull);
    expect(decodeQueueQr('SMARTQR|Counter 1|'), isNull);
    expect(decodeQueueQr('SMARTQR||Clinic'), isNull);

    for (final service in kServiceList) {
      expect(decodeQueueQr(encodeQueueQr(counter: 'Counter 2', service: service))
          ?.service, service);
    }
  });

  test('student scans QR, joins that counter, staff calls them', () async {
    // Isolate from other test files that share the default database folder.
    final base = await databaseFactory.getDatabasesPath();
    await databaseFactory.setDatabasesPath(p.join(base, 'queue_flow'));
    final path = p.join(await databaseFactory.getDatabasesPath(), 'smartqr.db');
    await databaseFactory.deleteDatabase(path);

    // Opens (and seeds) the database.
    expect(await DatabaseHelper.instance.login('2025-00123', 'password123'),
        isNotNull);

    // Student scans the QR on Counter 3.
    final payload = decodeQueueQr(
        encodeQueueQr(counter: 'Counter 3', service: 'Clinic'));
    expect(payload, isNotNull);

    expect(
        await DatabaseHelper.instance.getLastTicketForStudent('2025-11111'),
        isNull);
    final rowId = await DatabaseHelper.instance.joinQueue(
      studentId: '2025-11111',
      studentName: 'Scan Student',
      service: payload!.service,
      time: '11:15 AM',
      purpose: 'Check-up',
      counter: payload.counter,
    );
    expect(rowId, greaterThan(0));

    final joined =
        await DatabaseHelper.instance.getLastTicketForStudent('2025-11111');
    expect(joined, isNotNull);
    expect(joined!['status'], 'WAITING');
    expect(joined['counter'], 'Counter 3');
    expect(joined['service'], 'Clinic');

    // A second student picks Counter 4.
    await DatabaseHelper.instance.joinQueue(
      studentId: '2025-22222',
      studentName: 'Other Student',
      service: 'Registrar',
      time: '11:16 AM',
      purpose: 'Transcript',
      counter: 'Counter 4',
    );

    // Staff on Counter 3 calls next: the student who scanned that QR code.
    await DatabaseHelper.instance.callNext('Counter 3');
    final called =
        await DatabaseHelper.instance.getLastTicketForStudent('2025-11111');
    expect(called!['status'], 'SERVING');
    expect(called['counter'], 'Counter 3');

    // Counter 4 still finds its own student (nobody waiting at Counter 3).
    await DatabaseHelper.instance.callNext('Counter 4');
    final other =
        await DatabaseHelper.instance.getLastTicketForStudent('2025-22222');
    expect(other!['status'], 'SERVING');
    expect(other['counter'], 'Counter 4');

    // A counter nobody scanned still falls back to the next student in line.
    final servingBefore = await DatabaseHelper.instance.getNowServing();
    final waitingBefore = (await DatabaseHelper.instance.getActiveQueue())
        .where((r) => r['status'] == 'WAITING')
        .length;
    await DatabaseHelper.instance.callNext('Counter 5');
    final servingAfter = await DatabaseHelper.instance.getNowServing();
    if (waitingBefore == 0) {
      expect(servingAfter, hasLength(servingBefore.length));
    } else {
      expect(servingAfter, hasLength(servingBefore.length + 1));
      expect(
        servingAfter.where((r) => r['counter'] == 'Counter 5'),
        hasLength(1),
      );
    }

    // Serving the student finishes their ticket.
    await DatabaseHelper.instance.completeCurrent('Counter 3');
    final done =
        await DatabaseHelper.instance.getLastTicketForStudent('2025-11111');
    expect(done, isNull);
    expect(
      await DatabaseHelper.instance.getLastTicketForStudent('2025-22222'),
      isNotNull,
    );

    await databaseFactory.deleteDatabase(path);
  });
}
