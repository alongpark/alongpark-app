import 'enums.dart';

class TruckState {
  final String driverId;
  final String currentLocation;
  final String destination;
  final double freeVolumeM3;
  final double freeWeightKg;
  final DateTime eta;
  final TruckStatus status;
  final double totalVolumeM3;
  final double totalWeightKg;

  const TruckState({
    required this.driverId,
    required this.currentLocation,
    required this.destination,
    required this.freeVolumeM3,
    required this.freeWeightKg,
    required this.eta,
    required this.status,
    required this.totalVolumeM3,
    required this.totalWeightKg,
  });

  double get fillPercent =>
      totalVolumeM3 > 0 ? (1 - freeVolumeM3 / totalVolumeM3) * 100 : 0;

  TruckState copyWith({
    String? driverId,
    String? currentLocation,
    String? destination,
    double? freeVolumeM3,
    double? freeWeightKg,
    DateTime? eta,
    TruckStatus? status,
    double? totalVolumeM3,
    double? totalWeightKg,
  }) =>
      TruckState(
        driverId: driverId ?? this.driverId,
        currentLocation: currentLocation ?? this.currentLocation,
        destination: destination ?? this.destination,
        freeVolumeM3: freeVolumeM3 ?? this.freeVolumeM3,
        freeWeightKg: freeWeightKg ?? this.freeWeightKg,
        eta: eta ?? this.eta,
        status: status ?? this.status,
        totalVolumeM3: totalVolumeM3 ?? this.totalVolumeM3,
        totalWeightKg: totalWeightKg ?? this.totalWeightKg,
      );
}
