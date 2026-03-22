import 'dart:io';
import '../dimension_result.dart';
import '../dimension_strategy.dart';

/// Strategy 3 — Objet de référence (feuille A4 dans le cadre)
///
/// Availability: any phone with a camera
/// Precision:    ±5–8%
/// How it works:
///   1. User places an A4 sheet (21×29.7 cm) next to the object
///   2. Photo is taken
///   3. Backend detects the A4 sheet in the image
///   4. Pixel ratio between A4 and object gives real-world dimensions
///
/// Reference objects supported:
///   - Feuille A4   : 21 × 29.7 cm  ← default
///   - Carte bancaire: 85.6 × 54 mm (fallback)
///   - Palette EUR  : 120 × 80 cm   (driver-side reference)
class ReferenceObjectStrategy implements DimensionStrategy {
  final ReferenceObjectType referenceType;

  const ReferenceObjectStrategy({
    this.referenceType = ReferenceObjectType.a4Sheet,
  });

  @override
  EstimationMethod get method => EstimationMethod.referenceObject;

  @override
  Future<bool> isAvailable() async => true; // any device with camera

  @override
  Future<DimensionResult?> estimate(File image, {File? referenceImage}) async {
    // TODO: send image to backend /ai/vision/reference-measure
    // Backend detects the A4 sheet corners via contour detection (OpenCV),
    // computes pixel-per-cm ratio, then measures object bounding box.

    // ── MOCK ─────────────────────────────────────────────────────────────
    await Future.delayed(const Duration(milliseconds: 1500));

    // Simulated result: slightly more precise than pure vision
    return DimensionResult(
      lengthCm: 58,
      widthCm: 38,
      heightCm: 32,
      confidenceScore: 0.87,
      method: EstimationMethod.referenceObject,
      merchandiseType: 'Colis carton',
    );
    // ── END MOCK ─────────────────────────────────────────────────────────
  }
}

enum ReferenceObjectType {
  a4Sheet,
  creditCard,
  eurPallet,
}

extension ReferenceObjectLabel on ReferenceObjectType {
  String get label => switch (this) {
        ReferenceObjectType.a4Sheet => 'Feuille A4',
        ReferenceObjectType.creditCard => 'Carte bancaire',
        ReferenceObjectType.eurPallet => 'Palette EUR',
      };

  String get instruction => switch (this) {
        ReferenceObjectType.a4Sheet =>
          'Posez une feuille A4 à plat contre votre colis, bien visible dans le cadre',
        ReferenceObjectType.creditCard =>
          'Posez votre carte bancaire à côté du colis, face visible',
        ReferenceObjectType.eurPallet =>
          'Assurez-vous que la palette est entièrement visible',
      };

  /// Real dimensions in cm
  ({double w, double h}) get realDimensions => switch (this) {
        ReferenceObjectType.a4Sheet => (w: 21.0, h: 29.7),
        ReferenceObjectType.creditCard => (w: 8.56, h: 5.40),
        ReferenceObjectType.eurPallet => (w: 80.0, h: 120.0),
      };
}
