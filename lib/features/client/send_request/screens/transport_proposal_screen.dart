import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/send_request_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/widgets/nux_card.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/enums.dart';

class TransportProposalScreen extends ConsumerWidget {
  const TransportProposalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sendRequestProvider);
    final proposal = state.proposal;

    if (proposal == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Proposition')),
        body: const Center(child: Text('Aucune proposition disponible')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Transport trouvé')),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CompatibilityBadge(status: proposal.compatibilityStatus),
                  const SizedBox(height: 14),
                  Text(
                    formatPrice(proposal.price),
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          color: AppColors.of(context).textPrimary,
                          fontSize: 40,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    proposal.description,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Delivery time
                    NuxCard(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          const Icon(Icons.schedule_rounded,
                              color: AppColors.accent, size: 22),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Livraison estimée',
                                  style: Theme.of(context).textTheme.bodySmall),
                              const SizedBox(height: 2),
                              Text(
                                formatEta(proposal.estimatedArrival),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(color: AppColors.accent),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Transport details
                    NuxCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Détails du transport',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 16),
                          _DetailRow(
                            icon: Icons.local_shipping_rounded,
                            label: 'Transporteur',
                            value: proposal.description,
                            showVehicleImage: true,
                          ),
                          _DetailRow(
                            icon: Icons.scale_rounded,
                            label: 'Poids',
                            value: formatWeight(proposal.weightKg),
                          ),
                          _DetailRow(
                            icon: Icons.view_in_ar_rounded,
                            label: 'Volume',
                            value: formatVolume(proposal.volumeM3),
                          ),
                          _DetailRow(
                            icon: Icons.alt_route_rounded,
                            label: 'Impact trajet',
                            value: '+${formatDuration(proposal.routeImpact)}',
                            last: true,
                          ),
                        ],
                      ),
                    ),

                    // Warning for effort compatibility
                    if (proposal.compatibilityStatus ==
                        CompatibilityStatus.compatibleEffort) ...[
                      const SizedBox(height: 12),
                      NuxCard(
                        backgroundColor: AppColors.warning.withOpacity(0.08),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded,
                                color: AppColors.warning, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Ce transport nécessite un réagencement du chargement par le transporteur.',
                                style: const TextStyle(
                                    color: AppColors.warning,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500),
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

            // ── CTA ───────────────────────────────────────────────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.of(context).border)),
              ),
              child: Column(
                children: [
                  FilledButton(
                    onPressed: () async {
                      final request =
                          await ref.read(sendRequestProvider.notifier).confirm();
                      if (!context.mounted) return;
                      ref.read(sendRequestProvider.notifier).reset();
                      context.go('/client/tracking/${request?.id ?? 'new'}');
                    },
                    child: const Text('Confirmer l\'envoi'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () {
                      ref.read(sendRequestProvider.notifier).reset();
                      context.go('/client');
                    },
                    child: const Text('Annuler'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool last;
  final bool showVehicleImage;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.last = false,
    this.showVehicleImage = false,
  });

  Widget _buildVehicleImage(String desc) {
    final d = desc.toLowerCase();
    if (d.contains('vélo') || d.contains('velo')) return Image.asset('asset/veloCargo.png', height: 24);
    if (d.contains('fourgon') || d.contains('van')) return Image.asset('asset/fourgon.png', height: 24);
    if (d.contains('porteur') || d.contains('camion')) return Image.asset('asset/porteur.png', height: 24);
    return Image.asset('asset/fourgon.png', height: 24); // fallback
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              showVehicleImage ? _buildVehicleImage(value) : Icon(icon, size: 18, color: AppColors.of(context).textMuted),
              const SizedBox(width: 12),
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
