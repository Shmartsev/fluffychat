import 'package:fluffychat/pages/profile_screen/incoming_call_page.dart';
import 'package:fluffychat/widgets/fluffy_chat_app.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';


class LiveKitCallHandler {
  /// Перехватчик нового события в комнате.
  /// Вызывается ядром Matrix нативно при обновлении таймлайна, БЕЗ использования .listen()
  static void handleIncomingTimelineEvent(Event event, Client client) {
    print('Получено новое событие в таймлайне: ${event.eventId}, тип: ${event.type}');
    // Проверяем только наш стабильный тип сообщения
    if (event.type == EventTypes.Message &&
        event.content['custom_call_type'] == 'livekit_audio') {
      
      final myId = client.userID ?? '';
      final callerId = event.content['caller_id']?.toString() ?? '';
      
      if (callerId == myId) return; // Игнорируем исходящие

      // Проверка на свежесть (в пределах 30 секунд)
      final serverTime = event.originServerTs.millisecondsSinceEpoch;
      final now = DateTime.now().millisecondsSinceEpoch;
      if ((now - serverTime).abs() > 30000) return;

      // Future.microtask(() async {

        final roomId = event.roomId;
        if (roomId == null) return;

        // Магия навигации FluffyChat:
        // В твоем файле Matrix мы четко видим, что автор использует FluffyChatApp.router.
        // Достаем глобальный контекст роутера мессенджера напрямую, минуя UI-виджеты:
        final globalContext = FluffyChatApp.router.routerDelegate.navigatorKey.currentContext;

        if (globalContext != null) {
          Navigator.push(
            globalContext,
            MaterialPageRoute(
              builder: (context) => IncomingCallPage(
                roomId: roomId,
                callEventId: event.eventId,
                callerName: event.content['caller_name']?.toString() ?? 'Абонент',
                participantId: myId,
                targetParticipantId: callerId,
              ),
            ),
          );
        }
      // });
    }
  }
}