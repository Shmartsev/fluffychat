import 'package:fluffychat/utils/additional_api/additional_api.dart';
import 'package:fluffychat/utils/livekit/call_screen.dart';
import 'package:fluffychat/utils/livekit/isolated_call_listener.dart';
import 'package:fluffychat/widgets/fluffy_chat_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:livekit_client/livekit_client.dart' as livekit;


class LiveKitCallHandler {
  static livekit.Room? _activeRoom;
  static livekit.EventsListener<livekit.RoomEvent>? _activeListener;

  static String? _currentMyId;
  static String? _currentPeerId;

  static VoidCallback? onPeerDisconnected;

  static Future<void> sendVoIPTokenToBackend(String token, String platform, String userId) async {
    try {
      await AdditionalApi.instance.registerVoIPToken(token, platform, userId);
      print("LiveKitCallHandler: Токен звонков $platform успешно зарегистрирован на сервере");
    } catch (e) {
      print("Ошибка отправки токена на бэкенд: $e");
    }
  }

  static void initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'call_channel',
        channelName: 'Звонки',
        channelDescription: 'Уведомление активного звонка',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        allowWakeLock: true, // НЕ ДАЕТ СПАТЬ CPU ПРИ БЛОКИРОВКЕ
        allowWifiLock: true, // НЕ ДАЕТ ОТКЛЮЧАТЬ WI-FI/3G
      ),
    );
  }

  static Future<dynamic> startCallService() async {
    // 1. Проверяем и просим разрешение на уведомления (Android 13+)
    final notificationPermission = 
        await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    // 2. Запускаем переднеплановый сервис
    if (await FlutterForegroundTask.isRunningService) {
      return FlutterForegroundTask.restartService();
    } else {
      return FlutterForegroundTask.startService(
        serviceId: 256,
        notificationTitle: 'MGChat',
        notificationText: 'Идет звонок...',
        notificationIcon: const NotificationIcon(metaDataName: 'ic_launcher'),
      );
    }
  }

  static Future<dynamic> stopCallService() {
    return FlutterForegroundTask.stopService();
  }

  static Future<void> handleAcceptCall(String roomId, String callerName) async {
    final callData = await AdditionalApi.instance.acceptCall(roomId: roomId);
    final url = callData['server_url']?.toString() ?? '';
    final token = callData['token']?.toString() ?? '';
    final myId = callData['userId'].toString();
    final peerId = callData['peerId'].toString();
    //final callerName = callData['caller_name'].toString();

    _currentMyId = myId;
    _currentPeerId = peerId;

    print("[LiveKitCallHandler] Start CallPage");

    if (url.isEmpty || token.isEmpty) {
      print("❌ Бэкенд не вернул URL или Токен для LiveKit");
      return;
    }

    print("[LiveKitCallHandler] Starting CallPage continued");

    connectActiveCall(url, token);

    final navState = FluffyChatApp.router.routerDelegate.navigatorKey.currentState;
    navState?.push(
      MaterialPageRoute(
        builder: (context) => CallScreen(
          callerName: callerName,
          onEndCall: navState.pop
        ),
      ),
    );
    
  }

  static void closeCallScreenIfOpen() {
    final navState = FluffyChatApp.router.routerDelegate.navigatorKey.currentState;
    // Закрываем верхний экран (CallScreen)
    if (navState?.canPop() ?? false) {
      navState?.pop();
    }
  }

  static Future<void> connectActiveCall(String url, String token) async {
    if (_currentMyId == null || _currentPeerId == null) return;
    initForegroundTask();
    await startCallService();
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
          //await livekit.Hardware.instance.setSpeakerphoneOn(false);
          print("✅ Фоновый автоответ успешно отработал. Вы на связи.");
          if (livekit.lkPlatform() == livekit.PlatformType.iOS) {
            await IsolatedCallListener.setConnected();
          }
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
      //print("📡 Подключение к WebRTC: $url");
      await room.connect(url, token);
      
      // Публикуем свой микрофон
      //print("Connected to LiveKit. Публикуем микрофон...");
      await room.localParticipant?.setMicrophoneEnabled(true);
      
      
      
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
      if (livekit.lkPlatform() == livekit.PlatformType.iOS) {
        await IsolatedCallListener.endCall();
      }
      
    } catch (e) {
      print("Ошибка при очистке ресурсов: $e");
    } finally {
      _activeRoom = null;
      _activeListener = null;
      stopCallService();
      closeCallScreenIfOpen();
    }
  }
}