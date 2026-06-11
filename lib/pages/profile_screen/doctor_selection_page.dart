import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluffychat/entities/appointment_slot.dart';
import 'package:fluffychat/entities/doctor.dart';
import 'package:fluffychat/pages/profile_screen/time_selection_page.dart';
import 'package:fluffychat/utils/additional_api/additional_api.dart';
import 'package:flutter/material.dart';

class DoctorSelectionPage extends StatelessWidget {
  final int clinicId;
  final String clinicTitle;
  final AdditionalApi _apiService = AdditionalApi.instance;
  final String patientId; // Добавляем поле для идентификации пациента при бронировании

  DoctorSelectionPage({
    Key? key,
    required this.clinicId,
    required this.clinicTitle,
    required this.patientId,
  }) : super(key: key);

  Future<List<Doctor>> _fetchDoctors() async {
    //await Future.delayed(const Duration(milliseconds: 300)); // Имитация сети

    final doctors = await _apiService.getDoctors(clinicId: clinicId);
    
    // Твой реальный JSON
    final List<dynamic> results = [
      {
        "id": 79,
        "full_name": "Абгарян Армен Ваникович",
        "profile_picture": "https://mg-django.spbeu.ru/media/doctors/%D0%90%D0%B1%D0%B3%D0%B0%D1%80%D1%8F%D0%BD_%D0%90%D1%80%D0%BC%D0%B5%D0%BD_%D0%B2%D0%B8%D0%BA%D1%82%D0%BE%D1%80%D0%BE%D0%B2%D0%B8%D1%87.jpg.400x400_q85.jpg",
        "specialties": [{"specialty_title": "Имплантолог"}]
      },
      {
        "id": 109,
        "full_name": "Абдулаев Эмиль Сабутаевич",
        "profile_picture": "https://mg-django.spbeu.ru/media/doctors/IMG_0264.JPG.400x400_q85.jpg",
        "specialties": [{"specialty_title": "Терапевт"}]
      },
      {
        "id": 64,
        "full_name": "Аветисян Лолита Манвеловна",
        "profile_picture": "https://mg-django.spbeu.ru/media/doctors/%D0%90%D0%B2%D0%B5%D1%82%D0%B8%D1%81%D1%8F%D0%BD_%D0%9B%D0%BE%D0%BB%D0%B8%D1%82%D0%B0_%D0%9C%D0%B0%D0%BD%D0%B2%D0%B5%D0%BB%D0%BE%D0%B2%D0%BD%D0%B0.jpg.400x400_q85.jpg",
        "specialties": [{"specialty_title": "Ортодонт"}]
      }
    ];

    return doctors ?? results.map((json) => Doctor.fromJson(json)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: FutureBuilder<List<Doctor>>(
        future: _fetchDoctors(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(child: Text('Ошибка загрузки специалистов'));
          }

          final doctors = snapshot.data!;

          return CustomScrollView(
            slivers: [
              // Красивая большая шапка
              SliverAppBar.large(
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(clinicTitle),
                    const SizedBox(height: 4),
                    Text(
                      'Выберите специалиста',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface.withAlpha(140),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                backgroundColor: theme.colorScheme.surface,
                scrolledUnderElevation: 0,
              ),

              // Аккуратный индикатор шагов (Линейка прогресса)
              
              
              // Просторный список врачей в один ряд (List вместо Grid)
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final doc = doctors[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: _buildDoctorRowCard(context, doc, theme),
                      );
                    },
                    childCount: doctors.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDoctorRowCard(BuildContext context, Doctor doc, ThemeData theme) {
    return InkWell(
      onTap: () async {
        // 1. Показываем лоадер, пока тянутся слоты (опционально, но для UX хорошо)
        // Настоящий Lean-подход: получаем данные прямо перед переходом
        
        // Пример вызова твоего API:
        final slotsResponse = await _apiService.getSlots(clinicId: clinicId, doctorId: doc.id);
        // List<AppointmentSlot> slots = (slotsResponse.data as List).map((e) => AppointmentSlot.fromJson(e)).toList();

        // Временный мок для проверки перехода:
        final mockSlots = slotsResponse ??[
          AppointmentSlot(clinicId: clinicId, doctorId: doc.id, startTime: DateTime.parse("2026-04-09T10:00:00"), finishTime: DateTime.parse("2026-04-09T10:45:00")),
          AppointmentSlot(clinicId: clinicId, doctorId: doc.id, startTime: DateTime.parse("2026-04-09T11:00:00"), finishTime: DateTime.parse("2026-04-09T11:45:00")),
          AppointmentSlot(clinicId: clinicId, doctorId: doc.id, startTime: DateTime.parse("2026-04-10T14:00:00"), finishTime: DateTime.parse("2026-04-10T14:45:00")),
        ];

        // 2. Плавный переход на финальный шаг конвейера
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TimeSelectionPage(
              patientId: patientId, // Передаем ID пациента для бронирования
              doctor: doc,
              allSlots: mockSlots, // Передаем распарсенные слоты в базу экрана времени
              clinicTitle: clinicTitle,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant.withAlpha(40)),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Большая круглая аватарка
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              clipBehavior: Clip.antiAlias,
              child: doc.profilePicture != null
                  ? CachedNetworkImage(
                      imageUrl: doc.profilePicture!,
                      fit: BoxFit.cover,
                      errorWidget: (c, e, s) => const Icon(Icons.person, size: 40),
                    )
                  : const Icon(Icons.person, size: 40),
            ),
            const SizedBox(width: 16),
            
            // Блок с информацией (Специализация + ФИО)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc.specialty.toUpperCase(),
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    doc.fullName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            
            // Шеврон (иконка стрелочки) — визуальный намек на тап
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurface.withAlpha(100),
            ),
          ],
        ),
      ),
    );
  }
}