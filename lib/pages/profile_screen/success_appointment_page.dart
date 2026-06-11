import 'package:fluffychat/pages/profile_screen/profile_screen.dart';
import 'package:flutter/material.dart';

class SuccessAppointmentPage extends StatelessWidget {
  final String doctorName;
  final String clinicTitle;
  final String formattedDateTime; // Передаем красивую строку, например: "15 июня в 10:00"

  const SuccessAppointmentPage({
    Key? key,
    required this.doctorName,
    required this.clinicTitle,
    required this.formattedDateTime,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              
              // 1. Анимированная или просто красивая премиум-иконка успеха
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withAlpha(40),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  size: 56,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 32),
              
              // 2. Главный посыл
              const Text(
                'Вы записаны!',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ждём вас на приёме',
                style: TextStyle(
                  fontSize: 16,
                  color: theme.colorScheme.onSurface.withAlpha(140),
                ),
              ),
              const SizedBox(height: 32),
              
              // 3. Компактный талончик с деталями записи
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: theme.colorScheme.outlineVariant.withAlpha(40)),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ДАТА И ВРЕМЯ',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formattedDateTime,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const Divider(height: 24, thickness: 0.5),
                    Text(
                      'СПЕЦИАЛИСТ',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      doctorName,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const Divider(height: 24, thickness: 0.5),
                    Text(
                      'АДРЕС КЛИНИКИ',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      clinicTitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              
              const Spacer(),
              
              // 4. Кнопка перехода в Личный Кабинет
              ElevatedButton(
                onPressed: () {
                  // Очищаем весь стек экранов записи и возвращаем юзера в ЛК / Главный экран
                  // Предположим, что твой корневой экран с табами называется MainTabsPage(initialTab: ЛичныйКабинет)
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileScreen(),
                    ),
                    (route) => false, // Удаляет ВСЕ предыдущие экраны из памяти
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text(
                  'Перейти в личный кабинет',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}