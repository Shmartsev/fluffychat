import 'package:fluffychat/utils/livekit/livekit_call_handler.dart';
import 'package:flutter/services.dart';

class IsolatedCallListener {
  // Название канала ДОЛЖНО СТРОГО до буквы совпадать со Swift-кодом!
  static const _channel = MethodChannel('com.mgchat/voip');

  static Future<void> setConnected() async {
    await _channel.invokeMethod('setConnectedSuccessfully');
  }

  static Future<void> endCall() async {
    await _channel.invokeMethod('endCallFromDart');
  }

  void startListening() {
    print("[Package Dart] startListening() called. Подписываемся на пуши звонков в изоляте Dart.");
    // Вешаем реактивный слушатель на нативный канал
    _channel.setMethodCallHandler((MethodCall call) async {
      //print("[Package Dart] Пуш звонка успешно долетел до Dart-изолята! START ${call.method}");
      if (call.method == 'onIncomingCallPushAndroid') {
        print("[Package Dart] Пуш звонка успешно долетел до Dart-изолята! START ${call.method}");
        final Map<dynamic, dynamic> pushPayload = call.arguments;
        print("[Package Dart] Полный Payload: $pushPayload");
      }

      if (call.method == 'onCallAction') {
        final payload = call.arguments as Map<dynamic, dynamic>;
        final event = payload['event'];
        final roomId = payload['room_id'] ?? '';
        final callerName = payload['caller_name'] ?? 'Неизвестный';
        if (event == 'accept') {
          print("[Package Dart] Пользователь нажал accept на нативном экране Android: $payload");
          
          if (roomId.isNotEmpty) {
            print("[Package Dart] Пользователь принял звонок. Подключаемся к комнате LiveKit: $roomId");
            await _connectToLiveKitRoom(roomId, callerName);
          }
        } else if (event == 'decline') {
          print("[Package Dart] Пользователь нажал decline на нативном экране Android: $payload");
          await _disconnectFromLiveKitRoom(roomId, callerName);
        }
      }

      if (call.method == 'onVoIPTokenReceived') {
        final iosVoipToken = call.arguments;
        print("[Dart] Успешно получен нативный iOS VoIP токен: $iosVoipToken");

        
        await _sendTokenToYourBackend(iosVoipToken, 'ios');
      }
      if (call.method == 'onIncomingCallPush') {
        // 1. Принимаем сырой JSON-payload, который нам прислал Swift
        final Map<dynamic, dynamic> pushPayload = call.arguments;
        print("[Package Dart] Полный Payload: $pushPayload");
        
      }
      if (call.method == 'onCallAccepted') {
        print("[Package Dart] Пуш звонка успешно долетел до Dart-изолята! ${call.method}");
        //print("[Package Dart] Полный Payload: ${call.arguments}");
        final String roomId = call.arguments['room_id'] ?? '';
        final String callerName = call.arguments['caller_name'] ?? 'Неизвестный';
        print('roomId = $roomId, callerName = $callerName');
        
        if (roomId.isNotEmpty) {
          // 3. Вызываем подключение к LiveKit прямо внутри этого изолята!
          print('Start connecting to $roomId');
          await _connectToLiveKitRoom(roomId, callerName);
        }
      }
    });
  }

  Future<void> _sendTokenToYourBackend(String token, String platform) async {
    try {
      await LiveKitCallHandler.sendVoIPTokenToBackend(token, platform, '');
      print("IsolatedCallListener: Токен звонков iOS успешно зарегистрирован на сервере");
    } catch (e) {
      print("Ошибка отправки токена на бэкенд: $e");
    }
  }

  Future<void> _connectToLiveKitRoom(String roomId, String callerName) async {
    try {
      print("[Package Dart] Инициализируем аудиосессию для комнаты: $roomId");
      await LiveKitCallHandler.handleAcceptCall(roomId, callerName); // Передаем пустое имя звонящего, если оно не требуется
    } catch (e) {
      print("[Package Dart] Ошибка подключения к LiveKit: $e");
    }
  }
  
  Future<void> _disconnectFromLiveKitRoom(roomId, callerName) async {
    print('[Package Dart] Пользователь отклонил звонок. Написать на бэкенд, что звонок отклонен. roomId: $roomId, callerName: $callerName');
  }
}
