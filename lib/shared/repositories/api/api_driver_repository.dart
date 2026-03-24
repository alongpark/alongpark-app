import '../../models/transport_opportunity.dart';
import '../../models/truck_state.dart';
import '../../models/incident_report.dart';
import '../../models/enums.dart';
import '../interfaces/driver_repository.dart';
import '../../../core/api/api_client.dart';

class ApiDriverRepository implements DriverRepository {
  @override
  Future<TruckState> getTruckState(String driverId) async {
    // No dedicated endpoint yet — return a sensible default.
    return TruckState(
      driverId: driverId,
      currentLocation: 'En route',
      destination: '',
      freeVolumeM3: 10.0,
      freeWeightKg: 1000.0,
      eta: DateTime.now().add(const Duration(hours: 1)),
      status: TruckStatus.enRoute,
      totalVolumeM3: 20.0,
      totalWeightKg: 2000.0,
    );
  }

  @override
  Future<List<TransportOpportunity>> getOpportunitiesForDriver(
      String driverId) async {
    final list = await ApiClient.getList('/api/matching/pending');
    return list
        .whereType<Map<String, dynamic>>()
        .map(_fromJson)
        .whereType<TransportOpportunity>()
        .toList();
  }

  @override
  Future<void> acceptOpportunity(String opportunityId) async {
    await ApiClient.post('/api/matching/$opportunityId/accept', {});
  }

  @override
  Future<void> refuseOpportunity(String opportunityId) async {
    await ApiClient.post('/api/matching/$opportunityId/refuse', {});
  }

  @override
  Future<IncidentReport> reportIncident(IncidentReport report) async {
    // Not backed by an API endpoint yet — return the report as-is.
    return report;
  }

  // ── parsing ────────────────────────────────────────────────────────────────

  TransportOpportunity? _fromJson(Map<String, dynamic> m) {
    try {
      final shipment = m['shipments'] as Map<String, dynamic>? ?? {};
      return TransportOpportunity(
        id: m['id'] as String,
        shipmentRequestId: m['shipment_id'] as String? ?? '',
        driverId: m['driver_id'] as String? ?? '',
        compatibilityStatus: _parseCompatibility(
            m['compatibility_status'] as String? ?? 'effort'),
        price: (m['price'] as num?)?.toDouble() ?? 0.0,
        estimatedArrival: DateTime.tryParse(
                m['estimated_arrival'] as String? ?? '') ??
            DateTime.now().add(const Duration(hours: 2)),
        additionalRevenue: (m['price'] as num?)?.toDouble() ?? 0.0,
        requiresRearrangement:
            (m['compatibility_status'] as String?) == 'effort',
        description: _buildDescription(m, shipment),
        merchandiseType:
            shipment['estimated_type'] as String? ?? 'Marchandise',
        volumeM3:
            (shipment['estimated_volume_m3'] as num?)?.toDouble() ?? 0.1,
        weightKg:
            (shipment['estimated_weight_kg'] as num?)?.toDouble() ?? 1.0,
        pickupLocation:
            shipment['origin_address'] as String? ?? 'Lieu inconnu',
        pickupLat: (shipment['origin_lat'] as num?)?.toDouble() ?? 48.8566,
        pickupLng: (shipment['origin_lng'] as num?)?.toDouble() ?? 2.3522,
        deliveryDestination:
            shipment['destination_address'] as String? ?? 'Destination inconnue',
        routeImpact: const Duration(minutes: 0),
      );
    } catch (_) {
      return null;
    }
  }

  CompatibilityStatus _parseCompatibility(String value) {
    switch (value) {
      case 'certain':
        return CompatibilityStatus.compatibleCertain;
      case 'effort':
        return CompatibilityStatus.compatibleEffort;
      default:
        return CompatibilityStatus.rejected;
    }
  }

  String _buildDescription(
      Map<String, dynamic> m, Map<String, dynamic> shipment) {
    final type = shipment['estimated_type'] as String? ?? 'colis';
    final kg =
        (shipment['estimated_weight_kg'] as num?)?.toStringAsFixed(1) ?? '?';
    final dest =
        shipment['destination_address'] as String? ?? 'destination ?';
    final price = (m['price'] as num?)?.toStringAsFixed(2) ?? '?';
    return '$type · $kg kg → $dest · ${price}€';
  }
}
