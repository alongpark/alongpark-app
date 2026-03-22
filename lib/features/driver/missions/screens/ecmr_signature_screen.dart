import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:signature/signature.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/missions_provider.dart';
import '../../../../core/utils/formatters.dart';

class EcmrSignatureScreen extends ConsumerStatefulWidget {
  final String opportunityId;
  const EcmrSignatureScreen({super.key, required this.opportunityId});

  @override
  ConsumerState<EcmrSignatureScreen> createState() => _EcmrSignatureScreenState();
}

class _EcmrSignatureScreenState extends ConsumerState<EcmrSignatureScreen> {
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 4,
    penColor: AppColors.primary,
    exportBackgroundColor: Colors.white,
  );
  
  bool _isSigned = false;
  Uint8List? _signatureBytes;

  @override
  void initState() {
    super.initState();
    _signatureController.addListener(() {
      final hasSignature = _signatureController.isNotEmpty;
      if (hasSignature != _isSigned) {
        setState(() => _isSigned = hasSignature);
      }
    });
  }

  @override
  void dispose() {
    _signatureController.dispose();
    super.dispose();
  }

  Future<void> _submitSignature() async {
    if (_signatureController.isEmpty) return;
    
    final bytes = await _signatureController.toPngBytes();
    if (bytes == null) return;
    
    setState(() {
      _signatureBytes = bytes;
    });

    // Accept the mission in the backend to clear it from opportunities
    final user = ref.read(authProvider);
    if (user != null) {
      await ref.read(opportunitiesProvider(user.id).notifier).accept(widget.opportunityId);
    }

    if (!mounted) return;

    // Show success dialog
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.compatibleCertain,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 24),
            const Text(
              'Livraison validée',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
            const SizedBox(height: 12),
            const Text(
              'La e-CMR a été signée numériquement et envoyée au destinataire ainsi qu\'à l\'expéditeur.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 24),
            if (_signatureBytes != null)
              Container(
                height: 80,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Image.memory(_signatureBytes!),
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop(); // close dialog
                  context.go('/driver'); // Return to dashboard
                },
                child: const Text('Retour au tableau de bord'),
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    if (user == null) return const SizedBox();
    final async = ref.watch(opportunitiesProvider(user.id));

    return Scaffold(
      backgroundColor: AppColors.of(context).surface,
      appBar: AppBar(
        title: const Text('Lettre de Voiture (e-CMR)'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (list) {
          final opp = list.cast<dynamic>().firstWhere(
            (o) => o.id == widget.opportunityId,
            orElse: () => null,
          );

          if (opp == null) return const Center(child: Text('Mission introuvable'));

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // WAYBILL INFO
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.of(context).border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Récépissé de transport', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                          Text('#${opp.id.substring(0, 6).toUpperCase()}', style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                      const Divider(height: 30),
                      Text('Départ: ${opp.pickupLocation}', style: const TextStyle(fontSize: 14)),
                      const SizedBox(height: 8),
                      Text('Arrivée: ${opp.deliveryDestination}', style: const TextStyle(fontSize: 14)),
                      const SizedBox(height: 16),
                      Text('Marchandise: ${opp.merchandiseType}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      Text('Poids: ${formatWeight(opp.weightKg)} • Volume: ${formatVolume(opp.volumeM3)}', style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // SIGNATURE INSTRUCTIONS
                const Text(
                  'Signature du Destinataire',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tracez votre signature ci-dessous pour certifier la bonne réception de la marchandise.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                
                // SIGNATURE PAD
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Stack(
                      children: [
                        Signature(
                          controller: _signatureController,
                          height: 250,
                          backgroundColor: Colors.white,
                        ),
                        if (_isSigned)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () => _signatureController.clear(),
                              tooltip: 'Effacer',
                            ),
                          )
                        else
                          const Positioned.fill(
                            child: Center(
                              child: IgnorePointer(
                                child: Text('Signez ici', style: TextStyle(fontSize: 24, color: Colors.black12, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          )
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // CTA
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: _isSigned ? _submitSignature : null,
                    icon: const Icon(Icons.verified_user_rounded),
                    label: const Text('Valider la livraison', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.compatibleCertain,
                      disabledBackgroundColor: Colors.grey.shade300,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}
