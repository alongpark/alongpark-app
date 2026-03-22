import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/send_request_provider.dart';
import '../../../../core/theme/app_colors.dart';

class ShipmentInfoScreen extends ConsumerStatefulWidget {
  const ShipmentInfoScreen({super.key});

  @override
  ConsumerState<ShipmentInfoScreen> createState() => _ShipmentInfoScreenState();
}

class _ShipmentInfoScreenState extends ConsumerState<ShipmentInfoScreen> {
  String? _selectedType;
  double? _selectedWeight;
  double? _customWeight;
  final _weightController = TextEditingController();

  static const _types = [
    ('📦', 'Colis standard'),
    ('🎁', 'Colis fragile'),
    ('📋', 'Palette standard'),
    ('🛠️', 'Matériel pro'),
    ('🛍️', 'Marchandise diverse'),
  ];

  static const _quickWeights = [5.0, 10.0, 25.0, 50.0, 100.0, 250.0, 500.0, 1000.0];

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  bool get _canContinue =>
      _selectedType != null && (_selectedWeight != null || _customWeight != null);

  void _next() {
    final weight = _customWeight ?? _selectedWeight!;
    ref.read(sendRequestProvider.notifier).setMerchandiseInfo(
          type: _selectedType,
          weightKg: weight,
          volumeM3: _estimateVolume(weight),
        );
    context.push('/client/destination');
  }

  double _estimateVolume(double weightKg) {
    // Mock: 1 kg ≈ 0.004 m³ for general cargo
    return (weightKg * 0.004).clamp(0.1, 20.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Votre marchandise')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Step indicator
              _StepBar(step: 2, total: 4),
              const SizedBox(height: 28),

              // Type
              Text('Type de marchandise',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _types.map((t) {
                  final (emoji, label) = t;
                  final selected = _selectedType == label;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedType = label),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary
                            : AppColors.of(context).cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : AppColors.of(context).border,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(emoji, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 7),
                          Text(
                            label,
                            style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : AppColors.of(context).textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 32),

              // Weight
              Text('Poids estimé',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text('Choisissez ou saisissez',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _quickWeights.map((w) {
                  final label = w >= 1000
                      ? '${(w / 1000).toInt()} t'
                      : '${w.toInt()} kg';
                  final selected = _selectedWeight == w && _customWeight == null;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _selectedWeight = w;
                      _customWeight = null;
                      _weightController.clear();
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary.withOpacity(0.08)
                            : AppColors.of(context).cardBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : AppColors.of(context).border,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: selected
                              ? AppColors.primary
                              : AppColors.of(context).textSecondary,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _weightController,
                decoration: const InputDecoration(
                  labelText: 'Autre poids',
                  suffixText: 'kg',
                  hintText: 'ex : 78',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (v) {
                  final parsed = double.tryParse(v);
                  setState(() {
                    _customWeight = parsed;
                    _selectedWeight = null;
                  });
                },
              ),

              const SizedBox(height: 40),
              FilledButton(
                onPressed: _canContinue ? _next : null,
                child: const Text('Continuer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepBar extends StatelessWidget {
  final int step;
  final int total;
  const _StepBar({required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final active = i < step;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
            height: 4,
            decoration: BoxDecoration(
              color: active ? AppColors.primary : AppColors.of(context).border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}
