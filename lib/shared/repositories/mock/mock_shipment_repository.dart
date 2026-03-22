import 'dart:math';
import '../../models/shipment_request.dart';
import '../../models/enums.dart';
import '../interfaces/shipment_repository.dart';
import 'mock_data.dart';

class MockShipmentRepository implements ShipmentRepository {
  // Mutable in-memory list so UI updates are reflected instantly
  final List<ShipmentRequest> _store = List.from(MockData.shipments);

  @override
  Future<List<ShipmentRequest>> getShipmentsForClient(String clientId) async {
    await _delay();
    return _store.where((s) => s.clientId == clientId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<ShipmentRequest> getShipmentById(String id) async {
    await _delay();
    return _store.firstWhere((s) => s.id == id);
  }

  @override
  Future<ShipmentRequest> createShipment(ShipmentRequest request) async {
    await _delay(ms: 600);
    final newRequest = request.copyWith(
      id: 'ship-${Random().nextInt(9999).toString().padLeft(4, '0')}',
      createdAt: DateTime.now(),
      status: ShipmentStatus.created,
    );
    _store.add(newRequest);
    return newRequest;
  }

  @override
  Future<ShipmentRequest> updateStatus(String id, ShipmentStatus status) async {
    await _delay();
    final idx = _store.indexWhere((s) => s.id == id);
    if (idx == -1) throw Exception('Shipment $id not found');
    final updated = _store[idx].copyWith(status: status);
    _store[idx] = updated;
    return updated;
  }

  @override
  Future<ShipmentRequest> assignDriver(String shipmentId, String driverId) async {
    await _delay();
    final idx = _store.indexWhere((s) => s.id == shipmentId);
    if (idx == -1) throw Exception('Shipment $shipmentId not found');
    final updated = _store[idx].copyWith(
      assignedDriverId: driverId,
      status: ShipmentStatus.matched,
    );
    _store[idx] = updated;
    return updated;
  }

  Future<void> _delay({int ms = 300}) =>
      Future.delayed(Duration(milliseconds: ms));
}
