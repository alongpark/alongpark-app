import '../../models/shipment_request.dart';
import '../../models/enums.dart';

abstract class ShipmentRepository {
  Future<List<ShipmentRequest>> getShipmentsForClient(String clientId);
  Future<ShipmentRequest> getShipmentById(String id);
  Future<ShipmentRequest> createShipment(ShipmentRequest request);
  Future<ShipmentRequest> updateStatus(String id, ShipmentStatus status);
  Future<ShipmentRequest> assignDriver(String shipmentId, String driverId);
}
