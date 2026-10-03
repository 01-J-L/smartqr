import 'package:flutter/material.dart';

import 'database.dart';

class StaffPortalScreen extends StatefulWidget {
  const StaffPortalScreen({super.key});

  @override
  State<StaffPortalScreen> createState() => _StaffPortalScreenState();
}

class _StaffPortalScreenState extends State<StaffPortalScreen> {
  Map<String, int> _stats = {'waiting': 0, 'serving': 0, 'done': 0};
  Map<String, int> _todayStats = {'waiting': 0, 'serving': 0, 'done': 0, 'cancelled': 0, 'total': 0};
  String _nowServing = '—';

  // Color Palette
  static const Color headerNavy = Color(0xFF0D1B48);
  static const Color buttonNavy = Color(0xFF1B267E);
  static const Color accentBlue = Color(0xFF1E88E5);
  static const Color accentOrange = Color(0xFFEA580C);
  static const Color accentGreen = Color(0xFF2E7D32);
  static const Color pageBg = Color(0xFFF6F8FB);
  static const Color textGrey = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final stats = await DatabaseHelper.instance.getQueueStats();
    final today = await DatabaseHelper.instance.getTodayStats();
    final serving = await DatabaseHelper.instance.getNowServing();
    if (!mounted) return;
    final mine = serving
        .where((row) => (row['counter'] ?? '') == Session.counter)
        .toList();
    setState(() {
      _stats = stats;
      _todayStats = today;
      _nowServing = mine.isNotEmpty ? (mine.first['queue_no'] as String) : '—';
    });
  }

  void _logout() {
    Session.clear();
    Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBg,
      body: Column(
        children: [
          // ─── TOP APP BAR & STAFF HEADER ───────────────────────
          Container(
            color: headerNavy,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 22),
                          onPressed: _logout,
                        ),
                        const Text(
                          'STAFF PORTAL',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.format_list_bulleted_rounded, color: Colors.white, size: 24),
                          onPressed: () {
                            Navigator.pushNamed(context, '/queue-management').then((_) => _load());
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    Text(
                      Session.fullName.isNotEmpty ? Session.fullName : 'Staff',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    RichText(
                      text: TextSpan(
                        text: 'Assigned Counter: ',
                        style: const TextStyle(
                          color: Color(0xFF909BB8),
                          fontSize: 13,
                        ),
                          children: [
                            TextSpan(
                              text: Session.counter,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),

          // ─── MAIN CONTENT ─────────────────────────────────────
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Metric Cards Row
                    Row(
                      children: [
                        _buildMetricCard(
                          label: 'NOW SERVING',
                          value: _nowServing,
                          valueColor: accentBlue,
                        ),
                        const SizedBox(width: 12),
                        _buildMetricCard(
                          label: 'WAITING',
                          value: '${_stats['waiting'] ?? 0}',
                          valueColor: accentOrange,
                        ),
                        const SizedBox(width: 12),
                        _buildMetricCard(
                          label: 'SERVING',
                          value: '${_stats['serving'] ?? 0}',
                          valueColor: accentGreen,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // 2. Call Next Student Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/call-next').then((_) => _load());
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: buttonNavy,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.campaign_outlined,
                              color: Colors.white,
                              size: 24,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'CALL NEXT STUDENT',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // 2b. QR CODE FOR STUDENTS
                    InkWell(
                      onTap: () {
                        Navigator.pushNamed(context, '/staff-qr',
                                arguments: Session.counter)
                            .then((_) => _load());
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                          color: headerNavy,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.qr_code_2_rounded,
                                color: Colors.white, size: 26),
                            SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'SHOW QR CODE TO STUDENTS',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    'Students scan it to join your counter queue',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: Color(0xFF909BB8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded,
                                color: Color(0xFF909BB8)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // 3. Completed Requests Today Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE8F5E9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: accentGreen,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Completed Requests Today',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: textGrey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${_todayStats['done'] ?? 0} students assisted',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ─── QUEUE MANAGEMENT LINK ─────────────────────
                    InkWell(
                      onTap: () {
                        Navigator.pushNamed(context, '/queue-management').then((_) => _load());
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.format_list_bulleted_rounded, color: accentBlue),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Open Queue Management Portal',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ─── PUBLIC DISPLAY LINK ────────────────────────
                    InkWell(
                      onTap: () => Navigator.pushNamed(context, '/public-display'),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.tv_rounded, color: accentGreen),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Open Public Queue Display',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper Widget for Summary Stat Cards
  Widget _buildMetricCard({
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: textGrey,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: valueColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
