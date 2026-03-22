import '../../models/shipment_request.dart';
import '../../models/transport_opportunity.dart';
import '../../models/enums.dart';
import '../interfaces/matching_repository.dart';
import '../../../core/api/api_client.dart';

class ApiMatchingRepository implements MatchingRepository {
  @override
  Future<TransportOpportunity?> findBestMatch(ShipmentRequest request) async {
    try {
      final data = await ApiClient.post('/api/matching/', {
        'shipment_id': request.id,
      });

      final status = _parseStatus(data['compatibility_status'] as String);
      final arrival = DateTime.parse(data['estimated_arrival'] as String);
      final impactMin = (data['route_impact_minutes'] as num?)?.toInt() ?? 20;

      return TransportOpportunity(
        id:                    data['match_id'] as String,
        shipmentRequestId:     request.id,
        driverId:              data['driver_id'] as String,
        compatibilityStatus:   status,
        price:                 (data['price'] as num).toDouble(),
        estimatedArrival:      arrival,
        additionalRevenue:     (data['price'] as num).toDouble(),
        requiresRearrangement: status == CompatibilityStatus.compatibleEffort,
        description:           data['description'] as String,
        merchandiseType:       request.estimatedType ?? 'Marchandise',
        volumeM3:              request.estimatedVolumeM3 ?? 0.5,
        weightKg:              request.estimatedWeightKg,
        pickupLocation:        request.destination,
        pickupLat:             (data['pickup_lat'] as num?)?.toDouble() ?? 48.8566,
        pickupLng:             (data['pickup_lng'] as num?)?.toDouble() ?? 2.3522,
        deliveryDestination:   request.destination,
        routeImpact:           Duration(minutes: impactMin),
        clientVoiceInstruction: data['voice_instruction'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  CompatibilityStatus _parseStatus(String s) {
    switch (s) {
      case 'certain': return CompatibilityStatus.compatibleCertain;
      case 'effort':  return CompatibilityStatus.compatibleEffort;
      default:        return CompatibilityStatus.rejected;
    }
  }
}
