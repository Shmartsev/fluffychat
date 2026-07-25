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
        final String roomId = call.arguments;
        print('roomId = $roomId');
        
        if (roomId.isNotEmpty) {
          // 3. Вызываем подключение к LiveKit прямо внутри этого изолята!
          print('Start connecting to $roomId');
          await _connectToLiveKitRoom(roomId);
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

  // Метод подключения к LiveKit
  Future<void> _connectToLiveKitRoom(String roomId) async {
    try {
      print("[Package Dart] Инициализируем аудиосессию для комнаты: $roomId");
      await LiveKitCallHandler.handleAcceptCall(roomId);
      
      // Настраиваем звуковую подсистему для звонка
      // await Hardware().selectAudioOutput(AudioOutput.earpiece);
      
      // // Инициализируем комнату LiveKit
      // final room = Room();
      
      // // Токен для комнаты LiveKit вы должны сгенерировать на своем бэкенде 
      // // и либо передавать прямо в data-пуше, либо быстро запрашивать по HTTP.
      // // Пока подставьте сюда ваш тестовый токен генерации.
      // String liveKitToken = 'ВАШ_LIVEKIT_TOKEN_ДЛЯ_КОМНАТЫ'; 
      
      // await room.connect('https://medgarant-spb.ru', liveKitToken);
      
      // // Автоматически включаем микрофон после успешного коннекта
      // await room.localParticipant.setMicrophoneEnabled(true);
      
      //print("[Package Dart] Успешно подключились к LiveKit! Голосовой канал открыт.");
    } catch (e) {
      print("[Package Dart] Ошибка подключения к LiveKit: $e");
    }
  }
}
