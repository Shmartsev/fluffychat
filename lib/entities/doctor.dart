class Doctor {
  final int id;
  final String fullName;
  final String? profilePicture;
  final String specialty;
  final String elevatorSpeech; // Наша главная фича

  Doctor({
    required this.id,
    required this.fullName,
    this.profilePicture,
    required this.specialty,
    required this.elevatorSpeech,
  });

  factory Doctor.fromJson(Map<String, dynamic> json) {
    String spec = 'Стоматолог';
    if (json['specialties'] != null && (json['specialties'] as List).isNotEmpty) {
      spec = json['specialties'][0]['specialty_title'] ?? 'Стоматолог';
    }
    return Doctor(
      id: json['id'] as int,
      fullName: json['full_name'] ?? 'Без имени',
      profilePicture: json['profile_picture'],
      specialty: spec,
      elevatorSpeech: json['elevator_speech'] ?? '',
    );
  }
}