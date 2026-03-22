import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/shipment_request.dart';
import '../../send_request/providers/send_request_provider.dart';

final trackingProvider =
    FutureProvider.family<List<ShipmentRequest>, String>((ref, clientId) async {
  final repo = ref.read(shipmentRepoProvider);
  return repo.getShipmentsForClient(clientId);
});

final shipmentDetailProvider =
    FutureProvider.family<ShipmentRequest, String>((ref, shipmentId) async {
  final repo = ref.read(shipmentRepoProvider);
  return repo.getShipmentById(shipmentId);
});
