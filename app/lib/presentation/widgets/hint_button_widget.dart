import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class HintButtonWidget extends StatelessWidget {
  final int hintsRemaining;
  final VoidCallback? onTap;

  const HintButtonWidget({
    super.key,
    required this.hintsRemaining,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                Icons.lightbulb_rounded,
                color: onTap != null ? AppTheme.goldPrimary : AppTheme.textMuted,
                size: 22,
              ),
              if (hintsRemaining > 0)
                Positioned(
                  top: -6, right: -6,
                  child: Container(
                    width: 16, height: 16,
                    decoration: BoxDecoration(
                      color: AppTheme.accentCyan,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$hintsRemaining',
                        style: const TextStyle(
                          color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Hint',
            style: TextStyle(
              color: onTap != null ? AppTheme.textSecondary : AppTheme.textMuted,
              fontSize: 10, fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
