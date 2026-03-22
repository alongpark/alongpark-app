import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';

String formatPrice(double price) =>
    NumberFormat.currency(locale: 'fr_FR', symbol: '€', decimalDigits: 2)
        .format(price);

String formatWeight(double kg) =>
    kg >= 1000 ? '${(kg / 1000).toStringAsFixed(1)} t' : '${kg.toInt()} kg';

String formatVolume(double m3) => '${m3.toStringAsFixed(1)} m³';

String formatEta(DateTime eta) {
  final now = DateTime.now();
  final diff = eta.difference(now);
  if (diff.inHours >= 1) return 'Dans ${diff.inHours}h${diff.inMinutes % 60 > 0 ? '${diff.inMinutes % 60}min' : ''}';
  if (diff.inMinutes >= 1) return 'Dans ${diff.inMinutes} min';
  return 'Imminent';
}

String formatDateTime(DateTime dt) =>
    DateFormat('d MMM · HH:mm', 'fr_FR').format(dt);

String formatDateShort(DateTime dt) =>
    DateFormat('d MMM', 'fr_FR').format(dt);

String formatDuration(Duration d) {
  if (d.inHours >= 1) {
    return '${d.inHours}h ${d.inMinutes % 60}min';
  }
  return '${d.inMinutes} min';
}

String formatConfidence(double score) =>
    'Confiance ${(score * 100).toInt()}%';

Color getConfidenceColor(double score) {
  if (score >= 0.80) return AppColors.compatibleCertain;
  if (score >= 0.60) return AppColors.compatibleEffort;
  return AppColors.danger;
}
