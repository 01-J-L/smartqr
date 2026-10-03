import 'package:flutter/material.dart';

import 'database.dart';

class CallNextStudentScreen extends StatefulWidget {
  const CallNextStudentScreen({super.key});

  @override
  State<CallNextStudentScreen> createState() => _CallNextStudentScreenState();
}

class _CallNextStudentScreenState extends State<CallNextStudentScreen> {
  Map<String, dynamic>? _next;
  bool _loading = true;
  bool _calling = false;

  String get _counter => Session.counter;

  // Color Palette
  static const Color primaryNavy = Color(0xFF0D1B48);
  static const Color accentBlue = Color(0xFF1E88E5);
  static const Color lightBlueBg = Color(0xFFE1F0FF);
  static const Color cardBg = Color(0xFFFAFAFC);
  static const Color borderColor = Color(0xFFE5E7EB);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color textDark = Color(0xFF1E293B);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final active = await DatabaseHelper.instance.getActiveQueue();
    final waiting =
        active.where((q) => q['status'] == 'WAITING').toList();
    // Students who scanned this counter's QR code are served first.
    final assigned = waiting
        .where((q) => (q['counter'] ?? '') == _counter)
        .toList();
    if (mounted) {
      setState(() {
        final queue = assigned.isNotEmpty ? assigned : waiting;
        _next = queue.isNotEmpty ? queue.first : null;
        _loading = false;
      });
    }
  }

  Future<void> _callStudent() async {
    if (_next == null) return;
    setState(() => _calling = true);

    // Finishes whoever this counter is serving, then starts the next ticket.
    await DatabaseHelper.instance.serveTicket(_next!['id'] as int, _counter);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Now calling ${_next!['queue_no']} to $_counter')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ─── TOP ICON ─────────────────────────────────────────
                Container(
                  width: 76,
                  height: 76,
                  decoration: const BoxDecoration(
                    color: lightBlueBg,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.campaign_rounded,
                      color: accentBlue,
                      size: 38,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ─── HEADINGS ─────────────────────────────────────────
                const Text(
                  'Call Next Student?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: primaryNavy,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'Verify the details of the next student in the queue line before summoning.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: textMuted,
                      height: 1.4,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // ─── DETAILS CARD ─────────────────────────────────────
                if (_loading)
                  const CircularProgressIndicator()
                else if (_next == null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor, width: 1.2),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.people_outline_rounded,
                            size: 40, color: Color(0xFF94A3B8)),
                        SizedBox(height: 10),
                        Text(
                          'No students waiting in the queue.',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textMuted,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor, width: 1.2),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18.0, vertical: 14.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'QUEUE NUMBER',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                  color: textMuted,
                                ),
                              ),
                              Text(
                                _next!['queue_no'] as String,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: primaryNavy,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: borderColor),

                        _buildDetailRow(
                          label: 'STUDENT',
                          value: _next!['student_name'] as String,
                        ),
                        const Divider(height: 1, color: borderColor),

                        _buildDetailRow(
                          label: 'SERVICE',
                          value: _next!['service'] as String,
                        ),
                        const Divider(height: 1, color: borderColor),

                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18.0, vertical: 14.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'ASSIGNED TO',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                  color: textMuted,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F5E9),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _counter,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),

                // ─── ACTION BUTTONS ───────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed:
                        (_loading || _calling || _next == null) ? null : _callStudent,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryNavy,
                      disabledBackgroundColor: const Color(0xFF94A3B8),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _calling
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'CALL STUDENT',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () => Navigator.canPop(context) ? Navigator.pop(context) : null,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: primaryNavy, width: 1.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'CANCEL',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: primaryNavy,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Row Item Helper
  Widget _buildDetailRow({required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: textMuted,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: textDark,
            ),
          ),
        ],
      ),
    );
  }
}
