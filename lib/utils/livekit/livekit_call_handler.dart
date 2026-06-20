import 'package:fluffychat/pages/profile_screen/incoming_call_page.dart';
import 'package:fluffychat/utils/additional_api/additional_api.dart';
import 'package:fluffychat/widgets/fluffy_chat_app.dart';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as livekit;
import 'package:matrix/matrix.dart';


class LiveKitCallHandler {
  static livekit.Room? _activeRoom;
  static livekit.EventsListener<livekit.RoomEvent>? _activeListener;

  static String? _currentMyId;
  static String? _currentPeerId;

  static VoidCallback? onPeerDisconnected;
  /// Перехватчик нового события в комнате.
  /// Вызывается ядром Matrix нативно при обновлении таймлайна, БЕЗ использования .listen()
  static Future<void> handleIncomingTimelineEvent(Event event, Client client) async {
    print('Получено новое событие в таймлайне: ${event.eventId}, тип: ${event.type}');
    // Проверяем только наш стабильный тип сообщения
    if (event.type == EventTypes.Message &&
        event.content['custom_call_type'] == 'livekit_audio') {
      
      _currentMyId = client.userID ?? '';
      _currentPeerId = event.content['caller_id']?.toString() ?? '';

      final profile = await client.getUserProfile(_currentMyId!);
      final myName = profile.displayname ?? _currentMyId;
      
      if (_currentPeerId == _currentMyId) return; // Игнорируем исходящие

      // Проверка на свежесть (в пределах 30 секунд)
      final serverTime = event.originServerTs.millisecondsSinceEpoch;
      final now = DateTime.now().millisecondsSinceEpoch;
      if ((now - serverTime).abs() > 30000) return;

      final roomId = event.roomId;
      if (roomId == null) return;

      try {
      // 1. Получаем токен для этой же комнаты
        final callData = await AdditionalApi.instance.createCallToken(
          participantId: _currentMyId!,
          targetParticipantId: _currentPeerId!,
          participantName: myName!, // Или твое имя из Matrix
        );

        final url = callData['server_url']?.toString() ?? '';
        final token = callData['token']?.toString() ?? '';

        if (url.isEmpty || token.isEmpty) {
          print("❌ Бэкенд не вернул URL или Токен для LiveKit");
          return;
        }

        final globalContext = FluffyChatApp.router.routerDelegate.navigatorKey.currentContext;
        if (globalContext != null) {
          Navigator.push(
            globalContext,
            MaterialPageRoute(
              builder: (context) => IncomingCallPage(
                callerName: event.content['caller_name']?.toString() ?? 'Абонент',
                url: url,
                token: token,
              ),
            ),
          );
        }
        
      } catch (e) {
        // _rejectCall();

        print("❌ Ошибка при подготовке фонового автоответа: $e");
        _cleanUp(_currentMyId!, _currentPeerId!);
      }
    }
  }

  static Future<void> connectActiveCall(String url, String token) async {
    if (_currentMyId == null || _currentPeerId == null) return;
    await _startSilentCall(
      url: url,
      token: token,
      myId: _currentMyId!,
      peerId: _currentPeerId!,
    );
  }

  static Future<void> hangupActiveCall() async {
    if (_currentMyId == null || _currentPeerId == null) return;
    await _cleanUp(_currentMyId!, _currentPeerId!);
  }

  static Future<void> _startSilentCall({
    required String url,
    required String token,
    required String myId,
    required String peerId,
  }) async {
    try {
      print("📞 Инициализация фонового Room...");
      final room = livekit.Room(roomOptions: livekit.RoomOptions(
        adaptiveStream: true,
        dynacast: true,
        defaultAudioOutputOptions: livekit.AudioOutputOptions(
          speakerOn: false, // Принудительно выключаем громкую связь на старте
        ),
      ));
      _activeRoom = room;
      _activeListener = room.createListener();

      _activeListener?.on((event) => print("LiveKit Event: $event"));

      // Слушаем и принудительно запускаем входящий звук
      _activeListener?.on<livekit.TrackSubscribedEvent>((event) async {
        print('🔔 Получен новый трек от собеседника: ${event.track.sid}, тип: ${event.track.kind}');
        if (event.track.kind.toString().contains('AUDIO') && livekit.lkPlatformIsMobile()) {
          print("🔊 Получен аудио-поток собеседника. Стартуем трек.");  
          await livekit.Hardware.instance.setSpeakerphoneOn(false);
        }
      });

      // Собеседник повесил трубку — чистим фоновые ресурсы
      _activeListener?.on<livekit.ParticipantDisconnectedEvent>((_) {
        print("⏹ Собеседник отключился. Завершаем сессию.");
        stopCurrentCall(myId, peerId);
        if (onPeerDisconnected != null) {
          print("📣 Передаем сигнал дисконнекта в UI...");
          onPeerDisconnected!();
        }
      });

      // Коннект к LiveKit серверу
      print("📡 Подключение к WebRTC: $url");
      await room.connect(url, token);
      
      // Публикуем свой микрофон
      print("Connected to LiveKit. Публикуем микрофон...");
      await room.localParticipant?.setMicrophoneEnabled(true);
      
      print("✅ Фоновый автоответ успешно отработал. Вы на связи.");
    } catch (e) {
      print("❌ Ошибка LiveKit соединения: $e");
      stopCurrentCall(myId, peerId);
    }
  }

  /// Метод сброса звонка для вызова снаружи или при дисконнекте
  static Future<void> stopCurrentCall(String myId, String peerId) async {
    await _cleanUp(myId, peerId);
  }

  static Future<void> _cleanUp(String myId, String peerId) async {
    print("🧹 Жесткая очистка нативного WebRTC слоя...");
    try {
      _activeListener?.dispose();
      
      if (_activeRoom != null) {
        print("Active room found. Cleaning up...");
        await _activeRoom!.localParticipant?.setMicrophoneEnabled(false);
        await _activeRoom!.disconnect();
      }

      // if (livekit.lkPlatformIsMobile()) {
      //   await livekit.Hardware.instance.setSpeakerphoneOn(false);
      // }

      // Отправляем сигнал отбоя на Django бэкенд
      await AdditionalApi.instance.hangupCall(
        participantId: myId,
        targetParticipantId: peerId,
      );
    } catch (e) {
      print("Ошибка при очистке ресурсов: $e");
    } finally {
      _activeRoom = null;
      _activeListener = null;
    }
  }
}