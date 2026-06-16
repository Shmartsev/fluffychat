import 'package:flutter/material.dart';

class CallMessageWidget extends StatelessWidget {
  final String callerName;

  const CallMessageWidget({
    Key? key,
    required this.callerName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Чистый stateless-виджет: просто рисуем статичную плашку в ленте сообщений
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min, // Чтобы плашка не растягивалась на весь экран
        children: [
          const Icon(Icons.phone_in_talk, color: Colors.green),
          const SizedBox(width: 12),
          Text(
            'Голосовой звонок от $callerName'
          ),
        ],
      ),
    );
  }
}