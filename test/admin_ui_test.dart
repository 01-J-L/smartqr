import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mobile/admin_dashboard.dart';
import 'package:mobile/database.dart';
import 'package:mobile/staff_dashboard.dart';

/// sqflite does real file I/O, which the fake-async test zone cannot drive on
/// its own. Give the database a moment to finish, then pump frames until the
/// tree goes quiet.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 80; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 40));
    if (!tester.binding.hasScheduledFrame) return;
  }
  fail('the widget tree never stopped scheduling frames');
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  testWidgets('every admin sidebar entry opens a working section',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Real file I/O has to happen off the fake-async test zone.
    await tester.runAsync(() async {
      final base = await databaseFactory.getDatabasesPath();
      await databaseFactory.setDatabasesPath(p.join(base, 'admin_ui'));
      final path =
          p.join(await databaseFactory.getDatabasesPath(), 'smartqr.db');
      await databaseFactory.deleteDatabase(path);

      final admin =
          await DatabaseHelper.instance.login('ADMIN001', 'password123');
      expect(admin, isNotNull);
      Session.user = admin;

      // One real ticket so the reports and history panels have data.
      await DatabaseHelper.instance.joinQueue(
        studentId: '2025-00123',
        studentName: 'Juan Dela Cruz',
        service: 'Registrar',
        time: '9:30 AM',
        purpose: 'Request Transcript',
      );
    });

    await tester.pumpWidget(const MaterialApp(home: AdminDashboardScreen()));
    await _settle(tester);
    expect(find.text('Dashboard Overview'), findsOneWidget);
    expect(find.text("TODAY'S QUEUE"), findsOneWidget);

    await tester.tap(find.text('Services'));
    await _settle(tester);
    expect(find.text('ADD A SERVICE'), findsOneWidget);

    // Adding a service persists it and shows up immediately.
    await tester.enterText(
      find.byType(TextField).first,
      'Scholarship Office',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'ADD'));
    await _settle(tester);
    expect(find.text('Scholarship Office'), findsOneWidget);

    await tester.tap(find.text('Counters').first);
    await _settle(tester);
    expect(find.text('Counter 1'), findsOneWidget);

    await tester.tap(find.text('Staff').first);
    await _settle(tester);
    expect(find.text('Admin User'), findsWidgets); // sidebar + staff list

    await tester.tap(find.text('Queue History').first);
    await _settle(tester);
    expect(find.text('A001'), findsOneWidget);

    await tester.tap(find.text('Reports').first);
    await _settle(tester);
    expect(find.text('COMPLETION RATE'), findsOneWidget);
    expect(find.text('LAST 7 DAYS'), findsOneWidget);

    await tester.tap(find.text('Settings').first);
    await _settle(tester);
    expect(find.text('SIGNED-IN ACCOUNT'), findsOneWidget);
    expect(find.text('ADMIN001'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('staff portal renders with the assigned counter', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.runAsync(() async {
      final staff =
          await DatabaseHelper.instance.login('STAFF001', 'password123');
      expect(staff, isNotNull);
      Session.user = staff;
      await DatabaseHelper.instance
          .assignCounter(staff!['id'] as int, 'Counter 2');
      // Session holds a mutable copy of the row, so screens can update it.
      Session.user!['counter'] = 'Counter 2';
    });
    expect(Session.counter, 'Counter 2');

    await tester.pumpWidget(const MaterialApp(home: StaffPortalScreen()));
    await _settle(tester);

    expect(find.text('STAFF PORTAL'), findsOneWidget);
    expect(find.text('CALL NEXT STUDENT'), findsOneWidget);
    expect(find.text('NOW SERVING'), findsOneWidget);
    expect(
      tester.widgetList(find.byType(RichText)).map((w) {
        final rich = w as RichText;
        return rich.text.toPlainText();
      }),
      contains('Assigned Counter: Counter 2'),
    );

    await tester.pumpWidget(const SizedBox());
  });
}
