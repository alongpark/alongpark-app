import 'dart:math';
import '../../models/shipment_request.dart';
import '../../models/transport_opportunity.dart';
import '../../models/enums.dart';
import '../interfaces/matching_repository.dart';
import 'mock_data.dart';

/// Simulated AI matching engine.
/// Rule-based logic — easily replaceable by a real backend call.
class MockMatchingRepository implements MatchingRepository {
  @override
  Future<TransportOpportunity?> findBestMatch(ShipmentRequest request) async {
    // Simulate AI processing time
    await Future.delayed(const Duration(seconds: 2));

    final status = _evaluate(request);
    if (status == CompatibilityStatus.rejected) return null;

    final now = DateTime.now();
    return TransportOpportunity(
      id: 'opp-${Random().nextInt(9999)}',
      shipmentRequestId: request.id,
      driverId: 'driver-01',
      compatibilityStatus: status,
      price: _calculatePrice(request),
      estimatedArrival: now.add(_calculateDelay(request)),
      additionalRevenue: _calculatePrice(request),
      requiresRearrangement: status == CompatibilityStatus.compatibleEffort,
      description: _buildDescription(request, status),
      merchandiseType: request.estimatedType ?? 'Marchandise générale',
      volumeM3: request.estimatedVolumeM3 ?? 0.5,
      weightKg: request.estimatedWeightKg,
      pickupLocation: 'Adresse de départ',
      deliveryDestination: request.destination,
      routeImpact: const Duration(minutes: 20),
    );
  }

  /// Core matching logic — 3 categories
  CompatibilityStatus _evaluate(ShipmentRequest request) {
    final weight = request.estimatedWeightKg;
    final volume = request.estimatedVolumeM3 ?? 0.5;
    final truckFreeVolume = MockData.truckState.freeVolumeM3;
    final truckFreeWeight = MockData.truckState.freeWeightKg;

    // Rejected: clearly exceeds capacity with safety margin
    if (weight > truckFreeWeight * 0.85 || volume > truckFreeVolume * 0.85) {
      return CompatibilityStatus.rejected;
    }

    // Certain: fits easily (< 60% of available capacity)
    if (weight <= truckFreeWeight * 0.6 && volume <= truckFreeVolume * 0.6) {
      return CompatibilityStatus.compatibleCertain;
    }

    // With effort: fits but tight
    return CompatibilityStatus.compatibleEffort;
  }

  double _calculatePrice(ShipmentRequest request) {
    const baseRate = 15.0; // € per 100 km (mock)
    const weightRate = 0.08; // € per kg
    return (baseRate + request.estimatedWeightKg * weightRate)
        .clamp(25.0, 500.0);
  }

  Duration _calculateDelay(ShipmentRequest request) {
    // Mock: between 2h and 8h
    final hours = 2 + (request.estimatedWeightKg / 100).clamp(0, 6).toInt();
    return Duration(hours: hours);
  }

  String _buildDescription(ShipmentRequest request, CompatibilityStatus status) {
    final type = request.estimatedType ?? 'Marchandise';
    final suffix = status == CompatibilityStatus.compatibleEffort
        ? ' — réagencement nécessaire'
        : '';
    return '$type, ${request.estimatedWeightKg.toInt()} kg → ${request.destination}$suffix';
  }
}
