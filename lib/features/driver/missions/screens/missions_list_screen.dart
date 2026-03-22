import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/missions_provider.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../shared/models/transport_opportunity.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/widgets/nux_card.dart';
import '../../../../core/utils/formatters.dart';

class MissionsListScreen extends ConsumerWidget {
  const MissionsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    if (user == null) return const SizedBox();
    final async = ref.watch(opportunitiesProvider(user.id));

    return Scaffold(
      appBar: AppBar(title: const Text('Missions & Opportunités')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.task_alt_rounded,
                      size: 64, color: AppColors.of(context).textMuted),
                  const SizedBox(height: 16),
                  const Text('Aucune opportunité disponible'),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _OpportunityTile(opportunity: list[i]),
          );
        },
      ),
    );
  }
}

class _OpportunityTile extends StatelessWidget {
  final TransportOpportunity opportunity;
  const _OpportunityTile({required this.opportunity});

  @override
  Widget build(BuildContext context) {
    return NuxCard(
      onTap: () => context.push('/driver/missions/${opportunity.id}'),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CompatibilityBadge(status: opportunity.compatibilityStatus),
              const Spacer(),
              Text(
                '+${formatPrice(opportunity.additionalRevenue)}',
                style: const TextStyle(
                  color: AppColors.compatibleCertain,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            opportunity.description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.of(context).textPrimary,
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.location_on_outlined,
                  size: 13, color: AppColors.of(context).textMuted),
              const SizedBox(width: 4),
              Text(opportunity.pickupLocation,
                  style: Theme.of(context).textTheme.bodySmall),
              Icon(Icons.arrow_right_alt_rounded,
                  size: 16, color: AppColors.of(context).textMuted),
              Text(opportunity.deliveryDestination,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.add_road_rounded,
                  size: 13, color: AppColors.of(context).textMuted),
              const SizedBox(width: 4),
              Text(
                '+${formatDuration(opportunity.routeImpact)} sur votre trajet',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
