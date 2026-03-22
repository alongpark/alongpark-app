import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/models/enums.dart';
import '../../../../shared/models/incident_report.dart';
import '../../../../features/driver/dashboard/providers/driver_dashboard_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/nux_card.dart';

class IncidentReportScreen extends ConsumerStatefulWidget {
  final String missionId;
  const IncidentReportScreen({super.key, required this.missionId});

  @override
  ConsumerState<IncidentReportScreen> createState() =>
      _IncidentReportScreenState();
}

class _IncidentReportScreenState extends ConsumerState<IncidentReportScreen> {
  IncidentType? _selected;
  final _noteController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selected == null) return;
    setState(() => _sending = true);

    final repo = ref.read(driverRepoProvider);
    await repo.reportIncident(IncidentReport(
      id: 'inc-${DateTime.now().millisecondsSinceEpoch}',
      missionId: widget.missionId,
      type: _selected!,
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      createdAt: DateTime.now(),
    ));

    if (!mounted) return;
    setState(() => _sending = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Incident signalé — merci'),
        backgroundColor: AppColors.primary,
      ),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Signaler un incident')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Quel est le problème ?',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                'Sélectionnez le type d\'incident',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),

              // Incident types
              ...IncidentType.values.map((type) {
                final selected = _selected == type;
                final (icon, color) = _iconForType(type);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: NuxCard(
                    onTap: () => setState(() => _selected = type),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    backgroundColor: selected
                        ? AppColors.primary.withOpacity(0.04)
                        : AppColors.of(context).cardBg,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: color, size: 18),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            type.label,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: AppColors.of(context).textPrimary,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                          ),
                        ),
                        if (selected)
                          const Icon(Icons.check_circle_rounded,
                              color: AppColors.primary, size: 20),
                      ],
                    ),
                  ),
                );
              }),

              const SizedBox(height: 16),

              TextField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Commentaire libre (optionnel)',
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
              ),

              const Spacer(),

              FilledButton(
                onPressed: (_selected != null && !_sending) ? _submit : null,
                child: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Envoyer le signalement'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  (IconData, Color) _iconForType(IncidentType type) => switch (type) {
        IncidentType.delay => (Icons.access_time_rounded, AppColors.warning),
        IncidentType.loadingProblem =>
          (Icons.warning_amber_rounded, AppColors.warning),
        IncidentType.doesNotFit => (Icons.do_not_disturb_rounded, AppColors.danger),
        IncidentType.clientAbsent =>
          (Icons.person_off_rounded, AppColors.of(context).textSecondary),
        IncidentType.other => (Icons.more_horiz_rounded, AppColors.of(context).textMuted),
      };
}
