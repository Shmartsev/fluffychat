class Appointment {
  final DateTime date;
  final String doctor;
  final String clinic;
  final String money;
  final List<String> positions; // Выставленные позиции/услуги
  final List<String> teeth;     // Номера зубов

  Appointment({
    required this.date,
    required this.doctor,
    required this.clinic,
    required this.money,
    required this.positions,
    required this.teeth,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      date: DateTime.parse(json['date'] ?? DateTime.now().toIso8601String()),
      doctor: json['doctor'] ?? 'Врач не указан',
      clinic: json['clinic'] ?? 'Клиника не указана',
      money: json['money'] ?? '—',
      positions: (json['treatments'] as List? ?? [])
                  .map((t) => (t as Map<String, dynamic>)['service']?.toString() ?? '—')
                  .toList(),
      teeth: (json['treatments'] as List? ?? [])
                  .map((t) => (t as Map<String, dynamic>)['tooth']?.toString() ?? '—')
                  .toList(),
    );
  }
}