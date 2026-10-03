import 'dart:async';

import 'package:flutter/material.dart';

import 'database.dart';

/// Watches the signed-in student's active ticket and raises an in-app alert
/// as soon as a staff member moves it to `SERVING`.
class CallWatcher {
  CallWatcher({required this.onCalled});

  final void Function(Map<String, dynamic> ticket) onCalled;

  /// Tickets already announced during this app run, so the alert is shown
  /// exactly once even when more than one screen is watching.
  static final Set<int> _announced = <int>{};

  Timer? _timer;
  bool _checking = false;
  String _studentId = '';

  void start(String studentId) {
    _studentId = studentId;
    stop();
    _check();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _check());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _check() async {
    if (_checking || _studentId.isEmpty) return;
    _checking = true;
    try {
      final ticket =
          await DatabaseHelper.instance.getLastTicketForStudent(_studentId);
      if (ticket == null || ticket['status'] != 'SERVING') return;
      final id = ticket['id'] as int;
      if (_announced.add(id)) {
        onCalled(ticket);
      }
    } catch (_) {
      // Database is briefly unavailable; the next tick retries.
    } finally {
      _checking = false;
    }
  }
}

/// Full-screen alert shown to the student when their turn comes up.
Future<void> showCalledDialog(
  BuildContext context,
  Map<String, dynamic> ticket,
) {
  final queueNo = (ticket['queue_no'] as String?) ?? '—';
  final counter = (ticket['counter'] as String?) ?? 'the counter';
  final service = (ticket['service'] as String?) ?? '';

  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(20, 26, 20, 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.campaign_rounded,
                color: Color(0xFF2E7D32),
                size: 34,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'IT\'S YOUR TURN!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
                color: Color(0xFF1B2A7B),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Staff is calling you now.',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 16),
            Text(
              '#$queueNo',
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
                color: Color(0xFF0F2060),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Proceed to $counter',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            if (service.isNotEmpty)
              Text(
                service,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF6B7280),
                ),
              ),
            const SizedBox(height: 18),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.of(context).pushNamed('/my-queue');
            },
            child: const Text(
              'VIEW MY QUEUE',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E88E5),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B2A7B),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('GOT IT'),
          ),
        ],
      );
    },
  );
}
