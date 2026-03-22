import '../../models/truck_state.dart';
import '../../models/transport_opportunity.dart';
import '../../models/incident_report.dart';
import '../interfaces/driver_repository.dart';
import 'mock_data.dart';

class MockDriverRepository implements DriverRepository {
  TruckState _truckState = MockData.truckState;
  final List<TransportOpportunity> _opportunities = List.from(MockData.opportunities);
  final List<IncidentReport> _incidents = [];

  @override
  Future<TruckState> getTruckState(String driverId) async {
    await _delay();
    return _truckState;
  }

  @override
  Future<List<TransportOpportunity>> getOpportunitiesForDriver(String driverId) async {
    await _delay();
    return _opportunities.where((o) => o.driverId == driverId).toList();
  }

  @override
  Future<void> acceptOpportunity(String opportunityId) async {
    await _delay(ms: 500);
    _opportunities.removeWhere((o) => o.id == opportunityId);
    // Simulate truck space being consumed
    _truckState = _truckState.copyWith(
      freeVolumeM3: (_truckState.freeVolumeM3 - 0.3).clamp(0, double.infinity),
      freeWeightKg: (_truckState.freeWeightKg - 12).clamp(0, double.infinity),
    );
  }

  @override
  Future<void> refuseOpportunity(String opportunityId) async {
    await _delay();
    _opportunities.removeWhere((o) => o.id == opportunityId);
  }

  @override
  Future<IncidentReport> reportIncident(IncidentReport report) async {
    await _delay(ms: 400);
    _incidents.add(report);
    return report;
  }

  Future<void> _delay({int ms = 300}) =>
      Future.delayed(Duration(milliseconds: ms));
}
