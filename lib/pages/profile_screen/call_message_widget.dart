import 'package:flutter/material.dart';

class CallMessageWidget extends StatefulWidget {
  final String eventId;
  final String callerName;
  final String callerId;
  final String myId;
  final int timestamp; // Время сообщения, чтобы не открывать звонок из старой истории

  const CallMessageWidget({
    Key? key,
    required this.eventId,
    required this.callerName,
    required this.callerId,
    required this.myId,
    required this.timestamp,
  }) : super(key: key);

  @override
  State<CallMessageWidget> createState() => _CallMessageWidgetState();
}

class _CallMessageWidgetState extends State<CallMessageWidget> {
  @override
  void initState() {
    super.initState();
    
    // ПРОВЕРКА ДЛЯ АВТОЗАПУСКА:
    // Звонок входящий (не мой) И сообщение прилетело прямо сейчас (например, меньше 30 секунд назад)
    final isIncoming = widget.callerId != widget.myId;
    final isFresh = (DateTime.now().millisecondsSinceEpoch - widget.timestamp).abs() < 30000;

    // if (isIncoming && isFresh) {
    //   // Дожидаемся окончания текущего кадра отрисовки Flutter и пушим экран звонка
    //   WidgetsBinding.instance.addPostFrameCallback((_) {
    //     if (mounted) {
    //       Navigator.push(
    //         context,
    //         MaterialPageRoute(
    //           builder: (context) => IncomingCallPage(
    //             callEventId: widget.eventId,
    //             callerName: widget.callerName,
    //             participantId: widget.myId,
    //             targetParticipantId: widget.callerId,
    //           ),
    //         ),
    //       );
    //     }
    //   });
    // }
  }

  @override
  Widget build(BuildContext context) {
    // Тут просто рисуем плашку «Голосовой звонок» для истории чата
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.phone_in_talk, color: Colors.green),
          const SizedBox(width: 12),
          Text('Голосовой звонок от ${widget.callerName}'),
        ],
      ),
    );
  }
}