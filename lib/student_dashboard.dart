import 'package:flutter/material.dart';

import 'call_watcher.dart';
import 'database.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final int _currentIndex = 0;
  Map<String, dynamic>? _activeTicket;
  late final CallWatcher _watcher;

  // Design Colors
  static const Color headerNavy = Color(0xFF0F1B4C);
  static const Color primaryNavy = Color(0xFF1B2A7B);
  static const Color iconBlue = Color(0xFF1E88E5);
  static const Color iconGreen = Color(0xFF2E8B57);
  static const Color subTextGrey = Color(0xFF8E9BB0);

  @override
  void initState() {
    super.initState();
    _loadTicket();
    _watcher = CallWatcher(onCalled: _onStaffCalled)
      ..start(Session.studentId);
  }

  @override
  void dispose() {
    _watcher.stop();
    super.dispose();
  }

  /// Fires when staff moves this student's ticket to SERVING.
  void _onStaffCalled(Map<String, dynamic> ticket) {
    if (!mounted) return;
    setState(() => _activeTicket = ticket);
    showCalledDialog(context, ticket);
  }

  void _openNotifications() {
    final ticket = _activeTicket;
    if (ticket != null && ticket['status'] == 'SERVING') {
      showCalledDialog(context, ticket);
      return;
    }
    final message = ticket != null
        ? 'Ticket #${ticket['queue_no']} is still in the queue. '
            'We\'ll notify you when staff calls you.'
        : 'No new notifications.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _loadTicket() async {
    final ticket = await DatabaseHelper.instance
        .getLastTicketForStudent(Session.studentId);
    if (mounted) {
      setState(() => _activeTicket = ticket);
    }
  }

  String get _initials {
    final parts = Session.fullName.split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return Session.fullName.isNotEmpty
        ? Session.fullName.substring(0, 1).toUpperCase()
        : '?';
  }

  String get _firstName {
    final parts = Session.fullName.split(' ');
    return parts.first;
  }

  void _logout() {
    Session.clear();
    Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
  }

  void _onNavTap(int index) {
    if (index == 0) return; // already home
    if (index == 1) {
      Navigator.pushNamed(context, '/my-queue').then((_) => _loadTicket());
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
                  if (tickets.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('No history yet.'),
                    )
                  else
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
                            trailing: _StatusBadge(status: t['status'] as String),
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
            Text('Email: ${Session.user?['email'] ?? ''}'),
            Text('Contact: ${Session.user?['contact'] ?? ''}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _logout();
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
      backgroundColor: const Color(0xFFF6F8FB),
      body: Column(
        children: [
          // ─── TOP NAV & USER HEADER ───────────────────────────
          Container(
            color: headerNavy,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Column(
                  children: [
                    // App Bar Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.menu, color: Colors.white, size: 26),
                          onPressed: () => _showProfile(),
                        ),
                        const Text(
                          'SMARTQR',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            _activeTicket != null &&
                                    _activeTicket!['status'] == 'SERVING'
                                ? Icons.notifications_active_rounded
                                : Icons.notifications_none_rounded,
                            color: _activeTicket != null &&
                                    _activeTicket!['status'] == 'SERVING'
                                ? const Color(0xFFFDE047)
                                : Colors.white,
                            size: 26,
                          ),
                          onPressed: _openNotifications,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // User Profile Info
                    Padding(
                      padding: const EdgeInsets.only(left: 6.0, bottom: 14.0),
                      child: Row(
                        children: [
                          // Initials Avatar
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF1E2D70),
                              border: Border.all(color: const Color(0xFF384B94), width: 1.5),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _initials,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Name and Student ID
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Good Morning, $_firstName!',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Student ID: ${Session.studentId}',
                                style: const TextStyle(
                                  color: subTextGrey,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ─── MAIN CONTENT ─────────────────────────────────────
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadTicket,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Scan QR Code Card
                    _buildActionCard(
                      backgroundColor: const Color(0xFF101B4B),
                      iconBgColor: iconBlue,
                      icon: Icons.qr_code_scanner_rounded,
                      title: 'SCAN QR CODE',
                      titleColor: Colors.white,
                      subtitle: 'Scan kiosk QR code to get queue number',
                      subtitleColor: const Color(0xFF8A99C7),
                      onTap: () {
                        Navigator.pushNamed(context, '/scanner').then((_) => _loadTicket());
                      },
                    ),
                    const SizedBox(height: 14),

                    // 2. My Queue Card
                    _buildActionCard(
                      backgroundColor: primaryNavy,
                      iconBgColor: iconGreen,
                      icon: Icons.confirmation_number_outlined,
                      title: 'MY QUEUE',
                      titleColor: Colors.white,
                      subtitle: 'View status of your ongoing tickets',
                      subtitleColor: const Color(0xFF8A99C7),
                      onTap: () {
                        Navigator.pushNamed(context, '/my-queue').then((_) => _loadTicket());
                      },
                    ),
                    const SizedBox(height: 14),

                    // 3. Queue History Card
                    _buildActionCard(
                      backgroundColor: Colors.white,
                      iconBgColor: const Color(0xFFE8F5E9),
                      icon: Icons.access_time_rounded,
                      iconColor: iconGreen,
                      title: 'QUEUE HISTORY',
                      titleColor: iconGreen,
                      subtitle: 'Browse completed and cancelled requests',
                      subtitleColor: const Color(0xFF6B7280),
                      hasBorder: true,
                      onTap: _showHistory,
                    ),
                    const SizedBox(height: 24),

                    // Section Title
                    const Text(
                      'ACTIVE QUEUE TICKET',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Active Ticket Card
                    if (_activeTicket == null)
                      _buildEmptyTicket()
                    else
                      _buildActiveTicket(_activeTicket!),
                    const SizedBox(height: 20),
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
              activeIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.confirmation_number_outlined),
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

  Widget _buildEmptyTicket() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Column(
        children: [
          Icon(Icons.confirmation_number_outlined, size: 40, color: Color(0xFF94A3B8)),
          SizedBox(height: 8),
          Text(
            'No active ticket',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Scan a QR code to join the queue.',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTicket(Map<String, dynamic> ticket) {
    final status = ticket['status'] as String;
    final statusColor = status == 'SERVING'
        ? const Color(0xFF16A34A)
        : const Color(0xFFD97706);
    final statusBg = status == 'SERVING'
        ? const Color(0xFFE8F5E9)
        : const Color(0xFFFEF3C7);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticket['service'] as String,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      ticket['purpose'] as String? ?? '',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14.0),
            child: Divider(color: Color(0xFFF1F5F9), thickness: 1.5),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'YOUR NUMBER',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ticket['queue_no'] as String,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF102570),
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'TIME',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ticket['time'] as String,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Action Card Builder Helper
  Widget _buildActionCard({
    required Color backgroundColor,
    required Color iconBgColor,
    required IconData icon,
    Color iconColor = Colors.white,
    required String title,
    required Color titleColor,
    required String subtitle,
    required Color subtitleColor,
    bool hasBorder = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: hasBorder ? Border.all(color: const Color(0xFFE2E8F0)) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: titleColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: subtitleColor,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: subtitleColor, size: 22),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (status) {
      case 'DONE':
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF2E7D32);
        break;
      case 'SERVING':
        bg = const Color(0xFFE1F0FF);
        fg = const Color(0xFF1E88E5);
        break;
      case 'CANCELLED':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        break;
      default:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFD97706);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: fg,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
