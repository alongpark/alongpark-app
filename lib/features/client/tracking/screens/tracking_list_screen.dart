import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/tracking_provider.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../shared/models/shipment_request.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/widgets/nux_card.dart';
import '../../../../core/utils/formatters.dart';

class TrackingListScreen extends ConsumerWidget {
  const TrackingListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    if (user == null) return const SizedBox();

    final async = ref.watch(trackingProvider(user.id));

    return Scaffold(
      appBar: AppBar(title: const Text('Mes envois')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (shipments) {
          if (shipments.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_rounded, size: 64, color: AppColors.of(context).textMuted),
                  const SizedBox(height: 16),
                  const Text('Aucun envoi pour l\'instant'),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: shipments.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) =>
                _ShipmentTile(shipment: shipments[i]),
          );
        },
      ),
    );
  }
}

class _ShipmentTile extends StatelessWidget {
  final ShipmentRequest shipment;
  const _ShipmentTile({required this.shipment});

  @override
  Widget build(BuildContext context) {
    return NuxCard(
      onTap: () => context.push('/client/tracking/${shipment.id}'),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  shipment.destination,
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ShipmentStatusBadge(status: shipment.status),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.scale_rounded, size: 14, color: AppColors.of(context).textMuted),
              const SizedBox(width: 4),
              Text(formatWeight(shipment.estimatedWeightKg),
                  style: Theme.of(context).textTheme.bodySmall),
              if (shipment.estimatedType != null) ...[
                const SizedBox(width: 12),
                Icon(Icons.inventory_2_outlined,
                    size: 14, color: AppColors.of(context).textMuted),
                const SizedBox(width: 4),
                Text(shipment.estimatedType!,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
              const Spacer(),
              Text(
                formatDateShort(shipment.createdAt),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
