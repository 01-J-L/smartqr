import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'database.dart';

// Shared styling for every admin section.
const Color kSectionBg = Color(0xFFF4F6F9);
const Color kSectionNavy = Color(0xFF0F1E4A);
const Color kSectionBorder = Color(0xFFE5E7EB);
const Color kSectionMuted = Color(0xFF6B7280);
const Color kSectionBlue = Color(0xFF1E88E5);
const Color kSectionGreen = Color(0xFF16A34A);
const Color kSectionOrange = Color(0xFFEA580C);
const Color kSectionRed = Color(0xFFDC2626);

const List<String> kStatusFilters = [
  'ALL',
  'WAITING',
  'SERVING',
  'DONE',
  'CANCELLED',
];

Widget kSectionTitle(String text) => Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
        color: kSectionNavy,
      ),
    );

Widget kCard({required Widget child, EdgeInsetsGeometry? padding}) => Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kSectionBorder),
      ),
      child: child,
    );

InputDecoration kFieldDecoration({String? hint}) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13.5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kSectionBorder, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kSectionBlue, width: 1.5),
      ),
    );

Future<void> kConfirmDelete(
  BuildContext context,
  String message,
  VoidCallback onConfirm, {
  String actionLabel = 'Delete',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Please confirm'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(actionLabel, style: const TextStyle(color: kSectionRed)),
        ),
      ],
    ),
  );
  if (ok == true) onConfirm();
}

// ─────────────────────────────────────────────────────────────────
// 1. DASHBOARD OVERVIEW
// ─────────────────────────────────────────────────────────────────

class AdminOverviewSection extends StatefulWidget {
  const AdminOverviewSection({super.key});

  @override
  State<AdminOverviewSection> createState() => _AdminOverviewSectionState();
}

class _AdminOverviewSectionState extends State<AdminOverviewSection> {
  Map<String, int> _stats = {
    'waiting': 0,
    'serving': 0,
    'done': 0,
    'cancelled': 0,
    'total': 0,
  };
  Map<String, int> _serviceBreakdown = {};
  Map<String, int> _todayStats = {'total': 0};
  List<int> _trend = const [];
  List<String> _trendLabels = const [];
  bool _loading = true;

  static const List<int> _trendStarts = [7, 9, 11, 13, 15, 17];
  static const List<String> _labels = ['7AM', '9AM', '11AM', '1PM', '3PM', '5PM'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final stats = await DatabaseHelper.instance.getQueueStats();
    final today = await DatabaseHelper.instance.getTodayStats();
    final services = await DatabaseHelper.instance.getServiceBreakdown();
    final trend = await DatabaseHelper.instance.getHourlyTrend(
      starts: _trendStarts,
    );
    if (!mounted) return;
    setState(() {
      _stats = stats;
      _todayStats = today;
      _serviceBreakdown = services;
      _trend = trend;
      _trendLabels = _labels;
      _loading = false;
    });
  }

  String get _today {
    final now = DateTime.now();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dashboard Overview',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: kSectionNavy,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "Welcome back, Admin. Here is today's real-time queue performance.",
                      style: TextStyle(fontSize: 13, color: kSectionMuted),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kSectionBorder),
                  ),
                  child: Text(
                    _today,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF374151),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                _MetricCard(
                    "TODAY'S QUEUE", '${_todayStats['total'] ?? 0}', const Color(0xFF0284C7)),
                const SizedBox(width: 14),
                _MetricCard('WAITING', '${_stats['waiting'] ?? 0}', kSectionOrange),
                const SizedBox(width: 14),
                _MetricCard('SERVING', '${_stats['serving'] ?? 0}', kSectionGreen),
                const SizedBox(width: 14),
                _MetricCard('COMPLETED', '${_stats['done'] ?? 0}', const Color(0xFF0284C7)),
                const SizedBox(width: 14),
                _MetricCard('CANCELLED', '${_stats['cancelled'] ?? 0}', kSectionRed),
              ],
            ),
            const SizedBox(height: 24),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 6,
                  child: kCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        kSectionTitle('QUEUE TREND (TODAY)'),
                        const SizedBox(height: 8),
                        const Text(
                          'Tickets created per two-hour window',
                          style:
                              TextStyle(fontSize: 11.5, color: kSectionMuted),
                        ),
                        const SizedBox(height: 16),
                        if (_loading)
                          const SizedBox(
                            height: 200,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else ...[
                          if (_trend.every((v) => v == 0))
                            const SizedBox(
                              height: 200,
                              child: Center(
                                child: Text(
                                  'No tickets recorded today yet.',
                                  style: TextStyle(
                                      fontSize: 13, color: kSectionMuted),
                                ),
                              ),
                            )
                          else
                            SizedBox(
                              height: 200,
                              width: double.infinity,
                              child: QueueTrendChart(
                                values: _trend,
                                labels: _trendLabels,
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 3,
                  child: kCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        kSectionTitle('TOP SERVICES'),
                        const SizedBox(height: 20),
                        if (_serviceBreakdown.isEmpty)
                          const Text(
                            'No data yet',
                            style:
                                TextStyle(fontSize: 13, color: kSectionMuted),
                          )
                        else
                          ..._buildServiceList(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildServiceList() {
    final total = _serviceBreakdown.values.fold<int>(0, (a, b) => a + b);
    if (total == 0) return [];
    const colors = [
      Color(0xFF14205B),
      kSectionBlue,
      Color(0xFF22C55E),
      Color(0xFF5B67CA),
      kSectionOrange,
      kSectionRed,
    ];
    final widgets = <Widget>[];
    var i = 0;
    _serviceBreakdown.forEach((name, count) {
      final pct = ((count / total) * 100).round();
      if (i > 0) widgets.add(const SizedBox(height: 18));
      widgets.add(_ServiceProgress(
        name: name,
        count: count,
        percentage: pct,
        color: colors[i % colors.length],
      ));
      i++;
    });
    return widgets;
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(this.label, this.value, this.valueColor);

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kSectionBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: kSectionMuted,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: valueColor,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceProgress extends StatelessWidget {
  const _ServiceProgress({
    required this.name,
    required this.count,
    required this.percentage,
    required this.color,
  });

  final String name;
  final int count;
  final int percentage;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
            Text(
              '$count • $percentage%',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: kSectionMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: const Color(0xFFEFF2F6),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

class QueueTrendChart extends StatelessWidget {
  const QueueTrendChart({
    super.key,
    required this.values,
    required this.labels,
  });

  final List<int> values;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TrendChartPainter(values, labels),
      child: const SizedBox.expand(),
    );
  }
}

class _TrendChartPainter extends CustomPainter {
  _TrendChartPainter(this.values, this.labels);

  final List<int> values;
  final List<String> labels;

  @override
  void paint(Canvas canvas, Size size) {
    const bottomPadding = 24.0;
    const inset = 26.0;
    final chartHeight = size.height - bottomPadding;
    final plotWidth = size.width - (inset * 2);

    final gridPaint = Paint()
      ..color = const Color(0xFFF1F4F9)
      ..strokeWidth = 1.2;
    for (var i = 0; i <= 3; i++) {
      final y = (chartHeight / 3) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (values.isEmpty) return;

    final max = values.fold<int>(0, (a, b) => a > b ? a : b);
    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = inset + (i / (values.length - 1)) * plotWidth;
      final ratio = max == 0 ? 0.0 : values[i] / max;
      final y = chartHeight - 8 - (ratio * (chartHeight - 24));
      points.add(Offset(x, y));
    }

    final linePaint = Paint()
      ..color = const Color(0xFF007AFF)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()
      ..color = const Color(0xFF0E1E5C)
      ..style = PaintingStyle.fill;
    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(points[i], 4.0, dotPaint);

      // The count sits above each point so the chart is readable.
      final countPainter = TextPainter(
        text: TextSpan(
          text: '${values[i]}',
          style: const TextStyle(
            color: Color(0xFF0E1E5C),
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      countPainter.paint(
        canvas,
        Offset(points[i].dx - countPainter.width / 2, points[i].dy - 16),
      );

      if (i < labels.length) {
        final labelPainter = TextPainter(
          text: TextSpan(
            text: labels[i],
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        labelPainter.paint(
          canvas,
          Offset(points[i].dx - labelPainter.width / 2, chartHeight + 8),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.labels != labels;
}

// ─────────────────────────────────────────────────────────────────
// 2. SERVICES
// ─────────────────────────────────────────────────────────────────

class AdminServicesSection extends StatefulWidget {
  const AdminServicesSection({super.key});

  @override
  State<AdminServicesSection> createState() => _AdminServicesSectionState();
}

class _AdminServicesSectionState extends State<AdminServicesSection> {
  List<Map<String, dynamic>> _services = [];
  Map<String, int> _usage = {};
  final _controller = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final services = await DatabaseHelper.instance.getServices();
    final usage = await DatabaseHelper.instance.getServiceBreakdown();
    if (!mounted) return;
    setState(() {
      _services = services;
      _usage = usage;
      _loading = false;
    });
  }

  Future<void> _add() async {
    setState(() => _saving = true);
    final error = await DatabaseHelper.instance.addService(_controller.text);
    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    _controller.clear();
    _load();
  }

  Future<void> _remove(Map<String, dynamic> service) async {
    final name = service['name'] as String;
    kConfirmDelete(
      context,
      'Remove "$name" from the list of offered services?',
      () async {
        await DatabaseHelper.instance.deleteService(service['id'] as int);
        if (!mounted) return;
        _load();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Services',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: kSectionNavy,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Offered services drive the request form, staff QR codes and reports.',
              style: TextStyle(fontSize: 13, color: kSectionMuted),
            ),
            const SizedBox(height: 24),

            kCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  kSectionTitle('ADD A SERVICE'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          textCapitalization: TextCapitalization.sentences,
                          onSubmitted: (_) => _saving ? null : _add(),
                          decoration: kFieldDecoration(
                              hint: 'e.g. Scholarship Office'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _add,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kSectionBlue,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 22),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'ADD',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (_loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_services.isEmpty)
              kCard(
                child: Column(
                  children: const [
                    Icon(Icons.layers_outlined,
                        size: 40, color: Color(0xFF94A3B8)),
                    SizedBox(height: 10),
                    Text(
                      'No services yet. Add the first one above.',
                      style: TextStyle(fontSize: 13, color: kSectionMuted),
                    ),
                  ],
                ),
              )
            else
              kCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < _services.length; i++) ...[
                      if (i > 0) const Divider(height: 1, color: kSectionBorder),
                      _ServiceRow(
                        service: _services[i],
                        count: _usage[_services[i]['name'] as String] ?? 0,
                        onDelete: () => _remove(_services[i]),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({
    required this.service,
    required this.count,
    required this.onDelete,
  });

  final Map<String, dynamic> service;
  final int count;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFE1F0FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.layers_outlined,
                color: kSectionBlue, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              service['name'] as String,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
          Text(
            '$count tickets',
            style: const TextStyle(fontSize: 12.5, color: kSectionMuted),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline,
                color: kSectionRed, size: 20),
            tooltip: 'Remove service',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// 3. COUNTERS
// ─────────────────────────────────────────────────────────────────

class AdminCountersSection extends StatefulWidget {
  const AdminCountersSection({super.key});

  @override
  State<AdminCountersSection> createState() => _AdminCountersSectionState();
}

class _AdminCountersSectionState extends State<AdminCountersSection> {
  List<Map<String, dynamic>> _counters = [];
  List<Map<String, dynamic>> _active = [];
  List<Map<String, dynamic>> _staff = [];
  final _controller = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final counters = await DatabaseHelper.instance.getCounters();
    final active = await DatabaseHelper.instance.getActiveQueue();
    final staff = await DatabaseHelper.instance.getStaffUsers();
    if (!mounted) return;
    setState(() {
      _counters = counters;
      _active = active;
      _staff = staff;
      _loading = false;
    });
  }

  Future<void> _add() async {
    setState(() => _saving = true);
    final error = await DatabaseHelper.instance.addCounter(_controller.text);
    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    _controller.clear();
    _load();
  }

  Future<void> _remove(Map<String, dynamic> counter) async {
    final name = counter['name'] as String;
    kConfirmDelete(
      context,
      'Remove "$name"? Staff assigned to it will fall back to the first counter.',
      () async {
        await DatabaseHelper.instance.deleteCounter(counter['id'] as int);
        if (!mounted) return;
        _load();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Counters',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: kSectionNavy,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Service windows students are routed to when they scan a counter QR.',
              style: TextStyle(fontSize: 13, color: kSectionMuted),
            ),
            const SizedBox(height: 24),

            kCard(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _saving ? null : _add(),
                      decoration: kFieldDecoration(hint: 'e.g. Counter 4'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _add,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kSectionBlue,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'ADD',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (_loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_counters.isEmpty)
              kCard(
                child: Column(
                  children: const [
                    Icon(Icons.computer_rounded,
                        size: 40, color: Color(0xFF94A3B8)),
                    SizedBox(height: 10),
                    Text(
                      'No counters yet. Add the first one above.',
                      style: TextStyle(fontSize: 13, color: kSectionMuted),
                    ),
                  ],
                ),
              )
            else
              GridView.count(
                crossAxisCount:
                    MediaQuery.of(context).size.width > 1100 ? 3 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 2.1,
                children: [
                  for (final counter in _counters)
                    _CounterCard(
                      counter: counter,
                      active: _active,
                      staff: _staff,
                      onDelete: () => _remove(counter),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _CounterCard extends StatelessWidget {
  const _CounterCard({
    required this.counter,
    required this.active,
    required this.staff,
    required this.onDelete,
  });

  final Map<String, dynamic> counter;
  final List<Map<String, dynamic>> active;
  final List<Map<String, dynamic>> staff;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final name = counter['name'] as String;
    final serving = active
        .where((q) => q['status'] == 'SERVING' && q['counter'] == name)
        .toList();
    final waiting =
        active.where((q) => q['status'] == 'WAITING' && q['counter'] == name);
    final assigned =
        staff.where((s) => (s['counter'] ?? '') == name).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kSectionBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.computer_rounded,
                    color: kSectionGreen, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: kSectionNavy,
                  ),
                ),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline,
                    color: kSectionRed, size: 19),
                tooltip: 'Remove counter',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            serving.isEmpty
                ? 'Now serving: —'
                : 'Now serving: ${serving.first['queue_no']}',
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 3),
          Text(
            '${waiting.length} waiting in line',
            style: const TextStyle(fontSize: 12.5, color: kSectionMuted),
          ),
          const SizedBox(height: 3),
          Text(
            assigned.isEmpty
                ? 'No staff assigned'
                : 'Staff: ${assigned.map((s) => s['full_name']).join(', ')}',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, color: kSectionMuted),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// 4. STAFF
// ─────────────────────────────────────────────────────────────────

class AdminStaffSection extends StatefulWidget {
  const AdminStaffSection({super.key});

  @override
  State<AdminStaffSection> createState() => _AdminStaffSectionState();
}

class _AdminStaffSectionState extends State<AdminStaffSection> {
  List<Map<String, dynamic>> _staff = [];
  List<String> _counters = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final staff = await DatabaseHelper.instance.getStaffUsers();
    final counters = await DatabaseHelper.instance.getCounters();
    if (!mounted) return;
    setState(() {
      _staff = staff;
      _counters = counters.map((c) => c['name'] as String).toList();
      _loading = false;
    });
  }

  Future<void> _assign(Map<String, dynamic> user, String? counter) async {
    await DatabaseHelper.instance.assignCounter(user['id'] as int, counter);
    // Keep the signed-in staff member's own session in sync.
    if (Session.user != null && Session.user!['id'] == user['id']) {
      Session.user!['counter'] = counter;
    }
    if (!mounted) return;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Staff',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: kSectionNavy,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Assign the service window each staff or admin account works at.',
              style: TextStyle(fontSize: 13, color: kSectionMuted),
            ),
            const SizedBox(height: 24),

            if (_loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_staff.isEmpty)
              kCard(
                child: Column(
                  children: const [
                    Icon(Icons.people_outline_rounded,
                        size: 40, color: Color(0xFF94A3B8)),
                    SizedBox(height: 10),
                    Text(
                      'No staff accounts yet.',
                      style: TextStyle(fontSize: 13, color: kSectionMuted),
                    ),
                  ],
                ),
              )
            else
              kCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < _staff.length; i++) ...[
                      if (i > 0) const Divider(height: 1, color: kSectionBorder),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: const Color(0xFF1B267E),
                              child: Text(
                                _initials(_staff[i]['full_name'] as String? ?? ''),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _staff[i]['full_name'] as String,
                                    style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_staff[i]['student_id']} • ${(_staff[i]['role'] as String).toUpperCase()}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: kSectionMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            SizedBox(
                              width: 170,
                              child: DropdownButtonFormField<String>(
                                initialValue: _staff[i]['counter'] as String?,
                                isExpanded: true,
                                hint: const Text('Unassigned'),
                                items: [
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text('Unassigned'),
                                  ),
                                  for (final c in _counters)
                                    DropdownMenuItem(
                                      value: c,
                                      child: Text(c),
                                    ),
                                ],
                                onChanged: (v) => _assign(_staff[i], v),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts.first.isNotEmpty && parts.last.isNotEmpty) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

// ─────────────────────────────────────────────────────────────────
// 5. MANAGE USERS
// ─────────────────────────────────────────────────────────────────

class AdminUsersSection extends StatefulWidget {
  const AdminUsersSection({super.key});

  @override
  State<AdminUsersSection> createState() => _AdminUsersSectionState();
}

class _AdminUsersSectionState extends State<AdminUsersSection> {
  List<Map<String, dynamic>> _users = [];
  List<String> _counters = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final users = await DatabaseHelper.instance.getAllUsers();
    final counters = await DatabaseHelper.instance.getCounters();
    if (!mounted) return;
    setState(() {
      _users = users;
      _counters = counters.map((c) => c['name'] as String).toList();
      _loading = false;
    });
  }

  void _flash(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _remove(Map<String, dynamic> user) async {
    final name = user['full_name'] as String? ?? 'this account';
    await kConfirmDelete(
      context,
      'Delete $name? They will no longer be able to sign in.',
      () async {
        final error =
            await DatabaseHelper.instance.adminDeleteUser(user['id'] as int);
        if (error != null) return _flash(error);
        _flash('Deleted $name.');
        _load();
      },
      actionLabel: 'Delete account',
    );
  }

  Future<void> _showForm({Map<String, dynamic>? existing}) async {
    final editing = existing != null;
    final studentId = TextEditingController(
        text: existing?['student_id'] as String? ?? '');
    final fullName =
        TextEditingController(text: existing?['full_name'] as String? ?? '');
    final email =
        TextEditingController(text: existing?['email'] as String? ?? '');
    final contact =
        TextEditingController(text: existing?['contact'] as String? ?? '');
    final password = TextEditingController();
    var role = (existing?['role'] as String?) ?? 'student';
    var counter = existing?['counter'] as String?;

    String? error;
    var saving = false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> submit() async {
            String? problem;
            if (!editing && studentId.text.trim().isEmpty) {
              problem = 'Student ID cannot be empty.';
            } else if (fullName.text.trim().isEmpty) {
              problem = 'Full name cannot be empty.';
            } else if (!editing && password.text.length < 6) {
              problem = 'Password must be at least 6 characters.';
            } else if (editing &&
                password.text.isNotEmpty &&
                password.text.length < 6) {
              problem = 'Password must be at least 6 characters.';
            }
            if (problem != null) {
              setDialogState(() => error = problem);
              return;
            }

            setDialogState(() => saving = true);
            final result = editing
                ? await DatabaseHelper.instance.adminUpdateUser(
                    userId: existing['id'] as int,
                    fullName: fullName.text.trim(),
                    email: email.text.trim(),
                    contact: contact.text.trim(),
                    role: role,
                    counter: counter,
                    newPassword: password.text,
                  )
                : await DatabaseHelper.instance.adminCreateUser(
                    studentId: studentId.text.trim(),
                    fullName: fullName.text.trim(),
                    email: email.text.trim(),
                    contact: contact.text.trim(),
                    password: password.text,
                    role: role,
                    counter: counter,
                  );
            if (!dialogContext.mounted) return;
            if (result != null) {
              setDialogState(() {
                error = result;
                saving = false;
              });
              return;
            }
            Navigator.pop(dialogContext, true);
          }

          return AlertDialog(
            title: Text(editing ? 'Edit account' : 'Add account'),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: studentId,
                      enabled: !editing,
                      textCapitalization: TextCapitalization.characters,
                      decoration: kFieldDecoration(hint: 'Student ID'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: fullName,
                      decoration: kFieldDecoration(hint: 'Full name'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: email,
                      decoration: kFieldDecoration(hint: 'Email address'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: contact,
                      decoration: kFieldDecoration(hint: 'Contact number'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: role,
                      decoration: kFieldDecoration(hint: 'Role'),
                      items: [
                        for (final r in DatabaseHelper.roles)
                          DropdownMenuItem(
                            value: r,
                            child: Text(r.toUpperCase()),
                          ),
                      ],
                      onChanged: (v) =>
                          setDialogState(() => role = v ?? 'student'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: counter,
                      decoration: kFieldDecoration(hint: 'Counter'),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Unassigned'),
                        ),
                        for (final c in _counters)
                          DropdownMenuItem(value: c, child: Text(c)),
                      ],
                      onChanged: (v) => setDialogState(() => counter = v),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: password,
                      obscureText: true,
                      decoration: kFieldDecoration(
                        hint: editing
                            ? 'New password (leave blank to keep)'
                            : 'Password (min 6 characters)',
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        error!,
                        style: const TextStyle(
                          color: kSectionRed,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: saving ? null : submit,
                child: Text(
                  editing ? 'Save changes' : 'Create account',
                  style: const TextStyle(
                    color: kSectionBlue,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    studentId.dispose();
    fullName.dispose();
    email.dispose();
    contact.dispose();
    password.dispose();

    if (saved == true) {
      _flash(editing ? 'Account updated.' : 'Account created.');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Manage Users',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: kSectionNavy,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Create, edit and remove student, staff and admin accounts.',
                        style: TextStyle(fontSize: 13, color: kSectionMuted),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: () => _showForm(),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                    label: const Text('ADD ACCOUNT'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kSectionBlue,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            if (_loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_users.isEmpty)
              kCard(
                child: Column(
                  children: const [
                    Icon(Icons.manage_accounts_outlined,
                        size: 40, color: Color(0xFF94A3B8)),
                    SizedBox(height: 10),
                    Text(
                      'No accounts yet. Add the first one above.',
                      style: TextStyle(fontSize: 13, color: kSectionMuted),
                    ),
                  ],
                ),
              )
            else
              kCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < _users.length; i++) ...[
                      if (i > 0) const Divider(height: 1, color: kSectionBorder),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: const Color(0xFF1B267E),
                              child: Text(
                                _initials(
                                    _users[i]['full_name'] as String? ?? ''),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _users[i]['full_name'] as String? ?? '',
                                    style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_users[i]['student_id']} • '
                                    '${(_users[i]['role'] as String? ?? 'student').toUpperCase()}'
                                    '${_users[i]['counter'] == null ? '' : ' • ${_users[i]['counter']}'}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: kSectionMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => _showForm(existing: _users[i]),
                              icon: const Icon(Icons.edit_outlined,
                                  color: kSectionBlue, size: 20),
                              tooltip: 'Edit account',
                            ),
                            IconButton(
                              onPressed: () => _remove(_users[i]),
                              icon: const Icon(Icons.delete_outline,
                                  color: kSectionRed, size: 20),
                              tooltip: 'Delete account',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts.first.isNotEmpty && parts.last.isNotEmpty) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

// ─────────────────────────────────────────────────────────────────
// 6. QUEUE HISTORY
// ─────────────────────────────────────────────────────────────────

class AdminHistorySection extends StatefulWidget {
  const AdminHistorySection({super.key});

  @override
  State<AdminHistorySection> createState() => _AdminHistorySectionState();
}

class _AdminHistorySectionState extends State<AdminHistorySection> {
  List<Map<String, dynamic>> _rows = [];
  String _filter = 'ALL';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await DatabaseHelper.instance.getQueueHistory(
      status: _filter == 'ALL' ? null : _filter,
    );
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  Future<void> _setFilter(String filter) async {
    setState(() {
      _filter = filter;
      _loading = true;
    });
    await _load();
  }

  Future<void> _cancel(Map<String, dynamic> row) async {
    kConfirmDelete(
      context,
      'Cancel ticket ${row['queue_no']}?',
      () async {
        await DatabaseHelper.instance.cancelTicket(row['id'] as int);
        if (!mounted) return;
        _load();
      },
      actionLabel: 'Cancel ticket',
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Queue History',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: kSectionNavy,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Every ticket ever created, filterable by status.',
              style: TextStyle(fontSize: 13, color: kSectionMuted),
            ),
            const SizedBox(height: 20),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final filter in kStatusFilters)
                  ChoiceChip(
                    label: Text(filter),
                    selected: _filter == filter,
                    selectedColor: kSectionNavy,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _filter == filter ? Colors.white : kSectionNavy,
                    ),
                    onSelected: (_) => _setFilter(filter),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            if (_loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_rows.isEmpty)
              kCard(
                child: Column(
                  children: const [
                    Icon(Icons.access_time_rounded,
                        size: 40, color: Color(0xFF94A3B8)),
                    SizedBox(height: 10),
                    Text(
                      'No tickets match this filter.',
                      style: TextStyle(fontSize: 13, color: kSectionMuted),
                    ),
                  ],
                ),
              )
            else
              kCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < _rows.length; i++) ...[
                      if (i > 0) const Divider(height: 1, color: kSectionBorder),
                      _HistoryRow(
                        row: _rows[i],
                        onCancel: () => _cancel(_rows[i]),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.row, required this.onCancel});

  final Map<String, dynamic> row;
  final VoidCallback onCancel;

  Color get _statusColor {
    switch (row['status']) {
      case 'DONE':
        return kSectionGreen;
      case 'SERVING':
        return kSectionBlue;
      case 'CANCELLED':
        return kSectionRed;
      default:
        return kSectionOrange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = row['status'] as String;
    final canCancel = status == 'WAITING' || status == 'SERVING';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              row['queue_no'] as String,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: kSectionNavy,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row['student_name'] as String,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${row['service']} • ${row['time']}'
                  '${row['counter'] != null ? ' • ${row['counter']}' : ''}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: kSectionMuted),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: _statusColor,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (canCancel)
            IconButton(
              onPressed: onCancel,
              icon: const Icon(Icons.cancel_outlined,
                  color: kSectionRed, size: 20),
              tooltip: 'Cancel ticket',
            )
          else
            const SizedBox(width: 36),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// 7. REPORTS
// ─────────────────────────────────────────────────────────────────

class AdminReportsSection extends StatefulWidget {
  const AdminReportsSection({super.key});

  @override
  State<AdminReportsSection> createState() => _AdminReportsSectionState();
}

class _AdminReportsSectionState extends State<AdminReportsSection> {
  Map<String, int> _stats = {'waiting': 0, 'serving': 0, 'done': 0, 'cancelled': 0, 'total': 0};
  Map<String, int> _services = {};
  List<Map<String, dynamic>> _daily = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final stats = await DatabaseHelper.instance.getQueueStats();
    final services = await DatabaseHelper.instance.getServiceBreakdown();
    final daily = await DatabaseHelper.instance.getDailyCounts(7);
    if (!mounted) return;
    setState(() {
      _stats = stats;
      _services = services;
      _daily = daily;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final total = _stats['total'] ?? 0;
    final done = _stats['done'] ?? 0;
    final cancelled = _stats['cancelled'] ?? 0;
    final finished = done + cancelled;
    final completionRate =
        finished == 0 ? 0 : ((done / finished) * 100).round();
    final peak =
        _daily.map((d) => d['count'] as int).fold<int>(0, (a, b) => a > b ? a : b);

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reports',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: kSectionNavy,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Queue volume, completion rate and service distribution.',
              style: TextStyle(fontSize: 13, color: kSectionMuted),
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: _ReportTile('TOTAL TICKETS', '$total', kSectionNavy),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _ReportTile('COMPLETED', '$done', kSectionGreen),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _ReportTile('CANCELLED', '$cancelled', kSectionRed),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child:
                      _ReportTile('COMPLETION RATE', '$completionRate%', kSectionBlue),
                ),
              ],
            ),
            const SizedBox(height: 24),

            kCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  kSectionTitle('LAST 7 DAYS'),
                  const SizedBox(height: 18),
                  if (_daily.every((d) => d['count'] == 0))
                    const Text(
                      'No tickets were created in the past week.',
                      style: TextStyle(fontSize: 13, color: kSectionMuted),
                    )
                  else
                    for (final day in _daily)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 64,
                              child: Text(
                                day['label'] as String,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: kSectionMuted,
                                ),
                              ),
                            ),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: peak == 0
                                      ? 0
                                      : (day['count'] as int) / peak,
                                  minHeight: 10,
                                  backgroundColor: const Color(0xFFEFF2F6),
                                  valueColor: const AlwaysStoppedAnimation(
                                      kSectionBlue),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 32,
                              child: Text(
                                '${day['count']}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1E293B),
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

            kCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  kSectionTitle('SERVICE DISTRIBUTION'),
                  const SizedBox(height: 18),
                  if (_services.isEmpty)
                    const Text(
                      'No tickets recorded yet.',
                      style: TextStyle(fontSize: 13, color: kSectionMuted),
                    )
                  else
                    for (final entry in _services.entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                entry.key,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                            Text(
                              '${entry.value}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: kSectionNavy,
                              ),
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile(this.label, this.value, this.color);

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kSectionBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: kSectionMuted,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// 8. SETTINGS
// ─────────────────────────────────────────────────────────────────

class AdminSettingsSection extends StatefulWidget {
  const AdminSettingsSection({super.key});

  @override
  State<AdminSettingsSection> createState() => _AdminSettingsSectionState();
}

class _AdminSettingsSectionState extends State<AdminSettingsSection> {
  bool _busy = false;

  Future<void> _clearHistory() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear completed history?'),
        content: const Text(
          'All DONE and CANCELLED tickets are permanently deleted. '
          'Waiting and serving tickets are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Clear', style: TextStyle(color: kSectionRed)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    final removed = await DatabaseHelper.instance.clearCompletedHistory();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$removed ticket(s) removed from history.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Session.user ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Settings',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: kSectionNavy,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Account details and database maintenance.',
            style: TextStyle(fontSize: 13, color: kSectionMuted),
          ),
          const SizedBox(height: 24),

          kCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                kSectionTitle('SIGNED-IN ACCOUNT'),
                const SizedBox(height: 16),
                _InfoRow('Name', (user['full_name'] ?? '') as String),
                _InfoRow('Account ID', (user['student_id'] ?? '') as String),
                _InfoRow('Email', (user['email'] ?? '') as String),
                _InfoRow('Contact', (user['contact'] ?? '') as String),
                _InfoRow('Role', Session.role.toUpperCase()),
                _InfoRow('Assigned counter', Session.counter),
              ],
            ),
          ),
          const SizedBox(height: 20),

          kCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                kSectionTitle('DATABASE'),
                const SizedBox(height: 16),
                _InfoRow('Schema version', '${DatabaseHelper.schemaVersion}'),
                _InfoRow(
                  'Storage',
                  kIsWeb ? 'Browser (IndexedDB)' : 'Local app database',
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Delete every completed or cancelled ticket. '
                        'This cannot be undone.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: kSectionMuted,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      height: 44,
                      child: OutlinedButton(
                        onPressed: _busy ? null : _clearHistory,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: kSectionRed),
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text(
                                'Clear history',
                                style: TextStyle(
                                  color: kSectionRed,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: kSectionMuted),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
