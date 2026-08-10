import 'expense.dart' show parseAmount;

/// Tipo de recordatorio de factura. Solo etiqueta + ícono; no cambia el
/// comportamiento (spec 16).
enum ReminderKind { service, card, debt }

ReminderKind _parseKind(String raw) {
  switch (raw) {
    case 'service':
      return ReminderKind.service;
    case 'card':
      return ReminderKind.card;
    case 'debt':
      return ReminderKind.debt;
    default:
      throw FormatException('kind inválido: $raw');
  }
}

String kindToApi(ReminderKind kind) {
  switch (kind) {
    case ReminderKind.service:
      return 'service';
    case ReminderKind.card:
      return 'card';
    case ReminderKind.debt:
      return 'debt';
  }
}

/// Etiqueta en español del tipo (solo visual).
String kindLabel(ReminderKind kind) {
  switch (kind) {
    case ReminderKind.service:
      return 'Servicio';
    case ReminderKind.card:
      return 'Tarjeta';
    case ReminderKind.debt:
      return 'Deuda';
  }
}

/// Ciclo `YYYY-MM` de un año/mes dados (formato de `paid_cycle`).
String cycleOf(int year, int month) =>
    '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';

/// Recordatorio de factura a pagar (spec 16). Fuente de verdad en Supabase; la
/// notificación local es un reflejo device-local que se re-programa al abrir la
/// app. El botón PAGO crea un `expense` normal con `name`/`amount`/`categoryId`.
class BillReminder {
  const BillReminder({
    required this.id,
    required this.name,
    required this.kind,
    required this.amount,
    required this.categoryId,
    required this.startDay,
    required this.dueDay,
    required this.notifyHour,
    required this.notifyMinute,
    required this.persistent,
    required this.repeatMonthly,
    required this.paidCycle,
    required this.active,
  });

  final String id, name, categoryId;
  final ReminderKind kind;
  final double amount;
  final int startDay, dueDay, notifyHour, notifyMinute;
  final bool persistent, repeatMonthly, active;
  final String? paidCycle; // 'YYYY-MM' o null

  /// ¿Ya se pagó en el ciclo dado (`YYYY-MM`)?
  bool isPaidForCycle(String cycle) => paidCycle == cycle;

  /// Fecha concreta de inicio para un año/mes dados. Si `startDay` no existe en
  /// el mes (ej. 31 en febrero), se hace clamp al último día del mes.
  DateTime startDateFor(int year, int month) {
    final lastDay = DateTime(year, month + 1, 0).day;
    final day = startDay > lastDay ? lastDay : startDay;
    return DateTime(year, month, day, notifyHour, notifyMinute);
  }

  /// Id estable de la notificación derivado del `id` (UUID). `flutter_local_
  /// notifications` usa un int de 32 bits; se toma el hash acotado a positivo.
  int get notificationId => id.hashCode & 0x7fffffff;

  /// Mapeo desde una fila de Postgres (snake_case). `amount` (numeric) puede
  /// venir como `num` o `String` — se parsea de forma defensiva.
  factory BillReminder.fromJson(Map<String, dynamic> json) => BillReminder(
    id: json['id'] as String,
    name: json['name'] as String,
    kind: _parseKind(json['kind'] as String),
    amount: parseAmount(json['amount']),
    categoryId: json['category_id'] as String,
    startDay: (json['start_day'] as num).toInt(),
    dueDay: (json['due_day'] as num).toInt(),
    notifyHour: (json['notify_hour'] as num).toInt(),
    notifyMinute: (json['notify_minute'] as num).toInt(),
    persistent: json['persistent'] as bool,
    repeatMonthly: json['repeat_monthly'] as bool,
    paidCycle: json['paid_cycle'] as String?,
    active: json['active'] as bool,
  );

  Map<String, dynamic> toCreateJson() => {
    'name': name,
    'kind': kindToApi(kind),
    'amount': amount,
    'category_id': categoryId,
    'start_day': startDay,
    'due_day': dueDay,
    'notify_hour': notifyHour,
    'notify_minute': notifyMinute,
    'persistent': persistent,
    'repeat_monthly': repeatMonthly,
  };

  Map<String, dynamic> toUpdateJson() => {
    'name': name,
    'kind': kindToApi(kind),
    'amount': amount,
    'category_id': categoryId,
    'start_day': startDay,
    'due_day': dueDay,
    'notify_hour': notifyHour,
    'notify_minute': notifyMinute,
    'persistent': persistent,
    'repeat_monthly': repeatMonthly,
    'updated_at': DateTime.now().toIso8601String(),
  };

  BillReminder copyWith({
    String? name,
    ReminderKind? kind,
    double? amount,
    String? categoryId,
    int? startDay,
    int? dueDay,
    int? notifyHour,
    int? notifyMinute,
    bool? persistent,
    bool? repeatMonthly,
    String? paidCycle,
    bool? active,
  }) => BillReminder(
    id: id,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    amount: amount ?? this.amount,
    categoryId: categoryId ?? this.categoryId,
    startDay: startDay ?? this.startDay,
    dueDay: dueDay ?? this.dueDay,
    notifyHour: notifyHour ?? this.notifyHour,
    notifyMinute: notifyMinute ?? this.notifyMinute,
    persistent: persistent ?? this.persistent,
    repeatMonthly: repeatMonthly ?? this.repeatMonthly,
    paidCycle: paidCycle ?? this.paidCycle,
    active: active ?? this.active,
  );
}
