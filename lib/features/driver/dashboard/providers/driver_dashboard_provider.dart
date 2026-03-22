import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/truck_state.dart';
import '../../../../shared/repositories/mock/mock_driver_repository.dart';

final driverRepoProvider = Provider((_) => MockDriverRepository());

final truckStateProvider =
    FutureProvider.family<TruckState, String>((ref, driverId) async {
  final repo = ref.read(driverRepoProvider);
  return repo.getTruckState(driverId);
});
