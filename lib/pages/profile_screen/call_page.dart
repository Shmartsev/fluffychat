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
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  
  bool _isConnected = false;
  bool _isPeerJoined = false;
  bool _isDisconnecting = false;

  @override
  void initState() {
    super.initState();
    // Инициализируем строго после прорисовки UI, чтобы избежать ANR
    WidgetsBinding.instance.addPostFrameCallback((_) => _initLiveKit());
  }

  Future<void> _initLiveKit() async {
    try {
      final room = Room(roomOptions: RoomOptions(
        adaptiveStream: true,
        dynacast: true,
      ));
      _room = room;
      _listener = room.createListener();

      // Магия звука #1: Принудительно включаем разговорный динамик на старте
      // if (lkPlatformIsMobile()) {
      //   await Hardware.instance.setSpeakerphoneOn(false);
      // }

      // Магия звука #2: Перехватываем публикацию аудио-трека собеседника
      // _listener?.on<TrackSubscribedEvent>((event) async {
      //   // Проверяем тип трека через строковое значение 'audio'
      //   if (event.track.kind.toString().contains('audio')) {
      //     print("🔊 Получен аудио-трек собеседника! Включаем воспроизведение.");
      //     try {
      //       await event.track.start(); 
      //     } catch (e) {
      //       print("Не удалось принудительно запустить трек: $e");
      //     }
      //   }
      // });

      // // Отслеживаем статус собеседника
      // _listener?.on<RoomEvent>((event) {
      //   if (!mounted) return;
      //   setState(() {
      //     _isPeerJoined = room.remoteParticipants.isNotEmpty;
      //   });
      // });

      //_listener?.on<ParticipantDisconnectedEvent>((_) => _disconnectAndExit());

      // Коннект
      
      await room.connect('wss://livekit.medgarant-spb.ru', widget.token);
      
      // Публикуем себя в аудиосеть
      await room.localParticipant?.setMicrophoneEnabled(true);
      //await room.localParticipant?.setCameraEnabled(false);
      
      if (mounted) {
        setState(() {
          _isConnected = true;
          _isPeerJoined = room.remoteParticipants.isNotEmpty;
        });
      }
    } catch (e) {
      print('Ошибка LiveKit: $e');
      _disconnectAndExit();
    }
  }

  Future<void> _disconnectAndExit() async {
    if (_isDisconnecting || !mounted) return;
    setState(() => _isDisconnecting = true);

    try {
      if (_room != null) {
        await _room!.localParticipant?.setMicrophoneEnabled(false);
        await _room!.disconnect();
      }
      await AdditionalApi.instance.hangupCall(
        participantId: widget.myId,
        targetParticipantId: widget.peerId,
      );
    } catch (e) {
      print("Ошибка при закрытии WebRTC: $e");
    } finally {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _listener?.dispose();
    _room?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person, size: 100, color: Colors.white54),
            const SizedBox(height: 24),
            Text(
              _isPeerJoined ? 'Разговор...' : 'Вызов...',
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              !_isConnected ? 'Подключение к серверу...' : (_isPeerJoined ? 'На связи' : 'Ожидание врача...'),
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 100),
            // Одна большая круглая кнопка сброса
            Center(
              child: FloatingActionButton(
                backgroundColor: Colors.redAccent,
                onPressed: _disconnectAndExit,
                child: const Icon(Icons.call_end, size: 32, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}