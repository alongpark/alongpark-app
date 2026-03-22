import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/nux_card.dart';

class ClientHomeScreen extends ConsumerWidget {
  const ClientHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.of(context).surface,
      body: CustomScrollView(
        slivers: [
          // ── Header ────────────────────────────────────────────────────
          SliverAppBar(
            toolbarHeight: 56,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            pinned: true,
            title: Text(
              'Bonjour, ${user?.name.split(' ').first ?? '—'}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout_rounded, size: 20),
                onPressed: () {
                  ref.read(authProvider.notifier).logout();
                  context.go('/role');
                },
              ),
            ],
          ),

          // ── Main actions ───────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _BigActionCard(
                  icon: Icons.send_rounded,
                  label: 'Envoyer une marchandise',
                  description: 'Photo → transport en quelques secondes',
                  color: AppColors.accent,
                  backgroundColor: AppColors.primary,
                  onTap: () => context.push('/client/scan'),
                ),
                const SizedBox(height: 12),
                _BigActionCard(
                  icon: Icons.radar_rounded,
                  label: 'Suivre mes envois',
                  description: 'Statuts et localisation en temps réel',
                  color: AppColors.primary,
                  backgroundColor: AppColors.of(context).surface,
                  isLight: true,
                  onTap: () => context.push('/client/tracking'),
                ),
                const SizedBox(height: 28),
                const SectionHeader(title: 'Récent', subtitle: 'Vos derniers envois'),
                const SizedBox(height: 14),
                _RecentItem(
                  destination: 'Lyon, 69003',
                  status: 'En transit',
                  statusColor: AppColors.primary,
                  date: 'Aujourd\'hui',
                  onTap: () => context.push('/client/tracking/ship-001'),
                ),
                const SizedBox(height: 10),
                _RecentItem(
                  destination: 'Marseille, 13008',
                  status: 'Livré',
                  statusColor: AppColors.compatibleCertain,
                  date: 'Hier',
                  onTap: () => context.push('/client/tracking/ship-002'),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _BigActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final Color backgroundColor;
  final bool isLight;
  final VoidCallback onTap;

  const _BigActionCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.backgroundColor,
    this.isLight = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isLight ? AppColors.of(context).textPrimary : Colors.white;
    final subColor = isLight
        ? AppColors.of(context).textSecondary
        : Colors.white.withOpacity(0.65);

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: isLight
                ? Border.all(color: AppColors.of(context).border)
                : null,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(isLight ? 0.1 : 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(color: subColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 18,
                  color: isLight ? AppColors.of(context).textMuted : Colors.white.withOpacity(0.4)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentItem extends StatelessWidget {
  final String destination;
  final String status;
  final Color statusColor;
  final String date;
  final VoidCallback onTap;

  const _RecentItem({
    required this.destination,
    required this.status,
    required this.statusColor,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return NuxCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.of(context).surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.local_shipping_rounded,
                size: 18, color: AppColors.of(context).textSecondary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(destination,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontSize: 14)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                          color: statusColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 5),
                    Text(status,
                        style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(width: 10),
                    Text('·  $date',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              size: 18, color: AppColors.of(context).textMuted),
        ],
      ),
    );
  }
}
