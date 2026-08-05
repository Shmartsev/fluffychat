import 'dart:async';

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

class CallScreen extends StatefulWidget {
  final String callerName;
  final Room room;
  final VoidCallback onEndCall;

  const CallScreen({
    super.key,
    required this.callerName,
    required this.room,
    required this.onEndCall,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  // Состояния кнопок
  bool _isMuted = false;
  bool _isSpeakerOn = false;

  // Таймер звонка
  Timer? _timer;
  int _secondsElapsed = 0;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _secondsElapsed++;
      });
    });
  }

  // Форматирование секунд в 00:00
  String get _formattedTime {
    final minutes = (_secondsElapsed ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsElapsed % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1A1C29),
              Color(0xFF0D0E15),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 1. Верхний блок: Аватар, Имя и Таймер
              Column(
                children: [
                  const SizedBox(height: 40),
                  // Аватар (Заглушка с инициалом)
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.blueAccent.withOpacity(0.2),
                    child: Text(
                      widget.callerName.isNotEmpty
                          ? widget.callerName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Имя абонента
                  Text(
                    widget.callerName,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Таймер вызова
                  Text(
                    _formattedTime,
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white70,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),

              // 2. Нижний блок: Панель управления (Mute, End Call, Speaker)
              Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Кнопка Mute (Микрофон)
                    _CallControlButton(
                      icon: _isMuted ? Icons.mic_off : Icons.mic,
                      label: 'Микрофон',
                      isActive: _isMuted,
                      activeColor: Colors.white,
                      activeIconColor: Colors.black,
                      onPressed: () {
                        setState(() {
                          _isMuted = !_isMuted;
                        });
                        // TODO: LiveKit -> room.localParticipant?.setMicrophoneEnabled(!_isMuted);
                        widget.room.localParticipant?.setMicrophoneEnabled(!_isMuted);
                      },
                    ),

                    // Кнопка Завершить звонок
                    _CallControlButton(
                      icon: Icons.call_end,
                      label: 'Сброс',
                      backgroundColor: Colors.redAccent,
                      iconColor: Colors.white,
                      iconSize: 36,
                      buttonSize: 72,
                      onPressed: widget.onEndCall,
                    ),

                    // Кнопка Громкая связь (Динамик)
                    _CallControlButton(
                      icon: _isSpeakerOn
                          ? Icons.volume_up
                          : Icons.volume_down_outlined,
                      label: 'Динамик',
                      isActive: _isSpeakerOn,
                      activeColor: Colors.white,
                      activeIconColor: Colors.black,
                      onPressed: () {
                        setState(() {
                          _isSpeakerOn = !_isSpeakerOn;
                        });
                        // TODO: LiveKit / Hardware audio route switch
                        if (lkPlatformIsMobile()) {
                          Hardware.instance.setSpeakerphoneOn(_isSpeakerOn);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Вспомогательный виджет для круглых кнопок управления
class _CallControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isActive;
  final Color? backgroundColor;
  final Color? activeColor;
  final Color? iconColor;
  final Color? activeIconColor;
  final double iconSize;
  final double buttonSize;

  const _CallControlButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isActive = false,
    this.backgroundColor,
    this.activeColor,
    this.iconColor,
    this.activeIconColor,
    this.iconSize = 28,
    this.buttonSize = 60,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBgColor = isActive
        ? (activeColor ?? Colors.white)
        : (backgroundColor ?? Colors.white.withOpacity(0.15));

    final effectiveIconColor = isActive
        ? (activeIconColor ?? Colors.black)
        : (iconColor ?? Colors.white);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(buttonSize / 2),
          child: Container(
            width: buttonSize,
            height: buttonSize,
            decoration: BoxDecoration(
              color: effectiveBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: iconSize,
              color: effectiveIconColor,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}