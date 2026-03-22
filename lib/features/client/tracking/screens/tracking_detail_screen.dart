import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/tracking_provider.dart';
import '../../../../shared/models/enums.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/widgets/nux_card.dart';
import '../../../../core/utils/formatters.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/api/api_client.dart';
import '../../../../features/auth/providers/auth_provider.dart';

final _trackingSteps = ShipmentStatus.values
    .where((s) =>
        s != ShipmentStatus.analyzing &&
        s != ShipmentStatus.created &&
        s != ShipmentStatus.issue)
    .toList();

class TrackingDetailScreen extends ConsumerStatefulWidget {
  final String shipmentId;
  const TrackingDetailScreen({super.key, required this.shipmentId});

  @override
  ConsumerState<TrackingDetailScreen> createState() => _TrackingDetailScreenState();
}

class _TrackingDetailScreenState extends ConsumerState<TrackingDetailScreen> {
  bool _cancelling = false;

  Future<void> _cancelShipment() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler l\'envoi'),
        content: const Text('Voulez-vous vraiment annuler cet envoi ? Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Non'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _cancelling = true);
    try {
      await ApiClient.post('/api/shipments/${widget.shipmentId}/cancel', {});
      
      final user = ref.read(authProvider);
      if (user != null) {
        ref.invalidate(trackingProvider(user.id));
      }
      ref.invalidate(shipmentDetailProvider(widget.shipmentId));
      
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _cancelling = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(shipmentDetailProvider(widget.shipmentId));

    return Scaffold(
      appBar: AppBar(title: const Text('Suivi')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (shipment) {
          final currentIdx = _trackingSteps.indexOf(shipment.status)
              .clamp(0, _trackingSteps.length - 1);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                NuxCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              shipment.destination,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          ShipmentStatusBadge(status: shipment.status),
                        ],
                      ),
                      if (shipment.recipientName != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          shipment.recipientName!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _InfoChip(
                            icon: Icons.scale_rounded,
                            label: formatWeight(shipment.estimatedWeightKg),
                          ),
                          const SizedBox(width: 8),
                          if (shipment.estimatedType != null)
                            _InfoChip(
                              icon: Icons.inventory_2_outlined,
                              label: shipment.estimatedType!,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Driver info
                if (shipment.assignedDriverId != null)
                  NuxCard(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person_rounded,
                              color: AppColors.primary, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Marc Dupont',
                                style: Theme.of(context).textTheme.titleMedium),
                            Text('Transporteur attribué',
                                style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.phone_rounded,
                              color: AppColors.accent),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 20),

                // Timeline
                Text('Progression',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                ...List.generate(_trackingSteps.length, (i) {
                  final step = _trackingSteps[i];
                  final isDone = i <= currentIdx;
                  final isActive = i == currentIdx;
                  final isLast = i == _trackingSteps.length - 1;

                  return _TimelineStep(
                    label: step.label,
                    isDone: isDone,
                    isActive: isActive,
                    isLast: isLast,
                  );
                }),

                const SizedBox(height: 20),

                // Driver on the way — barre animée
                if (shipment.status == ShipmentStatus.matched ||
                    shipment.status == ShipmentStatus.confirmed ||
                    shipment.status == ShipmentStatus.pickedUp ||
                    shipment.status == ShipmentStatus.inTransit)
                  NuxCard(
                    padding: const EdgeInsets.all(18),
                    child: _DriverProgressCard(
                      status: shipment.status,
                      driverName: 'Marc Dupont',
                      etaLabel: _etaLabel(shipment.status),
                    ),
                  ),

                // Cancel button
                if (shipment.status == ShipmentStatus.analyzing ||
                    shipment.status == ShipmentStatus.matched ||
                    shipment.status == ShipmentStatus.confirmed) ...[
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _cancelling ? null : _cancelShipment,
                      child: _cancelling
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.red,
                              ),
                            )
                          : const Text('Annuler l\'envoi'),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Helper ETA ────────────────────────────────────────────────────────────────
String _etaLabel(ShipmentStatus status) => switch (status) {
  ShipmentStatus.matched    => '45 min',
  ShipmentStatus.confirmed  => '30 min',
  ShipmentStatus.pickedUp   => '20 min',
  ShipmentStatus.inTransit  => '8 min',
  _                         => '–',
};

// ── Driver Progress Card ──────────────────────────────────────────────────────
class _DriverProgressCard extends StatelessWidget {
  final ShipmentStatus status;
  final String driverName;
  final String etaLabel;

  const _DriverProgressCard({
    required this.status,
    required this.driverName,
    required this.etaLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Transporteur en route',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
        ),
        const SizedBox(height: 3),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: etaLabel,
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              TextSpan(
                text: ' (Arrivée estimée)',
                style: TextStyle(
                  color: AppColors.primary.withValues(alpha: 0.65),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _AnimatedStripeBar(),
      ],
    );
  }
}

// ── Barre animée ──────────────────────────────────────────────────────────────
class _AnimatedStripeBar extends StatefulWidget {
  const _AnimatedStripeBar();

  @override
  State<_AnimatedStripeBar> createState() => _AnimatedStripeBarState();
}

class _AnimatedStripeBarState extends State<_AnimatedStripeBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const barHeight = 30.0;

    return SizedBox(
      height: barHeight,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          painter: _StripePainter(progress: _ctrl.value),
          child: Row(
            children: [
              // ── Icône gauche (flèche) ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(left: 5),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: AppColors.primary,
                    size: 13,
                  ),
                ),
              ),

              const Spacer(),

              // ── Cercle destination ────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(right: 5),
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── CustomPainter — fond bleu + rayures diagonales animées ───────────────────
class _StripePainter extends CustomPainter {
  final double progress; // 0→1 en boucle

  const _StripePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height / 2);
    final rrect  = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      radius,
    );

    // Fond bleu principal
    canvas.drawRRect(
      rrect,
      Paint()..color = AppColors.primary,
    );

    // Rayures diagonales animées
    canvas.save();
    canvas.clipRRect(rrect);

    final stripePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    const stripeWidth = 18.0;
    const stripeGap   = 22.0;
    const pitch       = stripeWidth + stripeGap;

    // Décalage animé : les rayures avancent vers la droite
    final offset = progress * pitch;

    for (double x = -size.height - pitch + offset; x < size.width + size.height; x += pitch) {
      // Parallélogramme incliné à 45°
      final path = Path()
        ..moveTo(x, 0)
        ..lineTo(x + stripeWidth, 0)
        ..lineTo(x + stripeWidth - size.height, size.height)
        ..lineTo(x - size.height, size.height)
        ..close();
      canvas.drawPath(path, stripePaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_StripePainter old) => old.progress != progress;
}

class _TimelineStep extends StatelessWidget {
  final String label;
  final bool isDone;
  final bool isActive;
  final bool isLast;

  const _TimelineStep({
    required this.label,
    required this.isDone,
    required this.isActive,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDone
        ? (isActive ? AppColors.primary : AppColors.accent)
        : AppColors.of(context).border;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isDone ? color.withOpacity(0.12) : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDone ? color : AppColors.of(context).border,
                  width: isActive ? 2 : 1.5,
                ),
              ),
              child: isDone
                  ? Icon(
                      isActive
                          ? Icons.radio_button_checked_rounded
                          : Icons.check_rounded,
                      size: 14,
                      color: color,
                    )
                  : null,
            ),
            if (!isLast)
              Container(
                width: 1.5,
                height: 32,
                color: isDone ? AppColors.accent.withOpacity(0.4) : AppColors.of(context).border,
              ),
          ],
        ),
        const SizedBox(width: 14),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDone ? AppColors.of(context).textPrimary : AppColors.of(context).textMuted,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                ),
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.of(context).surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.of(context).border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.of(context).textMuted),
          const SizedBox(width: 5),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
