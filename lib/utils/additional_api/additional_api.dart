import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:matrix/matrix_api_lite/utils/logs.dart';

class AdditionalApi {
  // Приватный конструктор
  AdditionalApi._internal();
  
  // Единственный экземпляр на все приложение
  static final AdditionalApi instance = AdditionalApi._internal();

  Future<void> sendRecoveryKey(String userId, String recovery) async {
    Logs().i('start Additional API sendRecoveryKey $recovery for $userId');
    try {
      print(recovery);
      final response = await http.post(
      Uri.parse('https://mg-backend.it-ivs.ru/mg-backend/auth/matrix/backup'),
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
        Uri.parse('https://mg-backend.it-ivs.ru/mg-backend/auth/matrix/keys'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'user_id': userID}),
      ).timeout(
        const Duration(seconds: 3),
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return (data['recovery'] == null) ? '' : data['recovery'];
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
}