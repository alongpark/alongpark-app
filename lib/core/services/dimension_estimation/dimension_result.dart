/// Result produced by any estimation strategy
class DimensionResult {
  final double lengthCm;
  final double widthCm;
  final double heightCm;
  final double confidenceScore; // 0.0 – 1.0
  final EstimationMethod method;
  final String? merchandiseType; // detected label if available

  const DimensionResult({
    required this.lengthCm,
    required this.widthCm,
    required this.heightCm,
    required this.confidenceScore,
    required this.method,
    this.merchandiseType,
  });

  double get volumeM3 => (lengthCm * widthCm * heightCm) / 1_000_000;

  String get summary =>
      '${lengthCm.toInt()} × ${widthCm.toInt()} × ${heightCm.toInt()} cm';

  @override
  String toString() =>
      'DimensionResult($summary — ${method.label} — ${(confidenceScore * 100).toInt()}%)';
}

enum EstimationMethod {
  lidarAr,
  backendVision,
  referenceObject,
  manual,
}

extension EstimationMethodMeta on EstimationMethod {
  String get label => switch (this) {
        EstimationMethod.lidarAr => 'LiDAR / AR',
        EstimationMethod.backendVision => 'Vision IA',
        EstimationMethod.referenceObject => 'Objet de référence',
        EstimationMethod.manual => 'Saisie manuelle',
      };

  // IconData values expressed as codepoints to avoid a Flutter import
  // in this pure-Dart model file. Use EstimationMethodIcon extension
  // from core/widgets/ in UI code instead.
}
