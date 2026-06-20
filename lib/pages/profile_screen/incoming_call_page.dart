import 'package:fluffychat/utils/livekit/livekit_call_handler.dart';
import 'package:flutter/material.dart';

class IncomingCallPage extends StatefulWidget {
  final String callerName;
  final String url;
  final String token;
  
  const IncomingCallPage({
    Key? key,
    required this.callerName,
    required this.url,
    required this.token,
  }) : super(key: key);

  @override
  State<IncomingCallPage> createState() => _IncomingCallPageState();
}

class _IncomingCallPageState extends State<IncomingCallPage> {
  //bool _isProcessing = false;
  bool _isAccepted = false;

  @override
  void initState() {
    super.initState();
    
    // СЮДА: Регистрируем фоновую функцию закрытия экрана
    LiveKitCallHandler.onPeerDisconnected = () {
      if (mounted) {
        print("📉 UI поймал сигнал дисконнекта. Закрываем экран.");
        Navigator.of(context).pop();
      }
    };
  }

  @override
  void dispose() {
    // ОБЯЗАТЕЛЬНО: Очищаем ссылку при уничтожении экрана, 
    // чтобы хэндлер не держал мертвый контекст старого виджета
    LiveKitCallHandler.onPeerDisconnected = null;
    super.dispose();
  }

  void _handleAccept() async {
    setState(() {
      _isAccepted = true;
    });
    await LiveKitCallHandler.connectActiveCall(widget.url, widget.token);
  }

  void _handleReject() async {
    // Гасим нативный слой и уведомляем Django
    await LiveKitCallHandler.hangupActiveCall();
    
    if (mounted) {
      Navigator.of(context).pop(); // Просто закрываем экран звонка
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Блок информации о пользователе
            Column(
              children: [
                const CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.person, size: 60, color: Colors.white),
                ),
                const SizedBox(height: 24),
                Text(
                  widget.callerName,
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  _isAccepted ? "Идет разговор..." : "Входящий аудиозвонок...",
                  style: TextStyle(color: _isAccepted ? Colors.greenAccent : Colors.white70, fontSize: 18),
                ),
              ],
            ),

            // Блок управления кнопками (динамически меняется)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!_isAccepted) ...[
                  // Кнопка "Принять" (показывается только ДО принятия)
                  FloatingActionButton(
                    heroTag: "accept_btn",
                    backgroundColor: Colors.green,
                    onPressed: _handleAccept,
                    child: const Icon(Icons.call, size: 30, color: Colors.white),
                  ),
                  const SizedBox(width: 64),
                ],
                
                // Кнопка "Сбросить" (есть всегда)
                FloatingActionButton(
                  heroTag: "reject_btn",
                  backgroundColor: Colors.redAccent,
                  onPressed: _handleReject,
                  child: const Icon(Icons.call_end, size: 30, color: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}