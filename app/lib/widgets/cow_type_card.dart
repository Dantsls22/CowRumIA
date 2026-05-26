import 'package:flutter/material.dart';
import '../models/recording_result.dart';
import '../theme/app_theme.dart';

class CowTypeCard extends StatelessWidget {
  final CowType type;
  final bool isSelected;
  final VoidCallback? onTap;

  const CowTypeCard({
    super.key,
    required this.type,
    required this.isSelected,
    required this.onTap,
  });

  String get _label => type == CowType.engorda ? 'ENGORDA' : 'LECHE';
  String get _emoji => type == CowType.engorda ? '🐂' : '🐄';
  String get _subtitle =>
      type == CowType.engorda ? 'Ganado de carne' : 'Ganado lechero';

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.surfaceVariant,
              width: isSelected ? 3 : 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_emoji, style: const TextStyle(fontSize: 36)),
              const SizedBox(height: 8),
              Text(
                _label,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _subtitle,
                style: TextStyle(
                  color: isSelected
                      ? const Color(0xFFB9F6CA)
                      : AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 10),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? Colors.white : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? Colors.white : AppColors.surfaceVariant,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: AppColors.primary,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
