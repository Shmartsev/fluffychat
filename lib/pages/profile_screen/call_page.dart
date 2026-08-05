import 'package:fluffychat/utils/additional_api/additional_api.dart';
import 'package:fluffychat/utils/livekit/call_screen.dart';
import 'package:fluffychat/utils/livekit/livekit_call_handler.dart';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

class CallPage extends StatefulWidget {
  final String url;
  final String token;
  final String myId;
  final String peerId;
  final String peerName;
  

  const CallPage({
    Key? key,
    required this.url,
    required this.token,
    required this.myId,
    required this.peerId,
    required this.peerName,
    //required this.callEventId,
    
  }) : super(key: key);

  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> {
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  
  // bool _isConnected = false;
  // bool _isPeerJoined = false;
  bool _isDisconnecting = false;

  String _statusText = 'Инициализация...';

  @override
  void initState() {
    super.initState();
    // Инициализируем строго после прорисовки UI, чтобы избежать ANR
    WidgetsBinding.instance.addPostFrameCallback((_) => _initLiveKit());
  }

  Future<void> _initLiveKit() async {
    LiveKitCallHandler.initForegroundTask();
    await LiveKitCallHandler.startCallService();
    
    if (lkPlatformIsMobile()) {
      await Hardware.instance.setSpeakerphoneOn(false);
    }

    try {
      setState(() => _statusText = 'Соединение с сервером...');
      final room = Room(roomOptions: RoomOptions(
        adaptiveStream: true,
        dynacast: true,
        defaultAudioOutputOptions: AudioOutputOptions(
          speakerOn: false, // Принудительно выключаем громкую связь на старте
        ),
      ));
      _room = room;
      _listener = room.createListener();

     _listener?.on<ParticipantConnectedEvent>((event) {
        _switchToActiveCallScreen();
      });

      _listener?.on<ParticipantDisconnectedEvent>((_) => _disconnectAndExit());
      
      setState(() => _statusText = 'Подключаюсь...');
      
      await room.connect(widget.url, widget.token);
      await room.localParticipant?.setMicrophoneEnabled(true);
      setState(() => _statusText = '${widget.peerName} подключается...');
    } catch (e) {
      print('Ошибка LiveKit: $e');
      _disconnectAndExit();
    }
  }

  void _switchToActiveCallScreen() {
    if (!mounted || _room == null) return;

    // Снимаем listener, чтобы он не сработал повторно
    _listener?.dispose();
    _listener = null;

    // Подменяем CallPage на CallScreen, передавая созданную комнату Room
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => CallScreen(
          callerName: widget.peerName,
          room: _room!, // Передаем живую сессию WebRTC
          onEndCall: () async {
            await _room?.disconnect();
            await AdditionalApi.instance.hangupCall(
              participantId: widget.myId,
              targetParticipantId: widget.peerId,
            );
            LiveKitCallHandler.stopCallService();
            if (Navigator.canPop(context)) {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
    );
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
      LiveKitCallHandler.stopCallService();
    } catch (e) {
      print("Ошибка при закрытии WebRTC: $e");
    } finally {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _listener?.dispose();
    //_room?.disconnect();
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
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.white12,
              child: Text(
                widget.peerName.isNotEmpty ? widget.peerName[0].toUpperCase() : '?',
                style: const TextStyle(fontSize: 40, color: Colors.white),
              ),
            ),
            Text(
              widget.peerName,
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _statusText,
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