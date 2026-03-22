import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/shipment_request.dart';
import '../../../../shared/models/transport_opportunity.dart';
import '../../../../shared/models/enums.dart';
import '../../../../shared/repositories/api/api_shipment_repository.dart';
import '../../../../shared/repositories/api/api_matching_repository.dart';

// ─── Repositories ────────────────────────────────────────────────────────────
final shipmentRepoProvider = Provider((_) => ApiShipmentRepository());
final matchingRepoProvider = Provider((_) => ApiMatchingRepository());

// ─── State ───────────────────────────────────────────────────────────────────
class SendRequestState {
  final String? imagePath;
  final String? estimatedType;
  final double? estimatedVolumeM3;
  final double? estimatedWeightKg;
  final String? destination;
  final String? recipientName;
  final bool isSearching;
  final TransportOpportunity? proposal;
  final ShipmentRequest? confirmedRequest;
  final String? error;

  const SendRequestState({
    this.imagePath,
    this.estimatedType,
    this.estimatedVolumeM3,
    this.estimatedWeightKg,
    this.destination,
    this.recipientName,
    this.isSearching = false,
    this.proposal,
    this.confirmedRequest,
    this.error,
  });

  SendRequestState copyWith({
    String? imagePath,
    String? estimatedType,
    double? estimatedVolumeM3,
    double? estimatedWeightKg,
    String? destination,
    String? recipientName,
    bool? isSearching,
    TransportOpportunity? proposal,
    ShipmentRequest? confirmedRequest,
    String? error,
  }) =>
      SendRequestState(
        imagePath: imagePath ?? this.imagePath,
        estimatedType: estimatedType ?? this.estimatedType,
        estimatedVolumeM3: estimatedVolumeM3 ?? this.estimatedVolumeM3,
        estimatedWeightKg: estimatedWeightKg ?? this.estimatedWeightKg,
        destination: destination ?? this.destination,
        recipientName: recipientName ?? this.recipientName,
        isSearching: isSearching ?? this.isSearching,
        proposal: proposal ?? this.proposal,
        confirmedRequest: confirmedRequest ?? this.confirmedRequest,
        error: error ?? this.error,
      );

  bool get isReadyToSearch =>
      estimatedWeightKg != null && destination != null && destination!.isNotEmpty;
}

// ─── Notifier ─────────────────────────────────────────────────────────────────
final sendRequestProvider =
    StateNotifierProvider<SendRequestNotifier, SendRequestState>(
  (ref) => SendRequestNotifier(ref),
);

class SendRequestNotifier extends StateNotifier<SendRequestState> {
  final Ref _ref;

  SendRequestNotifier(this._ref) : super(const SendRequestState());

  void setImage(String path) => state = state.copyWith(imagePath: path);

  void setMerchandiseInfo({
    String? type,
    double? volumeM3,
    required double weightKg,
  }) =>
      state = state.copyWith(
        estimatedType: type,
        estimatedVolumeM3: volumeM3,
        estimatedWeightKg: weightKg,
      );

  void setDestination({required String destination, String? recipientName}) =>
      state = state.copyWith(
        destination: destination,
        recipientName: recipientName,
      );

  Future<void> search(String clientId) async {
    if (!state.isReadyToSearch) return;
    state = state.copyWith(isSearching: true, error: null);

    try {
      final repo = _ref.read(shipmentRepoProvider);
      final matching = _ref.read(matchingRepoProvider);

      // 1. Create the shipment record
      final request = await repo.createShipment(ShipmentRequest(
        id: '',
        clientId: clientId,
        imagePath: state.imagePath,
        estimatedType: state.estimatedType,
        estimatedVolumeM3: state.estimatedVolumeM3,
        estimatedWeightKg: state.estimatedWeightKg!,
        destination: state.destination!,
        recipientName: state.recipientName,
        createdAt: DateTime.now(),
        status: ShipmentStatus.analyzing,
      ));

      // 2. Find best match
      final proposal = await matching.findBestMatch(request);

      if (proposal == null) {
        state = state.copyWith(
          isSearching: false,
          error: 'Aucun transport compatible trouvé pour le moment.',
        );
        return;
      }

      state = state.copyWith(
        isSearching: false,
        proposal: proposal,
        confirmedRequest: request,
      );
    } catch (e) {
      state = state.copyWith(
        isSearching: false,
        error: e.toString(),
      );
    }
  }

  Future<ShipmentRequest?> confirm() async {
    final request = state.confirmedRequest;
    final proposal = state.proposal;
    if (request == null || proposal == null) return null;

    final repo = _ref.read(shipmentRepoProvider);
    final updated = await repo.assignDriver(request.id, proposal.driverId);
    state = state.copyWith(confirmedRequest: updated);
    return updated;
  }

  void reset() => state = const SendRequestState();
}
