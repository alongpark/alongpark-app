import 'dart:io';
import 'dimension_result.dart';
import 'dimension_strategy.dart';
import 'strategies/lidar_ar_strategy.dart';
import 'strategies/backend_vision_strategy.dart';
import 'strategies/reference_object_strategy.dart';

/// Orchestrates dimension estimation with automatic strategy selection.
///
/// Priority chain:
///   1. LiDAR/AR       → if device has depth sensor (iPhone Pro, iPad Pro)
///   2. BackendVision   → if internet available (any modern phone)
///   3. ReferenceObject → always available as fallback
///   4. Manual          → user inputs dimensions themselves
class DimensionEstimationService {
  final LidarArStrategy _lidar = LidarArStrategy();
  final BackendVisionStrategy _vision;
  final ReferenceObjectStrategy _reference = const ReferenceObjectStrategy();

  DimensionEstimationService({String backendUrl = 'https://api.alongpark.com'})
      : _vision = BackendVisionStrategy(baseUrl: backendUrl);

  /// Detects the best available strategy for this device.
  Future<EstimationMethod> detectBestMethod() async {
    if (await _lidar.isAvailable()) return EstimationMethod.lidarAr;
    if (await _vision.isAvailable()) return EstimationMethod.backendVision;
    return EstimationMethod.referenceObject;
  }

  /// Returns all available strategies for display in the UI.
  Future<List<EstimationMethod>> availableMethods() async {
    final methods = <EstimationMethod>[];
    if (await _lidar.isAvailable()) methods.add(EstimationMethod.lidarAr);
    methods.add(EstimationMethod.backendVision); // always
    methods.add(EstimationMethod.referenceObject); // always
    methods.add(EstimationMethod.manual); // always
    return methods;
  }

  /// Runs estimation with a specific strategy.
  Future<DimensionResult?> estimateWith(
    EstimationMethod method,
    File image, {
    File? referenceImage,
  }) async {
    final strategy = _strategyFor(method);
    return strategy.estimate(image, referenceImage: referenceImage);
  }

  /// Auto-selects the best strategy and runs it.
  Future<DimensionResult?> estimateAuto(File image) async {
    final method = await detectBestMethod();
    return estimateWith(method, image);
  }

  DimensionStrategy _strategyFor(EstimationMethod method) => switch (method) {
        EstimationMethod.lidarAr => _lidar,
        EstimationMethod.backendVision => _vision,
        EstimationMethod.referenceObject => _reference,
        EstimationMethod.manual =>
          throw StateError('Manual has no strategy — handle in UI'),
      };
}
