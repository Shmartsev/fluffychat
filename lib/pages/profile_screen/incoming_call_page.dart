import 'package:fluffychat/utils/additional_api/additional_api.dart';
import 'package:flutter/material.dart';

class IncomingCallPage extends StatefulWidget {
  final String roomId; // ID комнаты в Matrix, чтобы не открывать звонок из старой истории
  final String callEventId; // ID события звонка в Matrix, чтобы не открывать звонок из старой истории
  final String callerName;
  final String participantId;       // Мой ID
  final String targetParticipantId; // ID звонящего

  const IncomingCallPage({
    Key? key,
    required this.roomId,
    required this.callEventId,
    required this.callerName,
    required this.participantId,
    required this.targetParticipantId,
  }) : super(key: key);

  @override
  State<IncomingCallPage> createState() => _IncomingCallPageState();
}

class _IncomingCallPageState extends State<IncomingCallPage> {
  bool _isProcessing = false;

  // Пользователь принял вызов
  void _acceptCall() async {
    setState(() => _isProcessing = true);
    try {
      // 1. Получаем токен для этой же комнаты
      final callData = await AdditionalApi.instance.createCallToken(
        participantId: widget.participantId,
        targetParticipantId: widget.targetParticipantId,
        participantName: 'Пользователь', // Или твое имя из Matrix
      );

      if (!mounted) return;

      if (mounted) {
        Navigator.of(context).pop(true); 
      }

      // 2. Заменяем экран входящего звонка на активную CallPage
      // Navigator.pushReplacement(
      //   context,
      //   MaterialPageRoute(
      //     builder: (context) => CallPage(
      //       url: callData['server_url'],
      //       token: callData['token'],
      //       myId: widget.participantId,
      //       peerId: widget.targetParticipantId,
      //       callEventId: widget.callEventId,
      //     ),
      //   ),
      // );
    } catch (e) {
      _rejectCall();
    }
  }

  // Пользователь отклонил вызов
  void _rejectCall() async {
    // Отправляем сигнал "hangup" на бэк, чтобы у звонящего тоже прекратился вызов
    try {
      await AdditionalApi.instance.hangupCall(
        participantId: widget.participantId,
        targetParticipantId: widget.targetParticipantId,
      );
    } catch (_) {}

    if (mounted) {
      Navigator.of(context).pop(false); // Закрываем экран входящего звонка
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            
            // Информация о звонящем
            Column(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(Icons.person, size: 60, color: theme.colorScheme.onPrimaryContainer),
                ),
                const SizedBox(height: 32),
                Text(
                  widget.callerName,
                  style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Входящий аудиозвонок...',
                  style: TextStyle(fontSize: 16, color: Colors.green, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            
            const Spacer(),

            // Кнопки управления (Две круглые кнопки: Красная и Зеленая)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48.0, vertical: 40.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Сбросить
                  IconButton(
                    icon: const Icon(Icons.call_end, size: 36),
                    color: Colors.white,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.all(20),
                    ),
                    onPressed: _isProcessing ? null : _rejectCall,
                  ),
                  
                  // Принять
                  IconButton(
                    icon: _isProcessing 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Icon(Icons.call, size: 36),
                    color: Colors.white,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.all(20),
                    ),
                    onPressed: _isProcessing ? null : _acceptCall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}