import '../../models/shipment_request.dart';
import '../../models/transport_opportunity.dart';

abstract class MatchingRepository {
  /// Returns the single best opportunity for this shipment.
  /// Returns null if no compatible match found (rejected scenarios are filtered).
  Future<TransportOpportunity?> findBestMatch(ShipmentRequest request);
}
