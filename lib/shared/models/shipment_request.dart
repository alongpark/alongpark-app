import 'enums.dart';

class ShipmentRequest {
  final String id;
  final String clientId;
  final String? imagePath;
  final String? estimatedType;
  final double? estimatedVolumeM3;
  final double estimatedWeightKg;
  final String destination;
  final String? recipientName;
  final DateTime? desiredSlot;
  final DateTime createdAt;
  final ShipmentStatus status;
  final String? assignedDriverId;

  const ShipmentRequest({
    required this.id,
    required this.clientId,
    this.imagePath,
    this.estimatedType,
    this.estimatedVolumeM3,
    required this.estimatedWeightKg,
    required this.destination,
    this.recipientName,
    this.desiredSlot,
    required this.createdAt,
    required this.status,
    this.assignedDriverId,
  });

  ShipmentRequest copyWith({
    String? id,
    String? clientId,
    String? imagePath,
    String? estimatedType,
    double? estimatedVolumeM3,
    double? estimatedWeightKg,
    String? destination,
    String? recipientName,
    DateTime? desiredSlot,
    DateTime? createdAt,
    ShipmentStatus? status,
    String? assignedDriverId,
  }) =>
      ShipmentRequest(
        id: id ?? this.id,
        clientId: clientId ?? this.clientId,
        imagePath: imagePath ?? this.imagePath,
        estimatedType: estimatedType ?? this.estimatedType,
        estimatedVolumeM3: estimatedVolumeM3 ?? this.estimatedVolumeM3,
        estimatedWeightKg: estimatedWeightKg ?? this.estimatedWeightKg,
        destination: destination ?? this.destination,
        recipientName: recipientName ?? this.recipientName,
        desiredSlot: desiredSlot ?? this.desiredSlot,
        createdAt: createdAt ?? this.createdAt,
        status: status ?? this.status,
        assignedDriverId: assignedDriverId ?? this.assignedDriverId,
      );
}
