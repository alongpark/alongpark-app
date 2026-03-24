import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/driver_dashboard_provider.dart';
import '../../missions/providers/missions_provider.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/widgets/nux_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/enums.dart';

class DriverDashboardScreen extends ConsumerWidget {
  const DriverDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    if (user == null) return const SizedBox();

    final truckAsync = ref.watch(truckStateProvider(user.id));
    final opportunitiesAsync =
        ref.watch(opportunitiesProvider(user.id));

    return Scaffold(
      backgroundColor: AppColors.of(context).surface,
      body: CustomScrollView(
        slivers: [
          // ── Header ─────────────────────────────────────────────────────
          SliverAppBar(
            toolbarHeight: 56,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            pinned: true,
            title: Text(
              user.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            actions: [
              Consumer(builder: (context, ref, _) {
                final mode = ref.watch(themeModeProvider);
                final isDark = mode == ThemeMode.dark;
                return IconButton(
                  icon: Icon(
                    isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    size: 20,
                  ),
                  onPressed: () => ref.read(themeModeProvider.notifier).state =
                      isDark ? ThemeMode.light : ThemeMode.dark,
                );
              }),
              IconButton(
                icon: const Icon(Icons.logout_rounded, size: 20),
                onPressed: () {
                  ref.read(authProvider.notifier).logout();
                  context.go('/role');
                },
              ),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Truck state ──────────────────────────────────────────
                truckAsync.when(
                  loading: () => const Center(
                      child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  )),
                  error: (e, _) => Text('Erreur : $e'),
                  data: (truck) => Column(
                    children: [
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _DashTile(
                                icon: Icons.location_on_rounded,
                                label: 'Position',
                                value: truck.currentLocation,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _DashTile(
                                icon: Icons.schedule_rounded,
                                label: 'ETA',
                                value: formatEta(truck.eta),
                                valueColor: AppColors.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      NuxCard(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.view_in_ar_rounded,
                                    size: 16, color: AppColors.of(context).textMuted),
                                const SizedBox(width: 8),
                                Text('Espace libre',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge),
                                const Spacer(),
                                Text(
                                  formatVolume(truck.freeVolumeM3),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(color: AppColors.accent),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            LinearProgressIndicator(
                              value: truck.fillPercent / 100,
                              backgroundColor: AppColors.of(context).border,
                              valueColor: AlwaysStoppedAnimation(
                                truck.fillPercent > 80
                                    ? AppColors.warning
                                    : AppColors.accent,
                              ),
                              borderRadius: BorderRadius.circular(4),
                              minHeight: 6,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text(
                                  '${truck.fillPercent.toInt()}% rempli',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const Spacer(),
                                Text(
                                  '${formatWeight(truck.freeWeightKg)} restant',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ── Opportunities ────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: SectionHeader(
                        title: 'Opportunités',
                        subtitle: 'Missions proposées par l\'IA',
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push('/driver/missions'),
                      child: const Text('Tout voir'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                opportunitiesAsync.when(
                  loading: () => const Center(
                      child: CircularProgressIndicator()),
                  error: (e, _) => Text('Erreur : $e'),
                  data: (list) {
                    if (list.isEmpty) {
                      return NuxCard(
                        padding: const EdgeInsets.all(24),
                        child: const Center(
                          child: Text('Aucune opportunité pour l\'instant'),
                        ),
                      );
                    }
                    return Column(
                      children: list.take(2).toList().map((opp) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: NuxCard(
                            onTap: () => context
                                .push('/driver/missions/${opp.id}'),
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    StatusDot(
                                      color: opp.compatibilityStatus ==
                                              CompatibilityStatus.compatibleCertain
                                          ? AppColors.compatibleCertain
                                          : AppColors.compatibleEffort,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        opp.description,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(fontSize: 14),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Text(
                                      '+${formatPrice(opp.additionalRevenue)}',
                                      style: const TextStyle(
                                        color: AppColors.compatibleCertain,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '· +${formatDuration(opp.routeImpact)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                    const Spacer(),
                                    Icon(Icons.chevron_right_rounded,
                                        size: 18,
                                        color: AppColors.of(context).textMuted),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),

                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () =>
                      context.push('/driver/incident', extra: 'current-mission'),
                  icon: const Icon(Icons.flag_outlined, size: 18),
                  label: const Text('Signaler un incident'),
                ),
              ]),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/driver/map'),
        elevation: 4,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.map_rounded, color: Colors.white),
        label: const Text('Carte Tactique', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _DashTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DashTile({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return NuxCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.of(context).textMuted),
          const SizedBox(height: 8),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 3),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: valueColor ?? AppColors.of(context).textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
