import 'package:flutter/material.dart';

import 'call_watcher.dart';
import 'database.dart';

class MyQueueScreen extends StatefulWidget {
  const MyQueueScreen({super.key});

  @override
  State<MyQueueScreen> createState() => _MyQueueScreenState();
}

class _MyQueueScreenState extends State<MyQueueScreen> {
  final int _currentIndex = 1; // "My Queue" tab selected
  Map<String, dynamic>? _ticket;
  List<Map<String, dynamic>> _queueAhead = [];
  bool _loading = true;
  late final CallWatcher _watcher;

  // Color Palette
  static const Color headerNavy = Color(0xFF0F1A44);
  static const Color primaryNavy = Color(0xFF0F1E5C);
  static const Color greenAccent = Color(0xFF1E824C);
  static const Color labelGrey = Color(0xFF64748B);
  static const Color pageBg = Color(0xFFF6F8FB);

  @override
  void initState() {
    super.initState();
    _load();
    _watcher = CallWatcher(onCalled: _onStaffCalled)
      ..start(Session.studentId);
  }

  @override
  void dispose() {
    _watcher.stop();
    super.dispose();
  }

  void _onStaffCalled(Map<String, dynamic> ticket) {
    if (!mounted) return;
    _load();
    showCalledDialog(context, ticket);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final ticket = await DatabaseHelper.instance
        .getLastTicketForStudent(Session.studentId);
    final active = await DatabaseHelper.instance.getActiveQueue();

    List<Map<String, dynamic>> timeline = [];
    if (ticket != null) {
      final ticketId = ticket['id'] as int;
      // Timeline: now serving + tickets before yours + yours
      final serving = active.where((q) => q['status'] == 'SERVING').toList();
      final before = active
          .where((q) =>
              (q['id'] as int) < ticketId && q['status'] == 'WAITING')
          .toList();
      timeline = [...serving, ...before, ticket];
    }

    if (mounted) {
      setState(() {
        _ticket = ticket;
        _queueAhead = timeline;
        _loading = false;
      });
    }
  }

  String get _nowServing {
    final serving =
        _queueAhead.firstWhere((q) => q['status'] == 'SERVING', orElse: () => {});
    return serving.isNotEmpty ? (serving['queue_no'] as String) : '—';
  }

  String get _windowLabel {
    if (_ticket == null) return '';
    final service = _ticket!['service'] as String;
    final counter = _ticket!['counter'] as String?;
    if (counter != null) return '$service • $counter';
    return service;
  }

  void _onNavTap(int index) {
    if (index == 1) return;
    if (index == 0) {
      Navigator.pushReplacementNamed(context, '/student-dashboard');
    } else if (index == 2) {
      _showHistory();
    } else if (index == 3) {
      _showProfile();
    }
  }

  void _showHistory() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return FutureBuilder(
          future: DatabaseHelper.instance.getQueueForStudent(Session.studentId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final tickets = snapshot.data!;
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Queue History',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: tickets.length,
                      itemBuilder: (context, i) {
                        final t = tickets[i];
                        return ListTile(
                          leading: Text(
                            t['queue_no'] as String,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: primaryNavy,
                            ),
                          ),
                          title: Text(t['service'] as String),
                          subtitle: Text(t['time'] as String),
                          trailing: Text(
                            t['status'] as String,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showProfile() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: ${Session.fullName}'),
            Text('Student ID: ${Session.studentId}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Session.clear();
              Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBg,
      body: Column(
        children: [
          // ─── TOP APP BAR ──────────────────────────────────────
          Container(
            color: headerNavy,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      onPressed: () => Navigator.canPop(context) ? Navigator.pop(context) : null,
                    ),
                    const Expanded(
                      child: Center(
                        child: Text(
                          'MY QUEUE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                      onPressed: _load,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ─── MAIN CONTENT ─────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20.0, vertical: 20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_ticket == null)
                            _buildNoTicket()
                          else ...[
                            _buildTicketCard(),
                            const SizedBox(height: 26),

                            // ─── QUEUE TIMELINE SECTION ──────────────
                            const Text(
                              'QUEUE TIMELINE',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                                color: labelGrey,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildTimeline(),
                            const SizedBox(height: 24),
                          ],
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),

      // ─── BOTTOM NAVIGATION BAR ─────────────────────────────
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onNavTap,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 0,
          selectedItemColor: primaryNavy,
          unselectedItemColor: const Color(0xFF94A3B8),
          selectedFontSize: 11,
          unselectedFontSize: 11,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.confirmation_number_rounded),
              label: 'My Queue',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.access_time_rounded),
              label: 'History',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoTicket() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Column(
        children: [
          Icon(Icons.confirmation_number_outlined,
              size: 48, color: Color(0xFF94A3B8)),
          SizedBox(height: 12),
          Text(
            'No active ticket',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Join the queue from the scanner to see your ticket here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketCard() {
    final status = _ticket!['status'] as String;
    final statusBg = status == 'SERVING'
        ? const Color(0xFFE8F5E9)
        : const Color(0xFFFEF3C7);
    final statusFg =
        status == 'SERVING' ? const Color(0xFF2E7D32) : const Color(0xFFD97706);

    int ahead = 0;
    for (final q in _queueAhead) {
      if (q['id'] != _ticket!['id'] && q['status'] == 'WAITING') {
        ahead++;
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'YOUR TICKET NUMBER',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: Color(0xFF4C5E96),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _ticket!['queue_no'] as String,
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w900,
              color: primaryNavy,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _windowLabel,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20.0),
            child: Divider(color: Color(0xFFF1F5F9), thickness: 1.5),
          ),

          _buildDetailRow(
            'NOW SERVING',
            _nowServing,
            valueColor: greenAccent,
            valueFontSize: 16,
          ),
          const SizedBox(height: 16),

          _buildDetailRow(
            'PEOPLE BEFORE YOU',
            '$ahead',
            valueColor: primaryNavy,
            valueFontSize: 16,
          ),
          const SizedBox(height: 16),

          _buildDetailRow(
            'ESTIMATED WAIT',
            '${ahead * 5} minutes',
            valueColor: primaryNavy,
            valueFontSize: 15.5,
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'STATUS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: labelGrey,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: statusFg,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    if (_queueAhead.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (int i = 0; i < _queueAhead.length; i++) ...[
            if (i > 0)
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: Color(0xFF94A3B8)),
            _buildTimelinePill(
              _queueAhead[i]['queue_no'] as String,
              isCurrent: _queueAhead[i]['id'] == _ticket!['id'],
            ),
          ],
        ],
      ),
    );
  }

  // Ticket Detail Key-Value Row Helper
  Widget _buildDetailRow(
    String label,
    String value, {
    required Color valueColor,
    double valueFontSize = 15,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: labelGrey,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: valueFontSize,
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  // Timeline Badge Helper
  Widget _buildTimelinePill(String number, {bool isCurrent = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isCurrent ? greenAccent : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        number,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: isCurrent ? Colors.white : primaryNavy,
        ),
      ),
    );
  }
}
