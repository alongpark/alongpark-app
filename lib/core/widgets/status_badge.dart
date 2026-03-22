import 'package:flutter/material.dart';
import '../../shared/models/enums.dart';
import '../theme/app_colors.dart';

class StatusDot extends StatelessWidget {
  final Color color;
  final double size;

  const StatusDot({super.key, required this.color, this.size = 8});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class CompatibilityBadge extends StatelessWidget {
  final CompatibilityStatus status;

  const CompatibilityBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = switch (status) {
      CompatibilityStatus.compatibleCertain => (
          AppColors.compatibleCertain,
          Icons.check_circle_rounded,
          'Compatible certain',
        ),
      CompatibilityStatus.compatibleEffort => (
          AppColors.compatibleEffort,
          Icons.warning_amber_rounded,
          'Avec effort',
        ),
      CompatibilityStatus.rejected => (
          AppColors.rejected,
          Icons.cancel_rounded,
          'Rejeté',
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class ShipmentStatusBadge extends StatelessWidget {
  final ShipmentStatus status;

  const ShipmentStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      ShipmentStatus.created => (AppColors.of(context).textMuted, 'Créé'),
      ShipmentStatus.analyzing => (AppColors.warning, 'Analyse…'),
      ShipmentStatus.matched => (AppColors.accent, 'Transport trouvé'),
      ShipmentStatus.confirmed => (AppColors.accent, 'Confirmé'),
      ShipmentStatus.pickedUp => (AppColors.primary, 'Pris en charge'),
      ShipmentStatus.inTransit => (AppColors.primary, 'En transit'),
      ShipmentStatus.delivered => (AppColors.compatibleCertain, 'Livré'),
      ShipmentStatus.issue => (AppColors.danger, 'Incident'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}
