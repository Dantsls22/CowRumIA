import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class RecordButton extends StatelessWidget {
  final bool isRecording;
  final bool isEnabled;
  final VoidCallback? onPressed;

  const RecordButton({
    super.key,
    required this.isRecording,
    required this.isEnabled,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final Color bgColor = isEnabled ? AppColors.primary : AppColors.surfaceVariant;
    final Color iconColor = isEnabled ? Colors.white : AppColors.textSecondary;

    return GestureDetector(
      onTap: (!isRecording && isEnabled) ? onPressed : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 160,
        height: 160,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bgColor,
          boxShadow: isEnabled
              ? [BoxShadow(
                  color: bgColor.withOpacity(0.45),
                  blurRadius: 30,
                  spreadRadius: 4,
                  offset: const Offset(0, 8),
                )]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mic_rounded, size: 56, color: iconColor),
            const SizedBox(height: 6),
            Text(
              isRecording ? 'GRABANDO...' : 'ESCUCHAR',
              style: TextStyle(
                color: iconColor,
                fontWeight: FontWeight.w900,
                fontSize: 13,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}