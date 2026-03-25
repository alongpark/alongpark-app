import 'dart:io';
import 'dart:math' show pi;
import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_subject_segmentation/google_mlkit_subject_segmentation.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/api/api_client.dart';

typedef _EstimationResult = ({
  String type,
  double weightKg,
  double volumeM3,
  double bx, double by, double bw, double bh, // bounding box 2D fallback
  List<Offset>? corners, // 8 points pour la box 3D
});

class ScanEstimateScreen extends StatefulWidget {
  final String imagePath;
  const ScanEstimateScreen({super.key, required this.imagePath});

  @override
  State<ScanEstimateScreen> createState() => _ScanEstimateScreenState();
}

class _ScanEstimateScreenState extends State<ScanEstimateScreen>
    with TickerProviderStateMixin {
  late final AnimationController _resultController;
  late final Animation<double> _resultAnim;

  _EstimationResult? _result;
  bool _showResult = false;
  String? _error;

  int _stepIndex = 0;
  Timer? _stepTimer;
  bool _isZoomed = false;
  Uint8List? _foregroundBitmap;

  final _steps = [
    'Mise à l\'échelle de l\'image...',
    'Analyse de la profondeur...',
    'Extraction géométrique...',
    'Calcul géométrique en cours...',
  ];

  @override
  void initState() {
    super.initState();

    _resultController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _resultAnim = CurvedAnimation(parent: _resultController, curve: Curves.easeOut);

    Future.microtask(() {
      if (mounted) setState(() => _isZoomed = true);
    });

    _stepTimer = Timer.periodic(const Duration(milliseconds: 1400), (timer) {
      if (mounted) {
        setState(() {
          if (_stepIndex < _steps.length - 1) _stepIndex++;
        });
      }
    });

    _startScan();
  }

  double _parseBbox(dynamic val, double fallback) {
    if (val == null) return fallback;
    double v = (val as num).toDouble();
    if (v > 1.0) v = v / 100.0; // Prévient si l'IA renvoie 15 au lieu de 0.15
    if (v > 1.0) v = 1.0; 
    if (v < 0.0) v = 0.0;
    return v;
  }

  Future<void> _startScan() async {
    try {
      // 1. Extraction du détourage parfait (Surbrillance Pixel) via ML Kit On-Device
      try {
        final segmenter = SubjectSegmenter(
          options: SubjectSegmenterOptions(
            enableForegroundBitmap: true,
            enableForegroundConfidenceMask: false,
            enableMultipleSubjects: SubjectResultOptions(
              enableConfidenceMask: false,
              enableSubjectBitmap: false,
            ),
          ),
        );
        final inputImage = InputImage.fromFilePath(widget.imagePath);
        final segResult = await segmenter.processImage(inputImage);
        _foregroundBitmap = segResult.foregroundBitmap;
        segmenter.close();
      } catch (e) {
        debugPrint('MLKit Error: $e');
      }

      // 2. Encoder la photo en base64 et appeler Claude Vision pour l'estimation Poids/Volume
      final base64Image = await ApiClient.imageToBase64(widget.imagePath);
      final data = await ApiClient.post('/api/estimation/', {
        'image_base64': base64Image,
        'image_media_type': 'image/jpeg',
      });

      if (!mounted) return;
      _stepTimer?.cancel();

      final bbox = data['bbox'] as Map<String, dynamic>? ?? {};
      final cornersData = data['projected_corners'] as List<dynamic>?;
      List<Offset>? corners;
      if (cornersData != null && cornersData.length == 8) {
        corners = cornersData.map((e) {
          final m = e as Map<String, dynamic>;
          return Offset((m['x'] as num).toDouble(), (m['y'] as num).toDouble());
        }).toList();
      }

      _result = (
        type:     data['estimated_type'] as String,
        weightKg: (data['estimated_weight_kg'] as num).toDouble(),
        volumeM3: (data['estimated_volume_m3'] as num).toDouble(),
        bx: _parseBbox(bbox['x'], 0.15),
        by: _parseBbox(bbox['y'], 0.20),
        bw: _parseBbox(bbox['w'], 0.70),
        bh: _parseBbox(bbox['h'], 0.60),
        corners: corners,
      );
    } catch (e) {
      if (!mounted) return;
      _stepTimer?.cancel();
      _error = 'L\'analyse IA a échoué.\n\nDétail technique : $e';
    }

    setState(() => _showResult = true);
    _resultController.forward();
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    _resultController.dispose();
    super.dispose();
  }

  Widget _buildVolumeTag(BoxConstraints constraints, _EstimationResult result) {
    double minY = 1.0;
    double topX = 0.5;
    if (result.corners != null) {
      for (var p in result.corners!) {
        if (p.dy < minY) {
          minY = p.dy;
          topX = p.dx;
        }
      }
    } else {
      minY = result.by;
      topX = result.bx + result.bw / 2;
    }

    return Positioned(
      left: topX * constraints.maxWidth - 45,
      top: minY * constraints.maxHeight - 55,
      child: FadeTransition(
        opacity: _resultAnim,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${result.volumeM3.toStringAsFixed(2)} m³',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              CustomPaint(
                size: const Size(10, 5),
                painter: _ArrowPainter(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Photo plein écran avec zoom progressif
          AnimatedScale(
            scale: _isZoomed ? 1.05 : 1.0,
            duration: const Duration(seconds: 10),
            curve: Curves.easeOut,
            child: Image.file(
              File(widget.imagePath),
              fit: BoxFit.cover,
            ),
          ),

          // ── Overlay sombre (flou si chargement, net si résultat)
          if (!_showResult)
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(color: Colors.black.withValues(alpha: 0.45)),
            )
          else
            Container(color: Colors.black.withValues(alpha: 0.35)),

          // ── Contour détecté (Subject Segmentation)
          if (_showResult && _foregroundBitmap != null && _error == null)
            AnimatedBuilder(
              animation: _resultAnim,
              builder: (_, __) => Opacity(
                opacity: _resultAnim.value,
                child: Image.memory(
                  _foregroundBitmap!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),
          
          // ── Box 3D Artificielle (AR Style)
          if (_showResult && _result != null && _error == null)
            AnimatedBuilder(
              animation: _resultAnim,
              builder: (_, __) => LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _BBoxPainter(
                            result: _result!,
                            progress: _resultAnim.value,
                          ),
                        ),
                      ),
                      
                      // Étiquette de volume flottante
                      if (_resultAnim.value > 0.8)
                        _buildVolumeTag(constraints, _result!),
                    ],
                  );
                },
              ),
            ),

          // ── Interface de chargement "Pro"
          if (!_showResult)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   Container(
                     padding: const EdgeInsets.all(18),
                     decoration: BoxDecoration(
                       color: Colors.black.withValues(alpha: 0.3),
                       shape: BoxShape.circle,
                     ),
                     child: const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    ),
                   ),
                  const SizedBox(height: 24),
                  const Text(
                    'Vision Artificielle',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _steps[_stepIndex],
                      key: ValueKey(_stepIndex),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ── Bouton fermer
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
          ),

          // ── Résultat card ou erreur (slide from bottom)
          if (_showResult)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(_resultAnim),
                child: _error != null
                    ? _ErrorCard(
                        error: _error!,
                        onRetake: () => Navigator.pop(context),
                        bottomPad: bottom,
                      )
                    : _ResultCard(
                        result: _result!,
                        onValidate: () => Navigator.pop(context, (
                          type:     _result!.type,
                          weightKg: _result!.weightKg,
                          volumeM3: _result!.volumeM3,
                        )),
                        onRetake: () => Navigator.pop(context),
                        bottomPad: bottom,
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Error card ────────────────────────────────────────────────────────────────
class _ErrorCard extends StatelessWidget {
  final String error;
  final VoidCallback onRetake;
  final double bottomPad;

  const _ErrorCard({
    required this.error,
    required this.onRetake,
    required this.bottomPad,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 24, 20, bottomPad + 20),
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 48),
          const SizedBox(height: 16),
          Text(
            error,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onRetake,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF38383F),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Retour à la carte',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Result card ───────────────────────────────────────────────────────────────
class _ResultCard extends StatelessWidget {
  final _EstimationResult result;
  final VoidCallback onValidate;
  final VoidCallback onRetake;
  final double bottomPad;

  const _ResultCard({
    required this.result,
    required this.onValidate,
    required this.onRetake,
    required this.bottomPad,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 24, 20, bottomPad + 20),
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              width: 32,
              height: 3,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    color: AppColors.accent, size: 18),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dimensions estimées',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                  Text(
                    'Résultat de l\'analyse IA',
                    style: TextStyle(
                      color: Color(0xFF9898A0),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Metrics row
          Row(
            children: [
              _Metric(label: 'Type', value: result.type),
              _Divider(),
              _Metric(
                label: 'Poids estimé',
                value: '${result.weightKg.toStringAsFixed(1)} kg',
                highlight: true,
              ),
              _Divider(),
              _Metric(
                label: 'Volume',
                value: '${result.volumeM3.toStringAsFixed(2)} m³',
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Note
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 20),
            child: Text(
              'Le poids peut être ajusté manuellement après validation.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.40),
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),

          // Buttons
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onRetake,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF38383F)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: Text(
                        'Reprendre',
                        style: TextStyle(
                          color: Color(0xFF9898A0),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: onValidate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: Text(
                        'Valider',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _Metric({required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: highlight ? AppColors.accent : Colors.white,
              fontSize: highlight ? 16 : 14,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF9898A0),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: const Color(0xFF38383F),
    );
  }
}



// ── Bounding box painter — contour détecté par l'IA ──────────────────────────
class _BBoxPainter extends CustomPainter {
  final _EstimationResult result;
  final double progress;

  const _BBoxPainter({required this.result, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9 * progress)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: progress)
      ..style = PaintingStyle.fill;

    if (result.corners != null && result.corners!.length == 8) {
      final pts = result.corners!.map((p) => Offset(p.dx * size.width, p.dy * size.height)).toList();

      // Dessiner les arêtes de la box 3D
      // Face inférieure (0,1,2,3)
      _drawFace(canvas, pts.sublist(0, 4), paint);
      // Face supérieure (4,5,6,7)
      _drawFace(canvas, pts.sublist(4, 8), paint);
      // Arêtes verticales (0-4, 1-5, 2-6, 3-7)
      for (int i = 0; i < 4; i++) {
        canvas.drawLine(pts[i], pts[i + 4], paint);
      }

      // Dessiner les points aux sommets (White Dots)
      for (var p in pts) {
        canvas.drawCircle(p, 4, dotPaint);
      }
    } else {
      // Fallback 2D rect si on n'a pas les corners
      final rect = Rect.fromLTWH(
        result.bx * size.width,
        result.by * size.height,
        result.bw * size.width,
        result.bh * size.height,
      );
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), paint);
      
      // Points aux coins
      canvas.drawCircle(rect.topLeft, 4, dotPaint);
      canvas.drawCircle(rect.topRight, 4, dotPaint);
      canvas.drawCircle(rect.bottomLeft, 4, dotPaint);
      canvas.drawCircle(rect.bottomRight, 4, dotPaint);
    }
  }

  void _drawFace(Canvas canvas, List<Offset> pts, Paint paint) {
    final path = Path()
      ..moveTo(pts[0].dx, pts[0].dy)
      ..lineTo(pts[1].dx, pts[1].dy)
      ..lineTo(pts[2].dx, pts[2].dy)
      ..lineTo(pts[3].dx, pts[3].dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_BBoxPainter old) => old.progress != progress;
}

class _ArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
