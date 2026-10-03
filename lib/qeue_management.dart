import 'package:flutter/material.dart';

import 'database.dart';

class QueueManagementPortal extends StatefulWidget {
  const QueueManagementPortal({super.key});

  @override
  State<QueueManagementPortal> createState() => _QueueManagementPortalState();
}

class _QueueManagementPortalState extends State<QueueManagementPortal> {
  List<Map<String, dynamic>> _queueData = [];
  bool _loading = true;

  // Color Palette
  static const Color headerNavy = Color(0xFF0D1A44);
  static const Color primaryBlue = Color(0xFF1E88E5);
  static const Color queueNavy = Color(0xFF0F267A);
  static const Color pageBg = Color(0xFFF4F6F9);
  static const Color tableBorder = Color(0xFFE5E7EB);
  static const Color textGrey = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = await DatabaseHelper.instance.getActiveQueue();
    if (mounted) {
      setState(() {
        _queueData = data;
        _loading = false;
      });
    }
  }

  Future<void> _call(Map<String, dynamic> item) async {
    final counter = Session.counter;
    // Finish this counter's current ticket first so only one is SERVING here.
    await DatabaseHelper.instance.serveTicket(item['id'] as int, counter);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Now calling ${item['queue_no']} to $counter...'),
        ),
      );
      _load();
    }
  }

  Future<void> _done(Map<String, dynamic> item) async {
    await DatabaseHelper.instance.updateStatus(item['id'] as int, 'DONE');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ticket ${item['queue_no']} completed.')),
      );
      _load();
    }
  }

  void _view(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ticket ${item['queue_no']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Student: ${item['student_name']}'),
            Text('Student ID: ${item['student_id']}'),
            Text('Service: ${item['service']}'),
            Text('Time: ${item['time']}'),
            Text('Purpose: ${item['purpose'] ?? '—'}'),
            Text('Status: ${item['status']}'),
            if (item['counter'] != null) Text('Counter: ${item['counter']}'),
            Text('Created: ${item['created_at'] ?? '—'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                    onPressed: () => Navigator.canPop(context) ? Navigator.pop(context) : null,
                  ),
                  const Icon(
                    Icons.format_list_bulleted_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'QUEUE MANAGEMENT PORTAL',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),

                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
                    onPressed: _load,
                  ),
                  const SizedBox(width: 8),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2D69),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Staff Account',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ─── MAIN TABLE CONTAINER ─────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(24.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: tableBorder),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            if (_queueData.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(40),
                                child: Text(
                                  'No active tickets in the queue.',
                                  style: TextStyle(color: textGrey),
                                ),
                              )
                            else
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(minWidth: 990),
                                  child: Column(
                                    children: [
                                      // ─── TABLE HEADER ───────────
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 24, vertical: 16),
                                        decoration: const BoxDecoration(
                                          border: Border(
                                              bottom: BorderSide(color: tableBorder)),
                                        ),
                                        child: const Row(
                                          children: [
                                            SizedBox(
                                                width: 110,
                                                child: _HeaderCell('QUEUE NO.')),
                                            SizedBox(
                                                width: 140,
                                                child: _HeaderCell('STUDENT ID')),
                                            SizedBox(
                                                width: 180,
                                                child: _HeaderCell('STUDENT NAME')),
                                            SizedBox(
                                                width: 140,
                                                child: _HeaderCell('SERVICE')),
                                            SizedBox(
                                                width: 120, child: _HeaderCell('TIME')),
                                            SizedBox(
                                                width: 150,
                                                child: _HeaderCell('STATUS')),
                                            SizedBox(
                                                width: 240,
                                                child: _HeaderCell('ACTIONS',
                                                    textAlign: TextAlign.right)),
                                          ],
                                        ),
                                      ),

                                      // ─── TABLE ROWS ─────────────
                                      ..._queueData
                                          .map((item) => _buildTableRow(item)),
                                    ],
                                  ),
                                ),
                              ),

                            // ─── BOTTOM LINK ────────────────────
                            const Divider(height: 1, color: tableBorder),
                            InkWell(
                              onTap: _load,
                              borderRadius: const BorderRadius.vertical(
                                  bottom: Radius.circular(16)),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                alignment: Alignment.center,
                                child: const Text(
                                  'Refresh Active Tickets',
                                  style: TextStyle(
                                    color: primaryBlue,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // Row Builder
  Widget _buildTableRow(Map<String, dynamic> item) {
    final status = item['status'] as String;
    final statusBg = status == 'SERVING'
        ? const Color(0xFFE1F0FF)
        : const Color(0xFFFEF3C7);
    final statusFg =
        status == 'SERVING' ? const Color(0xFF1E88E5) : const Color(0xFFD97706);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          // Queue No.
          SizedBox(
            width: 110,
            child: Text(
              item['queue_no'] as String,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: queueNavy,
              ),
            ),
          ),

          // Student ID
          SizedBox(
            width: 140,
            child: Text(
              item['student_id'] as String,
              style: const TextStyle(
                fontSize: 13.5,
                color: Color(0xFF4B5563),
              ),
            ),
          ),

          // Student Name
          SizedBox(
            width: 180,
            child: Text(
              item['student_name'] as String,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
          ),

          // Service
          SizedBox(
            width: 140,
            child: Text(
              item['service'] as String,
              style: const TextStyle(
                fontSize: 13.5,
                color: Color(0xFF4B5563),
              ),
            ),
          ),

          // Time
          SizedBox(
            width: 120,
            child: Text(
              item['time'] as String,
              style: const TextStyle(
                fontSize: 13.5,
                color: Color(0xFF4B5563),
              ),
            ),
          ),

          // Status Badge
          SizedBox(
            width: 150,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: statusFg,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
          ),

          // Actions Buttons (CALL, DONE & VIEW)
          SizedBox(
            width: 240,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                  height: 32,
                  child: ElevatedButton(
                    onPressed: status == 'WAITING' ? () => _call(item) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      disabledBackgroundColor: const Color(0xFF93C5FD),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'CALL',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                SizedBox(
                  height: 32,
                  child: ElevatedButton(
                    onPressed:
                        status == 'SERVING' ? () => _done(item) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      disabledBackgroundColor: const Color(0xFFBBF7D0),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'DONE',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                SizedBox(
                  height: 32,
                  child: OutlinedButton(
                    onPressed: () => _view(item),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'VIEW',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Header Cell Helper Widget
class _HeaderCell extends StatelessWidget {
  final String text;
  final TextAlign textAlign;

  const _HeaderCell(this.text, {this.textAlign = TextAlign.left});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: textAlign,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
        color: _QueueManagementPortalState.textGrey,
      ),
    );
  }
}
