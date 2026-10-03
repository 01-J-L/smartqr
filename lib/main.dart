import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'database.dart';
import 'supabase_helper.dart';
import 'login.dart';
import 'register.dart';
import 'student_dashboard.dart';
import 'staff_dashboard.dart';
import 'staff_qr.dart';
import 'admin_dashboard.dart';
import 'scanner.dart';
import 'request.dart';
import 'confirmation.dart';
import 'my_qeue.dart';
import 'qeue_management.dart';
import 'call_next.dart';
import 'public.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // One shared online database: every device that opens the app reads and
  // writes the same Supabase project instead of its own local file.
  await Supabase.initialize(
    url: SupabaseHelper.supabaseUrl,
    publishableKey: SupabaseHelper.supabasePublishableKey,
  );
  DatabaseHelper.instance = SupabaseHelper();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartQR',
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/student-dashboard': (context) => const DashboardScreen(),
        '/staff-dashboard': (context) => const StaffPortalScreen(),
        '/staff-qr': (context) => const StaffQrScreen(),
        '/admin-dashboard': (context) => const AdminDashboardScreen(),
        '/scanner': (context) => const ScanQrScreen(),
        '/request': (context) => const RequestServiceScreen(),
        '/confirmation': (context) => const QueueSuccessScreen(),
        '/my-queue': (context) => const MyQueueScreen(),
        '/queue-management': (context) => const QueueManagementPortal(),
        '/call-next': (context) => const CallNextStudentScreen(),
        '/public-display': (context) => const QueueDisplayScreen(),
      },
    );
  }
}
