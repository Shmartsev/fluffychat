import 'package:fluffychat/entities/clinic.dart';
import 'package:fluffychat/pages/profile_screen/doctor_selection_page.dart';
import 'package:fluffychat/utils/additional_api/additional_api.dart';
import 'package:flutter/material.dart';

class AppointmentBookingSheet extends StatefulWidget {
  final String patientId; // Добавляем поле для идентификации пациента при бронировании
  const AppointmentBookingSheet({Key? key, required this.patientId}) : super(key: key);

  @override
  State<AppointmentBookingSheet> createState() => _AppointmentBookingSheetState();
}

class _AppointmentBookingSheetState extends State<AppointmentBookingSheet> {
  int _currentStep = 0;
  final AdditionalApi _apiService = AdditionalApi.instance;
  
  // Выбранные данные для API
  int? _selectedClinicId;
  String? _selectedDoctorId;
  String? _selectedTimeSlot;

  Future<List<Clinic>> _fetchClinics() async {
  // Здесь будет твой реальный вызов: 
  
    final clinics = await _apiService.getBranches();

    final List<dynamic> rawData = [
      {"id": 1, "title": "Приморский", "displayed_title": "— Стоматология на Беговой"},
      {"id": 3, "title": "Невский", "displayed_title": "Стоматология на Большевиков"},
      {"id": 4, "title": "Московский", "displayed_title": "Стоматология на Фрунзенской"},
      {"id": 5, "title": "Девяткино", "displayed_title": "Стоматология в Девяткино"},
      {"id": 6, "title": "Петровский", "displayed_title": "Стоматология на Спортивной"}
    ];
    
    return clinics ?? rawData.map((json) => Clinic.fromJson(json)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        top: 16, left: 16, right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Линия-гриппер сверху для красоты
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            
            // Заголовок с кнопкой "Назад"
            Row(
              children: [
                if (_currentStep > 0)
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => setState(() => _currentStep--),
                  ),
                Text(
                  'Выберите клинику',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Рендерим нужный шаг
            if (_currentStep == 0) _buildClinicStep(),
            
          ],
        ),
      ),
    );
  }

  // --- ШАГ 1: Список клиник (Просто, без каруселей) ---
  Widget _buildClinicStep() {
    return FutureBuilder<List<Clinic>>(
      future: _fetchClinics(), // Твой метод Additional API
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(), // Легкий лоадер, пока бэк отвечает
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return const Center(
            child: Text('Не удалось загрузить список клиник'),
          );
        }

        final clinics = snapshot.data!;

        return Column(
          children: clinics.map((clinic) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: ListTile(
              tileColor: Theme.of(context).colorScheme.surfaceContainerHigh,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              leading: const Icon(Icons.local_hospital, color: Colors.blue),
              
              // Выводим ТИТЛ клиники, как ты просил
              title: Text(
                clinic.title, 
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              
              // Сабтитлом можно красиво пуститьdisplayedTitle для контекста (опционально)
              subtitle: Text(
                clinic.displayedTitle, 
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // 1. Закрываем нижнюю шторку выбора клиник
                Navigator.pop(context); 
                
                // 2. Открываем полноэкранную страницу с докторами
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DoctorSelectionPage(
                      patientId: widget.patientId, // Передаем ID пациента
                      clinicId: clinic.id,         // Передаем ID (например, 1 или 5)
                      clinicTitle: clinic.title,   // Передаем Название для красивого AppBar
                    ),
                  ),
                );
              },
            ),
          )).toList(),
        );
      },
    );
  }
}