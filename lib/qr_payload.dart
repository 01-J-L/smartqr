/// Payload carried by the staff QR code and read by the student scanner.
///
/// Wire format: `SMARTQR|<counter>|<service>`
const String kQueueQrPrefix = 'SMARTQR';

/// Services a student can request (shared by the request form and staff QR).
///
/// This is only the reference data a brand new database is created with; every
/// screen reads the live `services` table through DatabaseHelper instead.
const List<String> kServiceList = [
  'Registrar',
  'Cashier / Accounting',
  'Dean\'s Office',
  'Guidance Office',
  'Clinic',
];

/// Counters a staff member can work at. Same contract as [kServiceList].
const List<String> kCounterList = [
  'Counter 1',
  'Counter 2',
  'Counter 3',
];

class QueueQrPayload {
  const QueueQrPayload({required this.counter, required this.service});

  final String counter;
  final String service;
}

String encodeQueueQr({required String counter, required String service}) =>
    '$kQueueQrPrefix|$counter|$service';

QueueQrPayload? decodeQueueQr(String? raw) {
  if (raw == null) return null;
  final parts = raw.trim().split('|');
  if (parts.length < 3) return null;
  if (parts.first.trim().toUpperCase() != kQueueQrPrefix) return null;

  final counter = parts[1].trim();
  final service = parts.sublist(2).join('|').trim();
  if (counter.isEmpty || service.isEmpty) return null;

  return QueueQrPayload(counter: counter, service: service);
}
