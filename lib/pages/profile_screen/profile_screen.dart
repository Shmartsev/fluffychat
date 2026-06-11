// lib/features/profile/profile_screen.dart
import 'package:fluffychat/entities/appointment.dart';
import 'package:fluffychat/entities/patient.dart';
import 'package:fluffychat/pages/profile_screen/appointment_booking_sheet.dart';
import 'package:fluffychat/utils/additional_api/additional_api.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {

  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _apiService = AdditionalApi.instance;

  late Future<List<Patient>> _patientsFuture;
  Future<List<Appointment>>? _appointmentsFuture;
  
  Patient? _selectedPatient;

  String formatAppointmentDate(DateTime dt) {
  // Добавляем ведущие нули, чтобы вместо "9:5" было "09:05"
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');

    return '$day.$month.${dt.year} в $hour:$minute';
  }

  @override
  void initState() {
    super.initState();
    // Сразу ищем пациентов по номеру телефона
    _patientsFuture = _apiService.fetchPatients();
  }

  // Метод вызывается при смене пациента в выпадающем списке
  void _onPatientChanged(Patient? patient) {
    if (patient == null) return;
    setState(() {
      _selectedPatient = patient;
      // Запускаем загрузку приемов для выбранного пациента
      _appointmentsFuture = _apiService.fetchAppointments(patient.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Личный кабинет')),
      body: FutureBuilder<List<Patient>>(
        future: _patientsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Пациенты не найдены для этого номера'));
          }

          final patients = snapshot.data!;
          // Если еще никто не выбран, берем первого по дефолту
          if (_selectedPatient == null && patients.isNotEmpty) {
            _selectedPatient = patients.first;
            _appointmentsFuture = _apiService.fetchAppointments(_selectedPatient!.id);
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            key: const ValueKey('profile_content'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Спикер/Выбор пациента
                const Text('Мед-карта пациента:', style: TextStyle(fontSize: 14, color: Colors.grey)),
                DropdownButton<Patient>(
                  value: _selectedPatient,
                  isExpanded: true,
                  items: patients.map((Patient p) {
                    return DropdownMenuItem<Patient>(
                      value: p,
                      child: Text(p.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    );
                  }).toList(),
                  onChanged: _onPatientChanged,
                ),
                const SizedBox(height: 20),
                
                // 2. Список приемов
                const Text('История приемов:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Expanded(
                  child: _buildAppointmentsList(),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          //if (_selectedPatient == null) return;
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => AppointmentBookingSheet(patientId: _selectedPatient!.id),
          );
        },
        label: const Text('Записаться на прием'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  // Виджет отрисовки приемов
  Widget _buildAppointmentsList() {
    if (_appointmentsFuture == null) return const SizedBox();

    return FutureBuilder<List<Appointment>>(
      future: _appointmentsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('История приемов пуста'));
        }

        final appointments = snapshot.data!;

        return ListView.builder(
          itemCount: appointments.length,
          itemBuilder: (context, index) {
            final appointment = appointments[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- ДОКТОР ---
                    Text(
                      appointment.doctor,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),

                    // --- КЛИНИКА ---
                    Row(
                      children: [
                        const Icon(Icons.local_hospital, size: 14, color: Colors.blue),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            appointment.clinic,
                            style: TextStyle(color: Colors.grey[700], fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // --- ДАТА И ВРЕМЯ ---
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 14, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text(
                          formatAppointmentDate(appointment.date),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),

                    // --- ЗУБЫ (Выводим плашки, если список не пуст) ---
                    if (appointment.teeth.isNotEmpty) ...[
                      const Divider(height: 20),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            'Зубы: ',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: appointment.teeth.map((tooth) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.blue.withOpacity(0.25)),
                                ),
                                child: Text(
                                  tooth,
                                  style: const TextStyle(
                                    fontSize: 12, 
                                    fontWeight: FontWeight.bold, 
                                    color: Colors.blue,
                                  ),
                                ),
                              )).toList(),
                            ),
                          ),
                        ],
                      ),
                    ],

                    // --- ПОЗИЦИИ / УСЛУГИ (Выводим простым списком текстов) ---
                    if (appointment.positions.isNotEmpty) ...[
                      const Divider(height: 20),
                      const Text(
                        'Оказанные услуги:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                      ),
                      const SizedBox(height: 6),
                      // Используем Column вместо ListView, так как список обычно короткий 
                      // и нам не нужны накладные расходы на скролл-виджеты
                      Column(
                        children: appointment.positions.map((position) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• ', style: TextStyle(color: Colors.grey)),
                              Expanded(
                                child: Text(
                                  position,
                                  style: const TextStyle(fontSize: 13, color: Colors.blueGrey),
                                ),
                              ),
                            ],
                          ),
                        )).toList(),
                      ),
                    ],

                    const Divider(height: 24),

                    // --- СУММА (MONEY) ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Всего к оплате:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          appointment.money,
                          style: const TextStyle(
                            fontSize: 16, 
                            fontWeight: FontWeight.bold, 
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}