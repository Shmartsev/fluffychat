import 'dart:async';
import 'dart:convert';

import 'package:fluffychat/entities/appointment.dart';
import 'package:fluffychat/entities/appointment_slot.dart';
import 'package:fluffychat/entities/clinic.dart';
import 'package:fluffychat/entities/doctor.dart';
import 'package:fluffychat/entities/patient.dart';
import 'package:fluffychat/utils/additional_api/token_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:matrix/matrix_api_lite/utils/logs.dart';

class AdditionalApi {

  static const String _baseUrl = 'https://mg-backend.it-ivs.ru/mg-backend';

  String clientPhone = '';
  String clientCode = '';
  String accessToken = '';
  String refreshToken = '';
  // Приватный конструктор
  AdditionalApi._internal();
  
  // Единственный экземпляр на все приложение
  static final AdditionalApi instance = AdditionalApi._internal();

  Future<void> sendRecoveryKey(String userId, String recovery) async {
    Logs().i('start Additional API sendRecoveryKey $recovery for $userId');
    try {
      print(recovery);
      final response = await http.post(
      Uri.parse('$_baseUrl/auth/matrix/backup'),
      headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'user_id': userId, 'recovery': recovery}),
    ).timeout(
      const Duration(seconds: 3),
    );
    debugPrint(response.body);
    Logs().i('Additional API sendRecoveryKey $recovery for $userId');
      
    } on TimeoutException catch (e) {
      print('Ошибка: Сервер не ответил за 3 секунды! $e');
      
    } catch (e) {
      print('Другая сетевая ошибка: $e');
      
    }
  }

  Future<String?> getRecoveryKey(String userID) async {

    Logs().i('Additional API getRecoveryKey $userID');
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/matrix/keys'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'user_id': userID}),
      ).timeout(
        const Duration(seconds: 3),
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        print(data['recovery']);
        return data['recovery'];
      }
      return null;
      
    } on TimeoutException catch (e) {
      print('Ошибка: Сервер не ответил за 3 секунды! $e');
      return null;
    } catch (e) {
      print('Другая сетевая ошибка: $e');
      return null;
    }

    // if (userID == '@arsenii:matrix.medgarant-spb.ru') {
    //   return 'EsTT 1eE4 pFyo b8Sy HncJ vj68 N7nn wSq4 fZ3K pohb LkYN SxqH';
    // }
    // return 'EsU1 csAL G9wC 4WMR f36h N29c 2U1L pjpw hUWB bPyf BtsE bGtW';
    
  }

  Future<void> sendSmsCode(String phone) async {
    Logs().i('start Additional API sendSmsCode for $phone');
    try {
      
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/matrix/send'),
        headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'phone': phone}),
        ).timeout(
          const Duration(seconds: 3),
        );
        debugPrint(response.body);
        Logs().i('Additional API sendSmsCode');
      
    } on TimeoutException catch (e) {
      print('Ошибка: Сервер не ответил за 3 секунды! $e');
      
    } catch (e) {
      print('Другая сетевая ошибка: $e');
      
    }

  }

  Future<Object?> verifySmsCode({required String phone, required String code}) async {

    Logs().i('Additional API getLogin $phone');
    //await Future.delayed(const Duration(seconds: 1));
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/matrix/login'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'phone': phone, 'code': code}),
      ).timeout(
        const Duration(seconds: 3),
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        clientPhone = phone;
        clientCode = code;
        fetchNewTokensFromServer(phone, code);
        print('Additional API getLogin $phone value: ${data['user_id']} ${data['password_on_create']}');
        return (login: data['user_id'], password: data['password_on_create']);
      }
      return null;
      
    } on TimeoutException catch (e) {
      print('Ошибка: Сервер не ответил за 3 секунды! $e');
      return null;
    } catch (e) {
      print('Другая сетевая ошибка: $e');
      return null;
    }
  }

  Future<void> fetchNewTokensFromServer(String clientPhone, String clientCode) async {

    try {
      final formattedPhone = clientPhone.startsWith('+') ? clientPhone : '+$clientPhone';

      final response = await http.post(
        Uri.parse('$_baseUrl/mobile_client/login'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'phone': formattedPhone, 
          'code': clientCode,
        }),
      ).timeout(
        const Duration(seconds: 3), // Жесткий таймаут 3 секунды, чтобы не копить фоновые ожидания
      );

      print('Response status: ${response.statusCode} value: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        // 1. Сохраняем в локальные переменные оперативной памяти
        accessToken = responseData['access_token'];
        refreshToken = responseData['refresh_token'];
        
        // 2. Параллельно записываем в безопасное зашифрованное хранилище телефона
        await TokenStorage.saveTokens(access: accessToken, refresh: refreshToken);
        print('Токены AdditionalAPI успешно получены и saved.');
      } else {
        print('AdditionalAPI отклонил авторизацию. Код ответа: ${response.statusCode}');
      }
    } catch (e) {
      // Важно: перехватываем таймауты (TimeoutException) и ошибки сети (SocketException)
      // Гасим их здесь, чтобы фоновый поток не мешал работе основного интерфейса чата
      print('Фоновое получение токенов сорвалось: $e');
    }
  }

  Future<void> initFromStorage() async {
    // 1. Читаем данные через твой класс TokenStorage
    final access = await TokenStorage.getAccessToken();
    final refresh = await TokenStorage.getRefreshToken();

    // 2. Наполняем поля текущего экземпляра (instance)
    accessToken = access ?? '';
    refreshToken = refresh ?? '';

    // 3. Если токены нашлись, можно сразу проверить их валидность
    if (accessToken.isNotEmpty) {
      print('Токены подтянуты в AdditionalApi: ${accessToken.substring(0, 20)}...');
      // Тут можно запустить фоновую проверку/обновление
      final isValid = await _verifyTokenWithServer(accessToken);
      if (!isValid) {
        print('Access-токен протух, запускаем обновление через Refresh...');
        await _refreshYourTokens(refreshToken);
      } else {
        print('Токены актуальны, ручки API готовы к работе.');
      }
    }
  }

  // Future<void> initAdditionalApiTokens() async {
  //   try {
  //     // Читаем из SecureStorage
  //     final savedAccess = await TokenStorage.getAccessToken();
  //     final savedRefresh = await TokenStorage.getRefreshToken();

  //     if (savedAccess == null || savedRefresh == null) {
  //       print('Токенов нет в SecureStorage. Ждем первый логин.');
  //       return; 
  //     }

  //     // Подтягиваем их в оперативку нашего синглтона
  //     accessToken = savedAccess;
  //     refreshToken = savedRefresh;

  //     print('Токены из TokenStorage подтянуты в инстанс AdditionalApi %accessToken');

  //     // Проверяем валидность на сервере
  //     final isValid = await _verifyTokenWithServer(accessToken);
      
  //     if (!isValid) {
  //       print('Access-токен протух, запускаем обновление через Refresh...');
  //       await _refreshYourTokens(refreshToken);
  //     } else {
  //       print('Токены актуальны, ручки API готовы к работе.');
  //     }
      
  //   } catch (e) {
  //     print('Ошибка инициализации токенов в синглтоне: $e');
  //   }
  // }

  // Внутренний метод проверки токена
  Future<bool> _verifyTokenWithServer(String token) async {
    try {
      // Твоя ручка проверки токена (обычно /auth/verify или получение легковесных данных)
      print(token);
      final response = await http.get(
        Uri.parse('$_baseUrl/mobile_client/me'),
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      ).timeout(
        const Duration(seconds: 3),
      );
      print('Проверка токена на сервере ${response.statusCode}');
      return response.statusCode == 200;
    } catch (_) {
      
      return false; // При любом сбое сети или 401 считаем токен невалидным
    }
  }

  // Внутренний метод обновления токенов
  Future<void> _refreshYourTokens(String refresh) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/mobile_client/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refresh, 'session_id': ''}),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        accessToken = responseData['access_token'] ?? '';
        refreshToken = responseData['refresh_token'] ?? '';
        
        await TokenStorage.saveTokens(access: accessToken, refresh: refreshToken);
        print('Токены успешно обновлены в фоне');
      }
    } catch (e) {
      print('Не удалось обновить рефреш-токен: $e');
    }
  }


  Future<List<Patient>> fetchPatients() async {
    if (accessToken.isEmpty) {
      await initFromStorage(); 
    }
    if (accessToken.isEmpty) return [];

    try {
      print(accessToken);
      final response = await http.get(
        Uri.parse('$_baseUrl/mobile_client/me'),
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      ).timeout(
        const Duration(seconds: 3),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        
        // Кастуем список ID из динамического JSON в строковый List<String>
        final List<String> patientIds = List<String>.from(responseData['patient_ids'] ?? []);
        
        // Явно указываем тип списка, чтобы не было ошибки List<dynamic>
        final List<Patient> patients = [];
        final List<Future<http.Response>> downloadFutures = [];

        for (final patientId in patientIds) {
          final future = http.get(
            Uri.parse('$_baseUrl/mobile_client/patient_short_info?patient_id=$patientId'),
            headers: {'Authorization': 'Bearer $accessToken'},
          ).timeout(
            const Duration(seconds: 3),
          );
          
          downloadFutures.add(future);
        }

        // Стреляем пачкой запросов
        final List<http.Response> responses = await Future.wait(downloadFutures);

        // Разбираем результаты
        for (final resp in responses) {
          if (resp.statusCode == 200) {
            final patientJson = jsonDecode(resp.body);
            print(patientJson);
            patients.add(Patient.fromJson(patientJson));
          }
        }

        return patients;
      }
    } catch (e) {
      print('Ошибка при загрузке пациентов: $e');
    }
      
    // Заглушка сработает, если сервер упал, вернул не 200 или отвалился по таймауту
    return [
      Patient(id: '1', name: 'Иванов Иван (Отец)'),
      Patient(id: '2', name: 'Иванова Мария (Дочь)'),
    ];
  }

  Future<List<Appointment>> fetchAppointments(String patientId) async {
    try {
      print('fetchAppointments for patientId: $patientId with token: ${accessToken.substring(0, 5)}...');
      final response = await http.get(
        Uri.parse('$_baseUrl/medinfo/visits/$patientId'),
        /* headers: {'Authorization': 'Bearer $accessToken'}, */);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        //print(data);
        final List<dynamic> visitsRaw = data['visits'] ?? [];
        return List<Appointment>.from(
          visitsRaw.map((item) => Appointment.fromJson(item))
        );
          
      }
    } catch (e) {
      print('Ошибка API приемов: $e');
    }
    // Дефолтная заглушка для тестов
    return [
      Appointment(
        date: DateTime.parse('2026-05-12T10:30:00'),
        doctor: 'Смирнова А.В. (Терапевт)',
        clinic: 'Клиника на Петроградке',
        money: '3500',
        positions: ['Лечение кариеса', 'Установка световой пломбы'],
        teeth: ['16', '17'],
      ),
      Appointment(
        date: DateTime.parse('2026-04-20T14:00:00'),
        doctor: 'Петров К.М. (Хирург)',
        clinic: 'Клиника на Петроградке',
        money: '2500',
        positions: ['Удаление зуба мудрости'],
        teeth: ['38'],
      ),
    ];
  }

  Future<List<Clinic>?> getBranches() async {
    try {
      final response = await http.get(Uri.parse('https://mg-django.spbeu.ru/api/website/clinics-description/'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        print(data);
        return data.map((json) => Clinic.fromJson(json)).toList();
      }
    } catch (e) {
      print('Ошибка при загрузке клиник: $e');
    }
    return null; // Возвращаем null при ошибке, чтобы можно было обработать в UI
  }

  Future<List<Doctor>?> getDoctors({required int clinicId}) async {
    try {
      final response = await http.get(Uri.parse('https://mg-django.spbeu.ru/api/docinfo/doctors-in-timetable?clinics=$clinicId'));
      print('getDoctors response for clinicId $clinicId: ${response.statusCode}');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body)['results'] as List<dynamic>;
        //print(data);
        return data.map((json) => Doctor.fromJson(json)).toList();
      }
    } catch (e) {
      print('Ошибка при загрузке врачей: $e');
    }
    return null; // Возвращаем null при ошибке, чтобы можно было обработать в UI
  }

  Future<List<AppointmentSlot>?> getSlots({required int clinicId, required int doctorId}) async {
    try {
      final response = await http.get(Uri.parse('https://mg-django.spbeu.ru//api/docinfo/doctor_slots/$doctorId/'));
      print('getSlots response for clinicId $clinicId doctorId $doctorId: ${response.statusCode} ${response.body}');
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body); 

        // 2. Разворачиваем матрёшку в плоский список одной строкой
        final List<AppointmentSlot> slots = AppointmentSlot.fromResponseMap(responseData, clinicId);
        return slots;
      }
    } catch (e) {
      print('Ошибка при загрузке слотов: $e');
    }
    return null; // Возвращаем null при ошибке, чтобы можно было обработать в UI
  }

  Future<bool> bookAppointment({required String patientId, int? doctorId, int? clinicId, required String startTime, required String finishTime}) async {
    try {
      // Тут должен быть реальный API вызов для бронирования
      print('Booking appointment with patientId: $patientId, doctorId: $doctorId, clinicId: $clinicId, startTime: $startTime, finishTime: $finishTime');
      final token = 'e32c26d322468a7f5e8858049f627a4798287418';
      
      // final response = await http.get(
      //   Uri.parse('https://mg-django.spbeu.ru/api/website/available-slots/?booking_token=$token')
      // );
      // print('Token response: ${response.statusCode} ${response.body}');
      final bookResponse = await http.post(
        Uri.parse('https://mg-django.spbeu.ru/api/docinfo/lk-booking/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
        body: jsonEncode({
                          'patient_id': patientId,
                                   'doctor_id': doctorId,
                                   'clinic_id': clinicId,
                                   'StartTime': startTime,
                                   'FinishTime': finishTime,
                                  
                        }),
      );
      print('Book appointment response: ${bookResponse.statusCode} ${bookResponse.body}');
      return bookResponse.statusCode == 200;

    } catch (e) {
      print('Ошибка при бронировании приёма: $e');
      return false;
    }
     // Заглушка, всегда успешно
  }

  Future<List<dynamic>>? fetchUpcomingAppointments(String patientId) async {
    try {
      print('fetchPreentries for patientId: $patientId with token: ${accessToken.substring(0, 5)}...');
      final response = await http.get(
        Uri.parse('$_baseUrl/mobile_client/patient_full_info?patient_id=$patientId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken'
        }
      );
      print('fetchPreentries response for patientId $patientId: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> visitsRaw = data['preentries']['planned'] ?? [];
        print('Upcoming appointments raw data: $visitsRaw');
        return List<Appointment>.from(
          visitsRaw.map((item) => Appointment.fromJson(item))
        );
          
      }
    } catch (e) {
      print('Ошибка API приемов: $e');
    }
    // Дефолтная заглушка для тестов
    return [];
    
  }

  Future<Map<String, dynamic>> createCallToken({
    required String participantId,
    required String targetParticipantId,
    required String participantName,
  }) async {
    final response = await http.post(
      Uri.parse('https://dev.mg-backend.it-ivs.ru/mg-backend/livekit/token'),
        headers: {
          'Content-Type': 'application/json',
          //'Authorization': 'Token $token',
        },
        body: jsonEncode({
          "participant_id": participantId,
          "target_participant_id": targetParticipantId,
          "participant_name": participantName,
        }),
    );
    if (response.statusCode == 200) {
      print('Call token response: ${response.statusCode} ${response.body}');
      final data = jsonDecode(response.body);
      return data; // Ждем тут {"url": "wss://...", "token": "..."}
    }
    return {}; // В случае ошибки возвращаем пустой словарь, который нужно обработать в UI
  }

  // 2. Сигнал о завершении звонка
  Future<void> hangupCall({
    required String participantId,
    required String targetParticipantId,
  }) async {
    final response = await http.post(
      Uri.parse('https://dev.mg-backend.it-ivs.ru/mg-backend/livekit/hangup'),
        headers: {
          'Content-Type': 'application/json',
          //'Authorization': 'Token $token',
        },
        body: jsonEncode({
          "participant_id": participantId,
          "target_participant_id": targetParticipantId,
        }),
    );
    if (response.statusCode == 200) {
      print('Call hangup response: ${response.statusCode} ${response.body}');
      final data = jsonDecode(response.body);
       // Ждем тут {"url": "wss://...", "token": "..."}
    }
  }
}