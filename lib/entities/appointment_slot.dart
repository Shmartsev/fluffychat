class AppointmentSlot {
  final int clinicId;
  final int doctorId;
  final DateTime startTime;
  final DateTime finishTime;

  AppointmentSlot({
    required this.clinicId,
    required this.doctorId,
    required this.startTime,
    required this.finishTime,
  });

  // Парсинг одной финальной ячейки времени
  factory AppointmentSlot.fromJson(Map<String, dynamic> json, int clinicId, int doctorId) {
    return AppointmentSlot(
      clinicId: clinicId,
      doctorId: doctorId,
      startTime: DateTime.parse(json['StartTime']),
      finishTime: DateTime.parse(json['FinishTime']),
    );
  }

  // Главный разборщик всей "матрёшки" от бэка
  static List<AppointmentSlot> fromResponseMap(Map<String, dynamic> json, int targetClinicId) {
    final List<AppointmentSlot> flatSlots = [];
    
    final int topDoctorId = json['doctor_id'] as int;
    
    // 1. Погружаемся в первый массив "slots" (который группировка по клиникам)
    if (json['slots'] != null) {
      final List<dynamic> clinicGroups = json['slots'] as List;
      
      for (var clinicGroup in clinicGroups) {
        final int currentClinicId = clinicGroup['clinic_id'] as int;
        
        // 2. Погружаемся во вложенный массив "slots" (где лежат StartTime/FinishTime)
        if (currentClinicId == targetClinicId) {
          if (clinicGroup['slots'] != null) {
            final List<dynamic> timeItems = clinicGroup['slots'] as List;
            
            for (var timeItem in timeItems) {
              if (timeItem['StartTime'] != null && timeItem['FinishTime'] != null) {
                flatSlots.add(
                  AppointmentSlot.fromJson(timeItem, currentClinicId, topDoctorId),
                );
              }
            }
          }
          // Нашли нужную клинику, обработали и можем выходить из цикла
          break; 
        }
      }
    }
    
    return flatSlots;
  }

  String get formattedTime {
    final hour = startTime.hour.toString().padLeft(2, '0');
    final minute = startTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}