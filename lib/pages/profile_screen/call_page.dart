import 'package:fluffychat/utils/additional_api/additional_api.dart';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

class CallPage extends StatefulWidget {
  final String url;
  final String token;
  final String myId;
  final String peerId;
  final String callEventId;

  const CallPage({
    Key? key,
    required this.url,
    required this.token,
    required this.myId,
    required this.peerId,
    required this.callEventId,
  }) : super(key: key);

  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> {
  late final Room room;
  late final EventsListener<RoomEvent> _listener;
  
  bool _isConnected = false;
  bool _isSpeakerOn = false;
  bool _isPeerJoined = false;

  bool _isDisconnecting = false;

  @override
  void initState() {
    super.initState();
    _initLiveKit();
  }

  Future<void> _initLiveKit() async {
    room = Room();
    _listener = room.createListener();

    if (lkPlatformIsMobile()) {
      await Hardware.instance.setSpeakerphoneOn(false);
    }

    _updatePeerStatus();

    // Слушаем появление/уход собеседника в комнате
    _listener.on<RoomEvent>((event) {
      setState(_updatePeerStatus);
    });

    _listener.on<ParticipantDisconnectedEvent>((event) {
      print("Собеседник отключился от WebRTC сессии");
      _disconnectAndExit();
    });

    try {
      await room.connect(widget.url, widget.token);
      
      // Публикуем ТОЛЬКО аудио
      await room.localParticipant?.setMicrophoneEnabled(true);
      await room.localParticipant?.setCameraEnabled(false);

      setState(() {
        _isConnected = true;
      });
    } catch (e) {
      print('Ошибка подключения к LiveKit Audio: $e');
      _showErrorDialog();
    }
  }

  Future<void> _disconnectAndExit() async {
    // Защита от двойного тапа по кнопке
    if (_isDisconnecting) return; 
    setState(() => _isDisconnecting = true);

    try {
      // 1. Глушим микрофон
      await room.localParticipant?.setMicrophoneEnabled(false);
      
      // 2. Выходим из комнаты LiveKit (это автоматически пошлет 
      //    сигнал ParticipantDisconnectedEvent на то устройство, которое еще сидит в звонке)
      await room.disconnect();
      
      // 3. Стучимся на Django, чтобы перевести статус звонка в БД в "завершен"
      if (widget.myId != null && widget.peerId != null) {
        await AdditionalApi.instance.hangupCall(
          participantId: widget.myId!,
          targetParticipantId: widget.peerId!,
        );
      }
    } catch (e) {
      print("Ошибка при очистке ресурсов WebRTC: $e");
    } finally {
      _closeScreen();
    }
  }

  void _closeScreen() {
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _updatePeerStatus() {
    // Если в удаленных участниках кто-то есть — значит собеседник подключился
    _isPeerJoined = room.remoteParticipants.isNotEmpty;
  }

  @override
  void dispose() {
    _listener.dispose();
    room.disconnect();
    super.dispose();
  }

  // Переключение аудио-выхода (спикер / разговорный динамик)
  void _toggleSpeaker() async {
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
    // Переключаем встроенный хардварный роутинг звука через LiveKit
    await Hardware.instance.setSpeakerphoneOn(_isSpeakerOn);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMicOn = room.localParticipant != null && !room.localParticipant!.isMuted;

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            
            // 1. Аватар и статус звонка тет-а-тет
            Center(
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Пульсирующий круг, если собеседник на связи
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isPeerJoined 
                              ? theme.colorScheme.primary.withAlpha(25) 
                              : theme.colorScheme.surfaceContainerHigh,
                        ),
                      ),
                      CircleAvatar(
                        radius: 55,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Icon(
                          Icons.person, 
                          size: 55, 
                          color: theme.colorScheme.onPrimaryContainer
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Статус-текст
                  Text(
                    _isPeerJoined ? 'Голосовой звонок' : 'Вызов...',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    !_isConnected 
                        ? 'Подключение...' 
                        : (_isPeerJoined ? 'На связи' : 'Ожидание собеседника...'),
                    style: TextStyle(
                      fontSize: 14, 
                      color: theme.colorScheme.onSurfaceVariant.withAlpha(180)
                    ),
                  ),
                ],
              ),
            ),
            
            const Spacer(),
            
            // 2. Панель кнопок (Микрофон, Сброс, Громкая связь)
            Padding(
              padding: const EdgeInsets.only(bottom: 40.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Кнопка микрофона (Mute/Unmute)
                  _buildCallButton(
                    icon: isMicOn ? Icons.mic_rounded : Icons.mic_off_rounded,
                    isActive: isMicOn,
                    onPressed: () {
                      if (room.localParticipant != null) {
                        room.localParticipant!.setMicrophoneEnabled(!isMicOn);
                        setState(() {}); // Обновляем UI микрофона
                      }
                    },
                    theme: theme,
                  ),
                  const SizedBox(width: 32),
                  
                  // Кнопка СБРОСА (Выход) — Красная, большая
                  IconButton(
                    icon: const Icon(Icons.call_end_rounded, size: 32),
                    color: Colors.white,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.all(20),
                      elevation: 4,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 32),
                  
                  // Кнопка Громкой связи (Speakerphone)
                  _buildCallButton(
                    icon: _isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                    isActive: _isSpeakerOn,
                    onPressed: _toggleSpeaker,
                    theme: theme,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Хелпер для боковых кнопок управления
  Widget _buildCallButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onPressed,
    required ThemeData theme,
  }) {
    return IconButton(
      icon: Icon(icon, size: 26),
      color: isActive ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface,
      style: IconButton.styleFrom(
        backgroundColor: isActive 
            ? theme.colorScheme.primaryContainer 
            : theme.colorScheme.surfaceContainerHigh,
        padding: const EdgeInsets.all(16),
      ),
      onPressed: onPressed,
    );
  }

  void _showErrorDialog() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Ошибка аудиосети'),
        content: const Text('Не удалось установить соединение для звонка.'),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('ОК'))],
      ),
    ).then((_) {
      if (mounted) Navigator.pop(context);
    });
  }
}