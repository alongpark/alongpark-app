import '../../models/shipment_request.dart';
import '../../models/enums.dart';
import '../interfaces/shipment_repository.dart';
import '../../../core/api/api_client.dart';

// Mapping statuts backend (snake_case) → enum Flutter
ShipmentStatus _parseStatus(String? raw) => switch (raw) {
  'matched'    => ShipmentStatus.matched,
  'confirmed'  => ShipmentStatus.confirmed,
  'picked_up'  => ShipmentStatus.pickedUp,
  'in_transit' => ShipmentStatus.inTransit,
  'delivered'  => ShipmentStatus.delivered,
  'cancelled'  => ShipmentStatus.issue,
  _            => ShipmentStatus.analyzing,
};

ShipmentRequest _fromJson(Map<String, dynamic> data) => ShipmentRequest(
  id:                  data['id'] as String,
  clientId:            data['client_id'] as String,
  estimatedWeightKg:   (data['estimated_weight_kg'] as num).toDouble(),
  estimatedVolumeM3:   data['estimated_volume_m3'] != null
                         ? (data['estimated_volume_m3'] as num).toDouble()
                         : null,
  estimatedType:       data['estimated_type'] as String?,
  destination:         data['destination_address'] as String,
  recipientName:       data['recipient_name'] as String?,
  createdAt:           DateTime.parse(data['created_at'] as String),
  status:              _parseStatus(data['status'] as String?),
  assignedDriverId:    data['assigned_driver_id'] as String?,
);

class ApiShipmentRepository implements ShipmentRepository {
  @override
  Future<ShipmentRequest> createShipment(ShipmentRequest request) async {
    final data = await ApiClient.post('/api/shipments/', {
      'client_id':           request.clientId,
      'image_url':           request.imagePath,
      'estimated_type':      request.estimatedType,
      'estimated_weight_kg': request.estimatedWeightKg,
      'estimated_volume_m3': request.estimatedVolumeM3,
      'origin_address':      'Position actuelle',
      'origin_lat':          48.8566,
      'origin_lng':          2.3522,
      'destination_address': request.destination,
      'destination_lat':     48.8566,
      'destination_lng':     2.3522,
      'recipient_name':      request.recipientName,
    });

    return request.copyWith(
      id:     data['id'] as String,
      status: ShipmentStatus.analyzing,
    );
  }

  @override
  Future<ShipmentRequest> assignDriver(String shipmentId, String driverId) async {
    return ShipmentRequest(
      id:                 shipmentId,
      clientId:           '',
      estimatedWeightKg:  0,
      destination:        '',
      createdAt:          DateTime.now(),
      status:             ShipmentStatus.confirmed,
      assignedDriverId:   driverId,
    );
  }

  @override
  Future<ShipmentRequest> getShipmentById(String id) async {
    final data = await ApiClient.get('/api/shipments/$id');
    return _fromJson(data);
  }

  @override
  Future<List<ShipmentRequest>> getShipmentsForClient(String clientId) async {
    try {
      final list = await ApiClient.getList('/api/shipments/?client_id=$clientId');
      return list.map((e) => _fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<ShipmentRequest> updateStatus(String id, ShipmentStatus status) async {
    await ApiClient.post('/api/shipments/$id/status', {
      'status': status.name,
    });
    return getShipmentById(id);
  }
}
