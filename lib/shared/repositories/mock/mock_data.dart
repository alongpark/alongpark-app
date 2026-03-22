import '../../models/enums.dart';
import '../../models/shipment_request.dart';
import '../../models/transport_opportunity.dart';
import '../../models/truck_state.dart';

/// Realistic mock data for demo/prototype
class MockData {
  static final List<ShipmentRequest> shipments = [
    ShipmentRequest(
      id: 'ship-001',
      clientId: 'client-01',
      estimatedType: 'Boîtes carton',
      estimatedVolumeM3: 1.2,
      estimatedWeightKg: 45,
      destination: 'Lyon, 69003',
      recipientName: 'Entrepôt Rhône Sud',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      status: ShipmentStatus.inTransit,
      assignedDriverId: 'driver-01',
    ),
    ShipmentRequest(
      id: 'ship-002',
      clientId: 'client-01',
      estimatedType: 'Palette standard',
      estimatedVolumeM3: 2.4,
      estimatedWeightKg: 180,
      destination: 'Marseille, 13008',
      recipientName: 'BTP Provence SARL',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      status: ShipmentStatus.delivered,
      assignedDriverId: 'driver-02',
    ),
    ShipmentRequest(
      id: 'ship-003',
      clientId: 'client-01',
      estimatedType: 'Colis fragile',
      estimatedVolumeM3: 0.3,
      estimatedWeightKg: 12,
      destination: 'Bordeaux, 33000',
      createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      status: ShipmentStatus.analyzing,
    ),
  ];

  static final TruckState truckState = TruckState(
    driverId: 'driver-01',
    currentLocation: 'A6 — Mâcon Nord',
    destination: 'Lyon, Halle Tony Garnier',
    freeVolumeM3: 8.5,
    freeWeightKg: 2200,
    eta: DateTime.now().add(const Duration(hours: 1, minutes: 20)),
    status: TruckStatus.enRoute,
    totalVolumeM3: 33,
    totalWeightKg: 24000,
  );

  static final List<TransportOpportunity> opportunities = [
    TransportOpportunity(
      id: 'opp-001',
      shipmentRequestId: 'ship-003',
      driverId: 'driver-01',
      compatibilityStatus: CompatibilityStatus.compatibleCertain,
      price: 87.50,
      estimatedArrival: DateTime.now().add(const Duration(hours: 3, minutes: 15)),
      additionalRevenue: 87.50,
      requiresRearrangement: false,
      description: '1 colis fragile, 12 kg — dépose Bordeaux centre',
      merchandiseType: 'Colis fragile',
      volumeM3: 0.3,
      weightKg: 12,
      pickupLocation: 'Mâcon, Quai des Maraîchers',
      pickupLat: 46.30,
      pickupLng: 4.83,
      deliveryDestination: 'Bordeaux, 33000',
      routeImpact: const Duration(minutes: 18),
      clientVoiceInstruction: '▶ Transcrit par IA : "C\'est un vieux vase au dépôt de Mâcon, merci de bien caler la boîte à l\'arrière pour éviter les secousses sur l\'autoroute."',
    ),
    TransportOpportunity(
      id: 'opp-002',
      shipmentRequestId: 'ship-004',
      driverId: 'driver-01',
      compatibilityStatus: CompatibilityStatus.compatibleEffort,
      price: 145.00,
      estimatedArrival: DateTime.now().add(const Duration(hours: 4, minutes: 40)),
      additionalRevenue: 145.00,
      requiresRearrangement: true,
      description: '2 palettes, 340 kg — dépose Lyon Est — réagencement chargement requis',
      merchandiseType: '2 palettes standard',
      volumeM3: 4.8,
      weightKg: 340,
      pickupLocation: 'Chalon-sur-Saône, Zone Ind.',
      pickupLat: 46.78,
      pickupLng: 4.85,
      deliveryDestination: 'Lyon, 69008',
      routeImpact: const Duration(minutes: 35),
      clientVoiceInstruction: '▶ Transcrit par IA : "Le quai de chargement numéro 2 est bloqué, veuillez vous présenter à la grille arrière et sonner à l\'interphone. Attention, palettes très lourdes."',
    ),
  ];
}
