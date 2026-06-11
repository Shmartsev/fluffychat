import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluffychat/entities/appointment_slot.dart';
import 'package:fluffychat/entities/doctor.dart';
import 'package:fluffychat/pages/profile_screen/success_appointment_page.dart';
import 'package:fluffychat/utils/additional_api/additional_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:intl/intl.dart'; // Потребуется для красивого вывода дат (Пн, 15 июн)

class TimeSelectionPage extends StatefulWidget {
  final Doctor doctor;
  final List<AppointmentSlot> allSlots; // Передаем сюда массив слотов из API
  final String clinicTitle;
  final AdditionalApi _apiService = AdditionalApi.instance;
  final String patientId;

  TimeSelectionPage({
    Key? key,
    required this.patientId,
    required this.doctor, 
    required this.allSlots,
    required this.clinicTitle,
  }) : super(key: key);

  @override
  State<TimeSelectionPage> createState() => _TimeSelectionPageState();
}

class _TimeSelectionPageState extends State<TimeSelectionPage> {
  DateTime? _selectedDate;
  AppointmentSlot? _selectedSlot;
  List<DateTime> _availableDates = [];

  @override
  void initState() {
    super.initState();
    _parseAvailableDates();
  }

  // Извлекаем из всех слотов уникальные дни для горизонтального календаря
  void _parseAvailableDates() {
    final dates = widget.allSlots.map((slot) {
      // Сбрасываем время до 00:00, чтобы сравнивать чисто дни
      return DateTime(slot.startTime.year, slot.startTime.month, slot.startTime.day);
    }).toSet().toList();

    // Сортируем даты по хронологии
    dates.sort();
    
    setState(() {
      _availableDates = dates;
      if (_availableDates.isNotEmpty) {
        _selectedDate = _availableDates.first; // По дефолту выбираем первый доступный день
      }
    });
  }

  // Получаем слоты именно для выбранного в календаре дня
  List<AppointmentSlot> _getSlotsForSelectedDate() {
    if (_selectedDate == null) return [];
    return widget.allSlots.where((slot) {
      return slot.startTime.year == _selectedDate!.year &&
             slot.startTime.month == _selectedDate!.month &&
             slot.startTime.day == _selectedDate!.day;
    }).toList()..sort((a, b) => a.startTime.compareTo(b.startTime)); // сортируем время от утра к вечеру
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeSlots = _getSlotsForSelectedDate();

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Запись на приём'),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Icon(
                  Icons.location_on_outlined, 
                  size: 16, 
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Филиал: ',
                  style: TextStyle(
                    fontSize: 13, 
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Expanded(
                  child: Text(
                    widget.clinicTitle, // <-- Вывод переданного названия клиники
                    style: TextStyle(
                      fontSize: 13, 
                      fontWeight: FontWeight.bold, 
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.5),
          Expanded(
            child: _availableDates.isEmpty
                ? const Center(child: Text('Нет свободных слотов для записи'))
                : SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Базовая карточка врача
                        _buildDoctorBaseCard(theme),

                        const Padding(
                          padding: EdgeInsets.only(left: 16.0, top: 16, bottom: 8),
                          child: Text('Выберите дату', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),

                        // 2. Динамический горизонтальный календарь
                        _buildCalendarHorizontal(theme),

                        const Padding(
                          padding: EdgeInsets.only(left: 16.0, top: 20, bottom: 12),
                          child: Text('Свободное время', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),

                        // 3. Сетка реальных таймслотов
                        activeSlots.isEmpty 
                            ? const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text('На этот день всё занято'),
                              )
                            : _buildTimeGrid(theme, activeSlots),
                        
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _selectedSlot == null ? null : _buildBottomAction(theme),
    );
  }

  // --- Горизонтальный календарь на реальных датах ---
  Widget _buildCalendarHorizontal(ThemeData theme) {
    return SizedBox(
      height: 68,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        physics: const BouncingScrollPhysics(),
        itemCount: _availableDates.length,
        itemBuilder: (context, index) {
          final date = _availableDates[index];
          final isSelected = date == _selectedDate;

          // Форматируем дату (Пн / 15 июн) штатными средствами интернационализации
          final dayName = DateFormat('E', 'ru').format(date); // Пн, Вт...
          final dayNum = DateFormat('d MMM', 'ru').format(date); // 15 июн

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: InkWell(
              onTap: () => setState(() {
                _selectedDate = date;
                _selectedSlot = null; // Сбрасываем выбранный час при переключении дня
              }),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 72,
                decoration: BoxDecoration(
                  color: isSelected ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isSelected ? Colors.transparent : theme.colorScheme.outlineVariant.withAlpha(40)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(dayName, style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(dayNum, style: TextStyle(color: isSelected ? Colors.white : theme.colorScheme.onSurface, fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // --- Сетка таймслотов ---
  Widget _buildTimeGrid(ThemeData theme, List<AppointmentSlot> slots) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: slots.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4, 
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.1,
        ),
        itemBuilder: (context, index) {
          final slot = slots[index];
          final isSelected = slot == _selectedSlot;
          return InkWell(
            onTap: () => setState(() => _selectedSlot = slot),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSelected ? Colors.transparent : theme.colorScheme.outlineVariant.withAlpha(40)),
              ),
              alignment: Alignment.center,
              child: Text(
                slot.formattedTime, // Выведет строку вида "10:00"
                style: TextStyle(
                  color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // --- Нижняя кнопка подтверждения ---
  Widget _buildBottomAction(ThemeData theme) {
    final formattedDate = DateFormat('d MMMM', 'ru').format(_selectedSlot!.startTime);
    final timeString = _selectedSlot!.formattedTime;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: () async {
            // Финал! Отправляем на бэк: 
            // widget.doctor.id
            // _selectedSlot.startTime в формате ISO (строка)
            final isSuccess = await widget._apiService.bookAppointment(
              patientId: widget.patientId,
              doctorId: _selectedSlot?.doctorId, 
              clinicId: _selectedSlot?.clinicId, 
              startTime: _selectedSlot!.startTime.toIso8601String().split('.')[0],
              finishTime: _selectedSlot!.finishTime.toIso8601String().split('.')[0],
            );
            if (isSuccess && context.mounted) {
              // Успех! Показываем подтверждение и возвращаемся назад
              //final snackBar = SnackBar(content: Text('Вы записались на приём. Врач — ${widget.doctor.fullName}. $timeString $formattedDate'));
              // ScaffoldMessenger.of(context).showSnackBar(snackBar);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SuccessAppointmentPage(
                    doctorName: widget.doctor.fullName,
                    clinicTitle: widget.clinicTitle,
                    formattedDateTime: '$formattedDate в $timeString',
                  ),
                ),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          child: Text(
            'Записаться на $formattedDate в $timeString',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  // Базовый виджет доктора оставляем без изменений из прошлого шага
  Widget _buildDoctorBaseCard(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant.withAlpha(40)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Крупная круглая аватарка — без обрезки макушек
              CircleAvatar(
                radius: 36,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                child: widget.doctor.profilePicture != null
                    ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: widget.doctor.profilePicture!,
                          fit: BoxFit.cover,
                          width: 72,
                          height: 72,
                        ),
                      )
                    : const Icon(Icons.person, size: 36),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.doctor.specialty.toUpperCase(),
                      style: TextStyle(color: theme.colorScheme.primary, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.doctor.fullName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, height: 1.2),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // Цитата (elevator speech) — оставляем, она дает живой контекст и продает врача
          if (widget.doctor.elevatorSpeech.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withAlpha(150),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.format_quote, color: theme.colorScheme.primary.withAlpha(150), size: 18),
                      const SizedBox(width: 6),
                      Text('Подход к лечению', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.primary)),
                    ],
                  ),
                  Html(
                    data: widget.doctor.elevatorSpeech,
                    style: {
                      "p": Style(
                        fontSize: FontSize(13),
                        lineHeight: const LineHeight(1.3),
                        color: theme.colorScheme.onSurface.withAlpha(200),
                        margin: Margins.zero,
                        padding: HtmlPaddings.only(top: 4),
                      ),
                    },
                  ),
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }
}