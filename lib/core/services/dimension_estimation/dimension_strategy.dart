import 'dart:io';
import 'dimension_result.dart';

/// Base interface — each strategy implements this contract.
/// Swappable: mock today, real implementation tomorrow.
abstract class DimensionStrategy {
  EstimationMethod get method;

  /// Returns true if this strategy can run on the current device/context
  Future<bool> isAvailable();

  /// Estimate dimensions from a captured image.
  /// [referenceImagePath] is only used by ReferenceObjectStrategy.
  Future<DimensionResult?> estimate(
    File image, {
    File? referenceImage,
  });
}
