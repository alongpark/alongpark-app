import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/missions_provider.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/widgets/nux_card.dart';
import '../../../../core/utils/formatters.dart';

class MissionDetailScreen extends ConsumerWidget {
  final String opportunityId;
  const MissionDetailScreen({super.key, required this.opportunityId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    if (user == null) return const SizedBox();
    final async = ref.watch(opportunitiesProvider(user.id));

    return Scaffold(
      appBar: AppBar(title: const Text('Opportunité')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          final opp = list.cast<dynamic>().firstWhere(
            (o) => o.id == opportunityId,
            orElse: () => null,
          );

          if (opp == null) {
            return const Center(child: Text('Mission introuvable'));
          }

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status + Revenue header
                      NuxCard(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CompatibilityBadge(
                                status: opp.compatibilityStatus),
                            const SizedBox(height: 14),
                            Text(
                              '+${formatPrice(opp.additionalRevenue)}',
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                color: AppColors.compatibleCertain,
                                letterSpacing: -1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Revenu additionnel estimé',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Route
                      NuxCard(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Trajet',
                                style:
                                    Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Column(
                                  children: [
                                    const Icon(Icons.circle_rounded,
                                        size: 10,
                                        color: AppColors.accent),
                                    Container(
                                        width: 1.5,
                                        height: 32,
                                        color: AppColors.of(context).border),
                                    const Icon(Icons.location_on_rounded,
                                        size: 18,
                                        color: AppColors.primary),
                                  ],
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('Prise en charge',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall),
                                          Text(opp.pickupLocation,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium
                                                  ?.copyWith(fontSize: 14)),
                                        ],
                                      ),
                                      const SizedBox(height: 20),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('Livraison',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall),
                                          Text(opp.deliveryDestination,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium
                                                  ?.copyWith(fontSize: 14)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Cargo details
                      NuxCard(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Marchandise',
                                style:
                                    Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 14),
                            _DetailRow(
                                label: 'Type',
                                value: opp.merchandiseType),
                            _DetailRow(
                                label: 'Poids',
                                value: formatWeight(opp.weightKg)),
                            _DetailRow(
                                label: 'Volume',
                                value: formatVolume(opp.volumeM3)),
                            _DetailRow(
                                label: 'Impact trajet',
                                value:
                                    '+${formatDuration(opp.routeImpact)}',
                                last: true),
                          ],
                        ),
                      ),

                      if (opp.requiresRearrangement) ...[
                        const SizedBox(height: 12),
                        NuxCard(
                          backgroundColor:
                              AppColors.warning.withOpacity(0.08),
                          padding: const EdgeInsets.all(16),
                          child: const Row(
                            children: [
                              Icon(Icons.warning_amber_rounded,
                                  color: AppColors.warning, size: 20),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Réagencement du chargement requis avant de charger cette marchandise.',
                                  style: TextStyle(
                                    color: AppColors.warning,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      
                      if (opp.clientVoiceInstruction != null) ...[
                        const SizedBox(height: 12),
                        NuxCard(
                          backgroundColor: AppColors.primary.withOpacity(0.05),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.record_voice_over_rounded, color: AppColors.primary, size: 20),
                                  const SizedBox(width: 8),
                                  Text('Consigne vocale (IA)', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.primary)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                opp.clientVoiceInstruction!,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 14,
                                  fontStyle: FontStyle.italic,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // ── CTA ────────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border:
                      Border(top: BorderSide(color: AppColors.of(context).border)),
                ),
                child: Column(
                  children: [
                    FilledButton(
                      onPressed: () {
                        // Navigate to e-CMR signature
                        context.push('/driver/missions/${opp.id}/ecmr');
                      },
                      child: const Text('Accepter et générer l\'e-CMR'),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              await ref
                                  .read(opportunitiesProvider(user.id)
                                      .notifier)
                                  .refuse(opp.id);
                              if (!context.mounted) return;
                              context.pop();
                            },
                            child: const Text('Refuser'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                context.push('/driver/incident',
                                    extra: opp.id),
                            child: const Text('Besoin de détail'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool last;
  const _DetailRow(
      {required this.label, required this.value, this.last = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
              const Spacer(),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.of(context).textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
        if (!last) const Divider(height: 1),
      ],
    );
  }
}
