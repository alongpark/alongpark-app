import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/send_request_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/dimension_estimation/dimension_estimation_service.dart';
import '../../../../core/services/dimension_estimation/dimension_result.dart';
import '../../../../core/utils/formatters.dart';

// ── Provider ─────────────────────────────────────────────────────────────────
final _estimationServiceProvider = Provider((_) => DimensionEstimationService());

final _bestMethodProvider = FutureProvider<EstimationMethod>((ref) async {
  return ref.read(_estimationServiceProvider).detectBestMethod();
});

// ── Screen ───────────────────────────────────────────────────────────────────
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  CameraController? _camera;
  bool _initializing = true;
  File? _captured;
  bool _analyzing = false;
  DimensionResult? _result;
  EstimationMethod? _selectedMethod;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        _camera = CameraController(
          cameras.first,
          ResolutionPreset.high,
          enableAudio: false,
        );
        await _camera!.initialize();
      }
    } catch (_) {}
    if (mounted) setState(() => _initializing = false);
  }

  Future<void> _shoot() async {
    if (_camera == null || !_camera!.value.isInitialized) return;
    final xf = await _camera!.takePicture();
    final file = File(xf.path);
    setState(() => _captured = file);
    await _analyze(file);
  }

  Future<void> _pickFromGallery() async {
    final xf = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (xf == null) return;
    final file = File(xf.path);
    setState(() => _captured = file);
    await _analyze(file);
  }

  Future<void> _analyze(File image) async {
    final method = _selectedMethod ??
        await ref.read(_estimationServiceProvider).detectBestMethod();

    if (method == EstimationMethod.lidarAr) {
      // AR session is triggered separately via native — skip auto analyze
      return;
    }

    setState(() => _analyzing = true);

    final result = await ref
        .read(_estimationServiceProvider)
        .estimateWith(method, image);

    if (mounted) setState(() {
      _analyzing = false;
      _result = result;
    });
  }

  void _confirm() {
    if (_captured != null) {
      ref.read(sendRequestProvider.notifier).setImage(_captured!.path);
    }
    // Pass dimensions to next screen via provider
    context.push('/client/info', extra: _result);
  }

  void _switchMethod(EstimationMethod method) {
    setState(() {
      _selectedMethod = method;
      _result = null;
      _captured = null;
    });
  }

  @override
  void dispose() {
    _camera?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bestMethodAsync = ref.watch(_bestMethodProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Scanner la marchandise'),
        actions: [
          // Method switcher
          bestMethodAsync.when(
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
            data: (best) => _MethodSwitcherButton(
              current: _selectedMethod ?? best,
              onSwitch: _switchMethod,
            ),
          ),
        ],
      ),
      body: bestMethodAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        error: (_, __) => _buildViewfinder(),
        data: (best) {
          final active = _selectedMethod ?? best;

          // LiDAR: show dedicated AR hint screen
          if (active == EstimationMethod.lidarAr) {
            return _LidarPrompt(
              onFallback: () =>
                  _switchMethod(EstimationMethod.backendVision),
            );
          }

          // Reference object: guide overlay
          if (active == EstimationMethod.referenceObject &&
              _captured == null) {
            return _ReferenceObjectGuide(
              onShoot: _shoot,
              onGallery: _pickFromGallery,
            );
          }

          // Photo captured → show result or loading
          if (_captured != null) return _buildPreview(active);

          // Default camera view
          return _buildViewfinder();
        },
      ),
    );
  }

  // ── Camera viewfinder ──────────────────────────────────────────────────────
  Widget _buildViewfinder() {
    if (_initializing) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_camera != null && _camera!.value.isInitialized)
          CameraPreview(_camera!)
        else
          const _NoCameraPlaceholder(),

        // Crosshair overlay
        Center(
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.accent, width: 2),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),

        // Bottom bar
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _CameraControls(
            onShoot: _shoot,
            onGallery: _pickFromGallery,
            onSkip: () => context.push('/client/info'),
          ),
        ),
      ],
    );
  }

  // ── Preview + result ───────────────────────────────────────────────────────
  Widget _buildPreview(EstimationMethod method) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(_captured!, fit: BoxFit.cover),

        // Dark gradient bottom
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.center,
                colors: [Colors.black.withValues(alpha: 0.85), Colors.transparent],
              ),
            ),
          ),
        ),

        // Analysis overlay
        if (_analyzing)
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: AppColors.accent,
                      strokeWidth: 2,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(_methodIcon(method), color: AppColors.accent, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '${method.label} en cours…',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),

        // Result card
        if (_result != null && !_analyzing)
          Positioned(
            bottom: 140,
            left: 20,
            right: 20,
            child: _ResultCard(result: _result!),
          ),

        // CTA buttons
        if (!_analyzing)
          Positioned(
            bottom: 48,
            left: 20,
            right: 20,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() {
                      _captured = null;
                      _result = null;
                    }),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white38),
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Reprendre'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _confirm,
                    child: const Text('Continuer'),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ── LiDAR prompt ──────────────────────────────────────────────────────────────
class _LidarPrompt extends StatelessWidget {
  final VoidCallback onFallback;
  const _LidarPrompt({required this.onFallback});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.radar_rounded, color: AppColors.accent, size: 72),
          const SizedBox(height: 24),
          const Text(
            'Mesure LiDAR disponible',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Votre appareil dispose d\'un capteur LiDAR. Pointez la caméra vers la marchandise — la mesure se fait automatiquement en temps réel.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          FilledButton.icon(
            onPressed: () {
              // TODO: launch ARKit session via native method channel
            },
            icon: const Icon(Icons.view_in_ar_rounded),
            label: const Text('Lancer la mesure AR'),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: onFallback,
            child: const Text(
              'Utiliser la Vision IA à la place',
              style: TextStyle(color: Colors.white54),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reference object guide ────────────────────────────────────────────────────
class _ReferenceObjectGuide extends StatelessWidget {
  final VoidCallback onShoot;
  final VoidCallback onGallery;
  const _ReferenceObjectGuide({required this.onShoot, required this.onGallery});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Instruction card
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.description_outlined, color: AppColors.accent, size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Posez une feuille A4 bien visible à côté de votre colis, puis prenez la photo.',
                    style: TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ),

        // A4 position indicator
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Object zone
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white54, width: 1.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(Icons.inventory_2_outlined, color: Colors.white38, size: 48),
                ),
              ),
              const SizedBox(height: 12),
              // A4 reference zone
              Container(
                width: 84,
                height: 118,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.accent, width: 2),
                  borderRadius: BorderRadius.circular(6),
                  color: AppColors.accent.withValues(alpha: 0.1),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.description_outlined, color: AppColors.accent, size: 20),
                    SizedBox(height: 4),
                    Text('A4', style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Controls
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _CameraControls(
            onShoot: onShoot,
            onGallery: onGallery,
            onSkip: null,
          ),
        ),
      ],
    );
  }
}

// ── Result card ───────────────────────────────────────────────────────────────
class _ResultCard extends StatelessWidget {
  final DimensionResult result;
  const _ResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_methodIcon(result.method), color: AppColors.accent, size: 14),
              const SizedBox(width: 6),
              Text(
                result.method.label,
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              // Confidence bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: getConfidenceColor(result.confidenceScore)
                      .withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  formatConfidence(result.confidenceScore),
                  style: TextStyle(
                    color: getConfidenceColor(result.confidenceScore),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (result.merchandiseType != null)
            Text(
              result.merchandiseType!,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15),
            ),
          const SizedBox(height: 4),
          Text(
            result.summary,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          Text(
            'Volume estimé : ${result.volumeM3.toStringAsFixed(3)} m³',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

}

// ── Shared widgets ────────────────────────────────────────────────────────────
class _CameraControls extends StatelessWidget {
  final VoidCallback onShoot;
  final VoidCallback onGallery;
  final VoidCallback? onSkip;

  const _CameraControls({
    required this.onShoot,
    required this.onGallery,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 32, right: 32, bottom: 48, top: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _CircleButton(
            icon: Icons.photo_library_rounded,
            label: 'Galerie',
            onTap: onGallery,
          ),
          GestureDetector(
            onTap: onShoot,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.4), width: 4),
              ),
              child: const Icon(Icons.camera_alt_rounded,
                  color: Colors.black, size: 30),
            ),
          ),
          if (onSkip != null)
            _CircleButton(
              icon: Icons.skip_next_rounded,
              label: 'Passer',
              onTap: onSkip!,
            )
          else
            const SizedBox(width: 60),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _CircleButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}

class _NoCameraPlaceholder extends StatelessWidget {
  const _NoCameraPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.camera_alt_outlined, color: Colors.white30, size: 64),
          const SizedBox(height: 16),
          Text(
            'Caméra non disponible',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
          ),
        ],
      ),
    );
  }
}

class _MethodSwitcherButton extends StatelessWidget {
  final EstimationMethod current;
  final ValueChanged<EstimationMethod> onSwitch;

  const _MethodSwitcherButton(
      {required this.current, required this.onSwitch});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(_methodIcon(current), color: Colors.white, size: 20),
      tooltip: 'Changer de méthode',
      onPressed: () => _showPicker(context),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Méthode de mesure',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            ...EstimationMethod.values.map((m) => _MethodTile(
                  method: m,
                  selected: m == current,
                  onTap: () {
                    Navigator.pop(context);
                    onSwitch(m);
                  },
                )),
          ],
        ),
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  final EstimationMethod method;
  final bool selected;
  final VoidCallback onTap;

  const _MethodTile(
      {required this.method, required this.selected, required this.onTap});

  static const _descriptions = {
    EstimationMethod.lidarAr: 'iPhone Pro — ±2 cm — temps réel',
    EstimationMethod.backendVision:
        'Tout appareil — ±15% — connexion requise',
    EstimationMethod.referenceObject:
        'Tout appareil — ±5% — feuille A4 requise',
    EstimationMethod.manual: 'Saisie manuelle des dimensions',
  };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppColors.accent.withValues(alpha: 0.5)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(_methodIcon(method),
                color: selected ? AppColors.accent : Colors.white54,
                size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(method.label,
                      style: TextStyle(
                        color: selected ? AppColors.accent : Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      )),
                  const SizedBox(height: 2),
                  Text(
                    _descriptions[method] ?? '',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.accent, size: 18),
          ],
        ),
      ),
    );
  }
}

IconData _methodIcon(EstimationMethod method) => switch (method) {
      EstimationMethod.lidarAr => Icons.radar_rounded,
      EstimationMethod.backendVision => Icons.psychology_rounded,
      EstimationMethod.referenceObject => Icons.description_outlined,
      EstimationMethod.manual => Icons.edit_rounded,
    };
