import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'database.dart';
import 'qr_payload.dart';

/// Staff screen that displays the QR code students scan to join the queue.
class StaffQrScreen extends StatefulWidget {
  const StaffQrScreen({super.key});

  @override
  State<StaffQrScreen> createState() => _StaffQrScreenState();
}

class _StaffQrScreenState extends State<StaffQrScreen> {
  static const Color headerNavy = Color(0xFF0D1B48);
  static const Color primaryBlue = Color(0xFF1E88E5);
  static const Color pageBg = Color(0xFFF6F8FB);
  static const Color textGrey = Color(0xFF6B7280);

  List<String> _counters = kCounterList;
  List<String> _services = kServiceList;

  String _counter = kCounterList.first;
  String _service = kServiceList.first;
  bool _loaded = false;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String && args.isNotEmpty) {
      _counter = args;
    } else {
      _counter = Session.counter;
    }
    _loadOptions();
  }

  /// Counters and services come from the database so admin edits show up here.
  Future<void> _loadOptions() async {
    try {
      final counterRows = await DatabaseHelper.instance.getCounters();
      final serviceRows = await DatabaseHelper.instance.getServices();
      if (!mounted) return;
      setState(() {
        if (counterRows.isNotEmpty) {
          _counters = counterRows.map((r) => r['name'] as String).toList();
        }
        if (serviceRows.isNotEmpty) {
          _services = serviceRows.map((r) => r['name'] as String).toList();
        }
        if (!_counters.contains(_counter)) {
          _counter = _counters.contains(Session.counter)
              ? Session.counter
              : _counters.first;
        }
        if (!_services.contains(_service)) _service = _services.first;
      });
    } catch (_) {
      // Fall back to the reference lists already in place.
    }
  }

  /// Persisting the picked counter makes it the account's assigned counter.
  Future<void> _onCounterChanged(String? value) async {
    if (value == null || value == _counter) return;
    setState(() {
      _counter = value;
      _saving = true;
    });
    final userId = Session.user?['id'] as int?;
    if (userId != null) {
      await DatabaseHelper.instance.assignCounter(userId, value);
      Session.user!['counter'] = value;
    }
    if (!mounted) return;
    setState(() => _saving = false);
  }

  String get _payload => encodeQueueQr(counter: _counter, service: _service);

  void _openQueueManagement() {
    Navigator.pushNamed(context, '/queue-management');
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
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    onPressed: () =>
                        Navigator.canPop(context) ? Navigator.pop(context) : null,
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'STUDENT QUEUE QR',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'COUNTER',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: Color(0xFF1E2B58),
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _counter,
                    decoration: _inputDecoration(),
                    items: _counters
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: _saving ? null : _onCounterChanged,
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'SERVICE OFFERED',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: Color(0xFF1E2B58),
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _service,
                    decoration: _inputDecoration(),
                    items: _services
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => setState(() => _service = v ?? _service),
                  ),
                  const SizedBox(height: 22),

                  // ─── QR CARD ───────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
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
                          'SCAN TO JOIN QUEUE',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: headerNavy,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFE5E7EB),
                              width: 1.2,
                            ),
                          ),
                          child: QrImageView(
                            data: _payload,
                            version: QrVersions.auto,
                            size: 220,
                            backgroundColor: Colors.white,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: Color(0xFF0F1E5C),
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: Color(0xFF0F1E5C),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '$_service • $_counter',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Students scan this code with their phone\nthen submit the request form.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: textGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _openQueueManagement,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.format_list_bulleted_rounded,
                          color: Colors.white, size: 20),
                      label: const Text(
                        'OPEN QUEUE MANAGEMENT',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFDDE2E8), width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: primaryBlue, width: 1.5),
      ),
    );
  }
}
