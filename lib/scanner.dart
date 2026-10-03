import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'database.dart';
import 'qr_payload.dart';

class ScanQrScreen extends StatefulWidget {
  const ScanQrScreen({super.key});

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen> {
  // Color Palette
  static const Color darkNavyBg = Color(0xFF0B1536);
  static const Color scannerInnerBg = Color(0xFF070E26);
  static const Color frameGreen = Color(0xFF22C55E);
  static const Color primaryBlue = Color(0xFF1E88E5);
  static const Color subTextGrey = Color(0xFF7E8EA8);

  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final payload = decodeQueueQr(barcode.rawValue);
      if (payload != null) {
        _proceed(payload);
        return;
      }
    }
  }

  void _proceed(QueueQrPayload payload) {
    if (_handled || !mounted) return;
    _handled = true;
    _controller.stop();
    Navigator.pushReplacementNamed(context, '/request', arguments: payload);
  }

  /// Fallback for devices without a camera (or denied permission):
  /// the student picks counter + service instead of scanning.
  Future<void> _manualEntry() async {
    // Live lists from the database, falling back to the reference data.
    var counters = kCounterList.toList();
    var services = kServiceList.toList();
    try {
      final counterRows = await DatabaseHelper.instance.getCounters();
      final serviceRows = await DatabaseHelper.instance.getServices();
      if (counterRows.isNotEmpty) {
        counters = counterRows.map((r) => r['name'] as String).toList();
      }
      if (serviceRows.isNotEmpty) {
        services = serviceRows.map((r) => r['name'] as String).toList();
      }
    } catch (_) {
      // Reference data could not be read; the constants above still work.
    }
    if (!mounted) return;

    String counter = counters.first;
    String service = services.contains(kServiceList.first)
        ? kServiceList.first
        : services.first;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Join a counter'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'COUNTER',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: counter,
                    items: counters
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) =>
                        setDialogState(() => counter = v ?? counter),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'SERVICE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: service,
                    items: services
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) =>
                        setDialogState(() => service = v ?? service),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('CONTINUE'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true) {
      _proceed(QueueQrPayload(counter: counter, service: service));
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final scannerSize = screenSize.width * 0.72;

    return Scaffold(
      backgroundColor: darkNavyBg,
      body: SafeArea(
        child: Column(
          children: [
            // ─── TOP APP BAR ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () => Navigator.canPop(context) ? Navigator.pop(context) : null,
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Scan Service QR Code',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            const Spacer(flex: 1),

            // ─── QR SCANNER FRAME ─────────────────────────────────
            Column(
              children: [
                Container(
                  width: scannerSize,
                  height: scannerSize,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: scannerInnerBg,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: frameGreen,
                      width: 2.8,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        MobileScanner(
                          controller: _controller,
                          onDetect: _onDetect,
                          placeholderBuilder: (context) => const ColoredBox(
                            color: scannerInnerBg,
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: frameGreen,
                              ),
                            ),
                          ),
                          errorBuilder: (context, error) {
                            final permissionDenied = error.errorCode ==
                                MobileScannerErrorCode.permissionDenied;
                            return ColoredBox(
                              color: scannerInnerBg,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      permissionDenied
                                          ? Icons.no_photography_rounded
                                          : Icons.videocam_off_rounded,
                                      size: 44,
                                      color: subTextGrey,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      permissionDenied
                                          ? 'Camera access is blocked.'
                                          : 'Camera is unavailable on this device.',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Color(0xFFD1D5DB),
                                        fontSize: 12.5,
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    TextButton.icon(
                                      onPressed: _manualEntry,
                                      icon: const Icon(Icons.touch_app_rounded,
                                          size: 18, color: frameGreen),
                                      label: const Text(
                                        'Choose counter manually',
                                        style: TextStyle(
                                          color: frameGreen,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                        // Corner brackets
                        const IgnorePointer(
                          child: Center(
                            child: Icon(
                              Icons.qr_code_2_rounded,
                              size: 96,
                              color: Color(0x33FFFFFF),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Pill Helper Label
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF060B1E),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Align the staff QR code within the frame',
                    style: TextStyle(
                      color: Color(0xFFD1D5DB),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),

            const Spacer(flex: 2),

            // ─── BOTTOM DESCRIPTION & BUTTONS ─────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: Column(
                children: [
                  const Text(
                    'Scan the QR code shown on the staff screen\nto pick your counter and join the queue.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: subTextGrey,
                      fontSize: 13.5,
                      height: 1.45,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _manualEntry,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'CHOOSE COUNTER MANUALLY',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
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
                      onPressed: () => Navigator.pushNamed(context, '/request'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF3E4C7A), width: 1.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'JOIN QUEUE WITHOUT QR',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
