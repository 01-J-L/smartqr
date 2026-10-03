import 'package:flutter/material.dart';

import 'database.dart';

class QueueSuccessScreen extends StatefulWidget {
  const QueueSuccessScreen({super.key});

  @override
  State<QueueSuccessScreen> createState() => _QueueSuccessScreenState();
}

class _QueueSuccessScreenState extends State<QueueSuccessScreen> {
  Map<String, dynamic>? _ticket;

  // Design Colors
  static const Color successGreen = Color(0xFF1E7E34);
  static const Color iconGreen = Color(0xFF2E7D32);
  static const Color iconGreenBg = Color(0xFFE8F5E9);
  static const Color primaryNavy = Color(0xFF1B287B);
  static const Color cardBg = Color(0xFFF7F8FA);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color textDark = Color(0xFF1F2937);

  @override
  void initState() {
    super.initState();
    _loadTicket();
  }

  Future<void> _loadTicket() async {
    final ticket = await DatabaseHelper.instance
        .getLastTicketForStudent(Session.studentId);
    if (mounted) {
      setState(() => _ticket = ticket);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticket = _ticket;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 20.0),
          child: Column(
            children: [
              const Spacer(flex: 1),

              // ─── SUCCESS ICON ──────────────────────────────────
              Container(
                width: 78,
                height: 78,
                decoration: const BoxDecoration(
                  color: iconGreenBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: iconGreen,
                  size: 42,
                ),
              ),
              const SizedBox(height: 24),

              // ─── HEADINGS ──────────────────────────────────────
              const Text(
                'QUEUE REQUEST SUCCESSFUL',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: successGreen,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'You have successfully joined the line. A notification will be sent when your turn is near.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: textMuted,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // ─── TICKET DETAILS CARD ────────────────────────────
              if (ticket == null)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFECEEF2)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'YOUR QUEUE NUMBER',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: Color(0xFF5D6F9E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '#${ticket['queue_no']}',
                        style: const TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F2060),
                          letterSpacing: -1,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14.0),
                        child: Divider(color: Color(0xFFE5E7EB), thickness: 1),
                      ),

                      _buildInfoRow('Service', ticket['service'] as String),
                      const SizedBox(height: 12),
                      _buildInfoRow('Preferred Time', ticket['time'] as String),
                      const SizedBox(height: 12),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Status',
                            style: TextStyle(
                              fontSize: 13,
                              color: textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              ticket['status'] as String,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFD97706),
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              const Spacer(flex: 2),

              // ─── ACTION BUTTONS ────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/my-queue');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryNavy,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'VIEW MY QUEUE',
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
                height: 52,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/student-dashboard',
                      (route) => false,
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: primaryNavy, width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'BACK TO HOME',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: primaryNavy,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  // Row Item Helper
  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: textDark,
          ),
        ),
      ],
    );
  }
}
