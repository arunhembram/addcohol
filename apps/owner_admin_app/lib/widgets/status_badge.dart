import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../config/translations.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final bool isLarge;

  const StatusBadge({super.key, required this.status, this.isLarge = false});

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<AppLocaleProvider>(context);

    Color bgColor;
    Color textColor;
    Color dotColor;
    String labelKey;

    switch (status.toLowerCase()) {
      case 'verified':
        bgColor = AppTheme.statusGreenLight;
        textColor = const Color(0xFF15803D);
        dotColor = AppTheme.statusGreen;
        labelKey = 'status_verified';
        break;
      case 'submitted':
        bgColor = const Color(0xFFE0F2FE); // Blue light
        textColor = const Color(0xFF0369A1);
        dotColor = const Color(0xFF0284C7);
        labelKey = 'status_submitted';
        break;
      case 'not_uploaded':
        bgColor = AppTheme.statusYellowLight;
        textColor = const Color(0xFFB45309);
        dotColor = AppTheme.statusYellow;
        labelKey = 'status_not_uploaded';
        break;
      case 'rejected':
        bgColor = AppTheme.statusRedLight;
        textColor = const Color(0xFFB91C1C);
        dotColor = AppTheme.statusRed;
        labelKey = 'status_rejected';
        break;
      case 'active':
        bgColor = AppTheme.statusGreenLight;
        textColor = const Color(0xFF15803D);
        dotColor = AppTheme.statusGreen;
        labelKey = 'status_active';
        break;
      case 'inactive':
      case 'archived':
      case 'expired':
      default:
        bgColor = AppTheme.statusGreyLight;
        textColor = const Color(0xFF4B5563);
        dotColor = AppTheme.statusGrey;
        labelKey = 'status_$status';
        break;
    }

    final label = localeProvider.t(labelKey);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isLarge ? 12 : 8, vertical: isLarge ? 6 : 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: dotColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: isLarge ? 8 : 6,
            height: isLarge ? 8 : 6,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: isLarge ? 13 : 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
