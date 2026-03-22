import 'dart:io';
import 'package:flutter/services.dart';
import '../dimension_result.dart';
import '../dimension_strategy.dart';

/// Strategy 1 — LiDAR + ARKit (iOS Pro) / ARCore Depth (Android)
///
/// Availability: iPhone 12 Pro+ and iPad Pro 2020+
/// Precision:    ±2–3 cm
/// How it works: Native AR session detects planes and measures real-world
///               distances using the depth sensor.
///
/// TODO: replace stub with arkit_plugin / ar_flutter_plugin AR session.
/// The method channel below is the bridge to the native measurement screen.
class LidarArStrategy implements DimensionStrategy {
  static const _channel = MethodChannel('com.alongpark/lidar');

  @override
  EstimationMethod get method => EstimationMethod.lidarAr;

  /// Checks LiDAR hardware availability via native platform channel.
  /// Falls back to false on any error (simulator, older devices).
  @override
  Future<bool> isAvailable() async {
    try {
      final result =
          await _channel.invokeMethod<bool>('isLidarAvailable') ?? false;
      return result;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      // Channel not registered yet (simulator or plugin not installed)
      return false;
    }
  }

  /// Launches the native AR measurement session.
  /// Returns null if user cancels or hardware fails.
  @override
  Future<DimensionResult?> estimate(File image, {File? referenceImage}) async {
    try {
      final raw = await _channel
          .invokeMapMethod<String, dynamic>('measureObject');
      if (raw == null) return null;

      return DimensionResult(
        lengthCm: (raw['length_cm'] as num).toDouble(),
        widthCm: (raw['width_cm'] as num).toDouble(),
        heightCm: (raw['height_cm'] as num).toDouble(),
        confidenceScore: (raw['confidence'] as num?)?.toDouble() ?? 0.92,
        method: EstimationMethod.lidarAr,
        merchandiseType: raw['type'] as String?,
      );
    } on PlatformException {
      return null;
    }
  }
}
