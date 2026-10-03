import 'package:flutter/material.dart';

import 'database.dart';
import 'qr_payload.dart';

class RequestServiceScreen extends StatefulWidget {
  const RequestServiceScreen({super.key});

  @override
  State<RequestServiceScreen> createState() => _RequestServiceScreenState();
}

class _RequestServiceScreenState extends State<RequestServiceScreen> {
  // Controllers
  late final TextEditingController _studentIdController;
  late final TextEditingController _fullNameController;
  late final TextEditingController _contactController;
  late final TextEditingController _timeController;
  final _purposeController = TextEditingController();
  bool _loading = false;
  bool _argsRead = false;

  // Counter/service picked up from the scanned staff QR code
  String? _counter;
  QueueQrPayload? _payload;

  // Dropdown value
  String _selectedService = kServiceList.first;
  final List<String> _services = List<String>.of(kServiceList);

  // Design Colors
  static const Color headerNavy = Color(0xFF0F1A44);
  static const Color primaryBlue = Color(0xFF1E88E5);
  static const Color labelNavy = Color(0xFF1E2B58);
  static const Color borderColor = Color(0xFFDDE2E8);

  @override
  void initState() {
    super.initState();
    _studentIdController = TextEditingController(text: Session.studentId);
    _fullNameController = TextEditingController(text: Session.fullName);
    _contactController =
        TextEditingController(text: Session.user?['contact'] ?? '');
    _timeController = TextEditingController(text: _currentTime());
    _loadServices();
  }

  /// The service dropdown lists whatever the admin currently offers.
  Future<void> _loadServices() async {
    try {
      final rows = await DatabaseHelper.instance.getServices();
      if (rows.isNotEmpty) {
        _services
          ..clear()
          ..addAll(rows.map((r) => r['name'] as String));
      }
    } catch (_) {
      // Fall back to the reference list already in the field.
    }
    _applyPayload();
    if (mounted) setState(() {});
  }

  void _applyPayload() {
    final payload = _payload;
    if (payload == null) return;
    _counter = payload.counter;
    _selectedService = payload.service;
    if (!_services.contains(payload.service)) {
      _services.insert(0, payload.service);
    }
  }

  String _currentTime() {
    final now = TimeOfDay.now();
    final h = now.hourOfPeriod == 0 ? 12 : now.hourOfPeriod;
    final m = now.minute.toString().padLeft(2, '0');
    final period = now.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsRead) return;
    _argsRead = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is QueueQrPayload) _payload = args;
    _applyPayload();
  }

  @override
  void dispose() {
    _studentIdController.dispose();
    _fullNameController.dispose();
    _contactController.dispose();
    _timeController.dispose();
    _purposeController.dispose();
    super.dispose();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _joinQueue() async {
    final purpose = _purposeController.text.trim();
    if (purpose.isEmpty) {
      _snack('Please enter your purpose / reason.');
      return;
    }

    setState(() => _loading = true);
    String? error;
    Map<String, dynamic>? existing;
    try {
      existing = await DatabaseHelper.instance
          .getLastTicketForStudent(Session.studentId);
      if (existing != null) {
        error = 'You already have an active ticket #${existing['queue_no']}. '
            'Please wait to be called.';
      } else {
        await DatabaseHelper.instance.joinQueue(
          studentId: Session.studentId,
          studentName: _fullNameController.text.trim(),
          service: _selectedService,
          time: _timeController.text.trim(),
          purpose: purpose,
          counter: _counter,
        );
      }
    } catch (e) {
      error = 'Could not join the queue: $e';
    }

    if (!mounted) return;
    setState(() => _loading = false);

    if (error != null) {
      _snack(error);
      return;
    }

    Navigator.pushReplacementNamed(context, '/confirmation');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // ─── TOP HEADER / APP BAR ─────────────────────────────
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
                          'REQUEST SERVICE',
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
          ),

          // ─── FORM FIELDS ──────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Student ID
                  _buildInputField(
                    label: 'STUDENT ID (PRE-FILLED)',
                    controller: _studentIdController,
                    readOnly: true,
                  ),
                  const SizedBox(height: 16),

                  // 2. Full Name
                  _buildInputField(
                    label: 'FULL NAME',
                    controller: _fullNameController,
                  ),
                  const SizedBox(height: 16),

                  // 3. Contact Number
                  _buildInputField(
                    label: 'CONTACT NUMBER',
                    controller: _contactController,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),

                  // 4. Service Needed (Dropdown)
                  _buildLabel('SERVICE NEEDED'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedService,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF4B5563)),
                    style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
                    decoration: _inputDecoration(),
                    items: _services.map((service) {
                      return DropdownMenuItem(
                        value: service,
                        child: Text(service),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedService = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // 5. Preferred Time
                  _buildInputField(
                    label: 'PREFERRED TIME',
                    controller: _timeController,
                  ),
                  const SizedBox(height: 16),

                  // 6. Purpose / Reason
                  _buildInputField(
                    label: 'PURPOSE / REASON',
                    controller: _purposeController,
                  ),
                  const SizedBox(height: 36),

                  // ─── JOIN QUEUE BUTTON ─────────────────────────
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _joinQueue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'JOIN QUEUE',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Label Helper
  Widget _buildLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: labelNavy,
        letterSpacing: 0.5,
      ),
    );
  }

  // Input Field Helper
  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    bool readOnly = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          readOnly: readOnly,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
          decoration: _inputDecoration(),
        ),
      ],
    );
  }

  // Consistent Input Border Decoration
  InputDecoration _inputDecoration() {
    return InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: borderColor, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: primaryBlue, width: 1.5),
      ),
    );
  }
}
