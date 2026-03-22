import 'enums.dart';

class TransportOpportunity {
  final String id;
  final String shipmentRequestId;
  final String driverId;
  final CompatibilityStatus compatibilityStatus;
  final double price;
  final DateTime estimatedArrival;
  final double additionalRevenue;
  final bool requiresRearrangement;
  final String description;
  final String merchandiseType;
  final double volumeM3;
  final double weightKg;
  final String pickupLocation;
  final double pickupLat;
  final double pickupLng;
  final String deliveryDestination;
  final Duration routeImpact;
  final String? clientVoiceInstruction;

  const TransportOpportunity({
    required this.id,
    required this.shipmentRequestId,
    required this.driverId,
    required this.compatibilityStatus,
    required this.price,
    required this.estimatedArrival,
    required this.additionalRevenue,
    required this.requiresRearrangement,
    required this.description,
    required this.merchandiseType,
    required this.volumeM3,
    required this.weightKg,
    required this.pickupLocation,
    required this.pickupLat,
    required this.pickupLng,
    required this.deliveryDestination,
    required this.routeImpact,
    this.clientVoiceInstruction,
  });

  TransportOpportunity copyWith({
    String? id,
    String? shipmentRequestId,
    String? driverId,
    CompatibilityStatus? compatibilityStatus,
    double? price,
    DateTime? estimatedArrival,
    double? additionalRevenue,
    bool? requiresRearrangement,
    String? description,
    String? merchandiseType,
    double? volumeM3,
    double? weightKg,
    String? pickupLocation,
    double? pickupLat,
    double? pickupLng,
    String? deliveryDestination,
    Duration? routeImpact,
    String? clientVoiceInstruction,
  }) =>
      TransportOpportunity(
        id: id ?? this.id,
        shipmentRequestId: shipmentRequestId ?? this.shipmentRequestId,
        driverId: driverId ?? this.driverId,
        compatibilityStatus: compatibilityStatus ?? this.compatibilityStatus,
        price: price ?? this.price,
        estimatedArrival: estimatedArrival ?? this.estimatedArrival,
        additionalRevenue: additionalRevenue ?? this.additionalRevenue,
        requiresRearrangement: requiresRearrangement ?? this.requiresRearrangement,
        description: description ?? this.description,
        merchandiseType: merchandiseType ?? this.merchandiseType,
        volumeM3: volumeM3 ?? this.volumeM3,
        weightKg: weightKg ?? this.weightKg,
        pickupLocation: pickupLocation ?? this.pickupLocation,
        pickupLat: pickupLat ?? this.pickupLat,
        pickupLng: pickupLng ?? this.pickupLng,
        deliveryDestination: deliveryDestination ?? this.deliveryDestination,
        routeImpact: routeImpact ?? this.routeImpact,
        clientVoiceInstruction: clientVoiceInstruction ?? this.clientVoiceInstruction,
      );
}
