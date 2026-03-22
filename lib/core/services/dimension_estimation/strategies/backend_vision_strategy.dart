import 'dart:io';
import '../dimension_result.dart';
import '../dimension_strategy.dart';

/// Strategy 2 — Vision IA côté backend
///
/// Availability: always (requires internet)
/// Precision:    ±15–20%
/// How it works: image uploaded to backend → object detection model
///               (YOLO / Florence-2 / custom) → returns bounding box + type.
///               Falls back to category-based standard dimensions when
///               confidence is low.
class BackendVisionStrategy implements DimensionStrategy {
  final String baseUrl;

  const BackendVisionStrategy({required this.baseUrl});

  @override
  EstimationMethod get method => EstimationMethod.backendVision;

  @override
  Future<bool> isAvailable() async {
    // Always available — internet check could be added here
    return true;
  }

  @override
  Future<DimensionResult?> estimate(File image, {File? referenceImage}) async {
    try {
      // TODO: replace mock with real multipart upload to /ai/vision/estimate
      // final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/ai/vision/estimate'))
      //   ..files.add(await http.MultipartFile.fromPath('image', image.path));
      // final response = await request.send();

      // ── MOCK (simulates backend response) ────────────────────────────────
      await Future.delayed(const Duration(seconds: 2));

      // Mock: backend detects a standard carton box
      return const DimensionResult(
        lengthCm: 60,
        widthCm: 40,
        heightCm: 35,
        confidenceScore: 0.78,
        method: EstimationMethod.backendVision,
        merchandiseType: 'Boîte carton',
      );
      // ── END MOCK ─────────────────────────────────────────────────────────
    } catch (_) {
      return null;
    }
  }
}

/// Standard dimensions by merchandise category.
/// Used when backend confidence < 0.5.
class StandardDimensions {
  static const Map<String, Map<String, double>> _catalog = {
    'palette_eur': {'l': 120, 'w': 80, 'h': 150},
    'palette_us': {'l': 121, 'w': 101, 'h': 150},
    'carton_small': {'l': 30, 'w': 20, 'h': 20},
    'carton_medium': {'l': 60, 'w': 40, 'h': 35},
    'carton_large': {'l': 90, 'w': 60, 'h': 60},
    'sac': {'l': 70, 'w': 40, 'h': 25},
    'colis_fragile': {'l': 50, 'w': 40, 'h': 30},
  };

  static DimensionResult fromCategory(String category) {
    final d = _catalog[category] ?? _catalog['carton_medium']!;
    return DimensionResult(
      lengthCm: d['l']!,
      widthCm: d['w']!,
      heightCm: d['h']!,
      confidenceScore: 0.60,
      method: EstimationMethod.backendVision,
      merchandiseType: category,
    );
  }
}
