import 'dart:async';

import 'package:flutter/material.dart';

import 'database.dart';

class QueueDisplayScreen extends StatefulWidget {
  const QueueDisplayScreen({super.key});

  @override
  State<QueueDisplayScreen> createState() => _QueueDisplayScreenState();
}

class _QueueDisplayScreenState extends State<QueueDisplayScreen> {
  List<Map<String, dynamic>> _active = [];
  Timer? _timer;

  // Color Palette
  static const Color backgroundNavy = Color(0xFF08112C);
  static const Color activeCardNavy = Color(0xFF1D2B7B);
  static const Color numberYellow = Color(0xFFFFCF33);
  static const Color bannerGreen = Color(0xFF2E7D32);
  static const Color borderNavy = Color(0xFF1B285E);
  static const Color listPillNavy = Color(0xFF16235E);
  static const Color counterBadgeNavy = Color(0xFF0F1740);

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final active = await DatabaseHelper.instance.getActiveQueue();
    if (mounted) {
      setState(() => _active = active);
    }
  }

  Map<String, dynamic>? get _nowServing {
    final serving = _active.where((q) => q['status'] == 'SERVING').toList();
    return serving.isNotEmpty ? serving.first : null;
  }

  List<Map<String, dynamic>> get _upNext =>
      _active.where((q) => q['status'] == 'WAITING').take(3).toList();

  @override
  Widget build(BuildContext context) {
    final serving = _nowServing;

    return Scaffold(
      backgroundColor: backgroundNavy,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            children: [
              // ─── 1. TOP HEADER ────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Brand Logo & Title
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded,
                              color: Colors.white, size: 18),
                          onPressed: () =>
                              Navigator.canPop(context) ? Navigator.pop(context) : null,
                        ),
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.qr_code_2_rounded,
                            color: backgroundNavy,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'SMARTQR QUEUE DISPLAY',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),

                    // Service Center Label
                    const Text(
                      'STUDENT SERVICE CENTER',
                      style: TextStyle(
                        color: Color(0xFF5A72A4),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),

              // Header Separator Line
              const Divider(color: Color(0xFF13204D), thickness: 1.2),
              const SizedBox(height: 12),

              // ─── 2. MAIN CARDS ROW ────────────────────────────────
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // LEFT: NOW SERVING (Active Ticket)
                    Expanded(
                      flex: 6,
                      child: Container(
                        decoration: BoxDecoration(
                          color: activeCardNavy,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'NOW SERVING',
                              style: TextStyle(
                                color: Color(0xFF8E9BB5),
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),

                            // Large Ticket Number
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                serving != null
                                    ? (serving['queue_no'] as String)
                                    : '—',
                                style: const TextStyle(
                                  color: numberYellow,
                                  fontSize: 88,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),

                            // Counter Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F1948),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: const Color(0xFF2E3D7D), width: 1.2),
                              ),
                              child: Text(
                                serving != null && serving['counter'] != null
                                    ? (serving['counter'] as String).toUpperCase()
                                    : 'NO COUNTER',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),

                    // RIGHT: UP NEXT QUEUE
                    Expanded(
                      flex: 4,
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: backgroundNavy,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: borderNavy, width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'UP NEXT',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 12),

                            if (_upNext.isEmpty)
                              const Expanded(
                                child: Center(
                                  child: Text(
                                    'No one in queue',
                                    style: TextStyle(
                                      color: Color(0xFF5A72A4),
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              )
                            else
                              for (int i = 0; i < _upNext.length; i++) ...[
                                if (i > 0) const SizedBox(height: 10),
                                Expanded(
                                  child: _buildUpNextItem(
                                    _upNext[i]['queue_no'] as String,
                                    _upNext[i]['service'] as String,
                                  ),
                                ),
                              ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ─── 3. BOTTOM ANNOUNCEMENT TICKER ────────────────────
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                decoration: BoxDecoration(
                  color: bannerGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.campaign_outlined,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        serving != null
                            ? 'TICKET ${serving['queue_no']} PLEASE PROCEED TO ${(serving['counter'] ?? 'COUNTER').toString().toUpperCase()}'
                            : 'WELCOME TO THE STUDENT SERVICE CENTER',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Up Next Queue Item Helper
  Widget _buildUpNextItem(String queueNo, String service) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: listPillNavy,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            queueNo,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: counterBadgeNavy,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              service,
              style: const TextStyle(
                color: Color(0xFF909BB8),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
