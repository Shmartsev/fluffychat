class Clinic {
  final int id;
  final String title;
  final String displayedTitle;

  Clinic({required this.id, required this.title, required this.displayedTitle});

  factory Clinic.fromJson(Map<String, dynamic> json) {
    return Clinic(
      id: json['id'] as int,
      title: json['title'] ?? '',
      displayedTitle: json['displayed_title'] ?? '',
    );
  }
}