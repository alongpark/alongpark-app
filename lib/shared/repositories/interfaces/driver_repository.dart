import '../../models/truck_state.dart';
import '../../models/transport_opportunity.dart';
import '../../models/incident_report.dart';

abstract class DriverRepository {
  Future<TruckState> getTruckState(String driverId);
  Future<List<TransportOpportunity>> getOpportunitiesForDriver(String driverId);
  Future<void> acceptOpportunity(String opportunityId);
  Future<void> refuseOpportunity(String opportunityId);
  Future<IncidentReport> reportIncident(IncidentReport report);
}
