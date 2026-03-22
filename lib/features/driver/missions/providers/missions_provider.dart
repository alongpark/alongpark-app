import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/transport_opportunity.dart';
import '../../../driver/dashboard/providers/driver_dashboard_provider.dart';

final opportunitiesProvider =
    StateNotifierProvider.family<OpportunitiesNotifier, AsyncValue<List<TransportOpportunity>>, String>(
  (ref, driverId) => OpportunitiesNotifier(ref, driverId),
);

class OpportunitiesNotifier
    extends StateNotifier<AsyncValue<List<TransportOpportunity>>> {
  final Ref _ref;
  final String _driverId;

  OpportunitiesNotifier(this._ref, this._driverId)
      : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = _ref.read(driverRepoProvider);
      final list = await repo.getOpportunitiesForDriver(_driverId);
      state = AsyncValue.data(list);
    } catch (e, s) {
      state = AsyncValue.error(e, s);
    }
  }

  Future<void> accept(String opportunityId) async {
    final repo = _ref.read(driverRepoProvider);
    await repo.acceptOpportunity(opportunityId);
    await _load();
  }

  Future<void> refuse(String opportunityId) async {
    final repo = _ref.read(driverRepoProvider);
    await repo.refuseOpportunity(opportunityId);
    await _load();
  }

  Future<void> refresh() => _load();
}
