import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Base card used throughout the app
class NuxCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;

  const NuxCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor ?? AppColors.of(context).cardBg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: padding ?? const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.of(context).border, width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Section header with optional subtitle
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}

/// Stat tile used in driver dashboard
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final IconData? icon;

  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return NuxCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: AppColors.of(context).textMuted),
            const SizedBox(height: 8),
          ],
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: valueColor ?? AppColors.of(context).textPrimary,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
