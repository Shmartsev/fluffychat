import 'dart:async';
import 'dart:convert';

import 'package:fluffychat/entities/appointment.dart';
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
      print('Токены подтянуты в AdditionalApi: ${accessToken.substring(0, 5)}...');
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

  Future<void> initAdditionalApiTokens() async {
    try {
      // Читаем из SecureStorage
      final savedAccess = await TokenStorage.getAccessToken();
      final savedRefresh = await TokenStorage.getRefreshToken();

      if (savedAccess == null || savedRefresh == null) {
        print('Токенов нет в SecureStorage. Ждем первый логин.');
        return; 
      }

      // Подтягиваем их в оперативку нашего синглтона
      accessToken = savedAccess;
      refreshToken = savedRefresh;

      print('Токены из TokenStorage подтянуты в инстанс AdditionalApi');

      // Проверяем валидность на сервере
      final isValid = await _verifyTokenWithServer(accessToken);
      
      if (!isValid) {
        print('Access-токен протух, запускаем обновление через Refresh...');
        await _refreshYourTokens(refreshToken);
      } else {
        print('Токены актуальны, ручки API готовы к работе.');
      }
      
    } catch (e) {
      print('Ошибка инициализации токенов в синглтоне: $e');
    }
  }

  // Внутренний метод проверки токена
  Future<bool> _verifyTokenWithServer(String token) async {
    try {
      // Твоя ручка проверки токена (обычно /auth/verify или получение легковесных данных)
      final response = await http.get(
        Uri.parse('$_baseUrl/mobile_client/me'),
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      ).timeout(
        const Duration(seconds: 3),
      );
      
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
        print(data);
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
}