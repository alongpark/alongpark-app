import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' hide Position;
import '../../../../core/services/voice_service.dart';

import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../shared/models/transport_opportunity.dart';
import '../../missions/providers/missions_provider.dart';
import '../../../../core/utils/formatters.dart';

class DriverMapScreen extends ConsumerStatefulWidget {
  const DriverMapScreen({super.key});

  @override
  ConsumerState<DriverMapScreen> createState() => _DriverMapScreenState();
}

class _DriverMapScreenState extends ConsumerState<DriverMapScreen> {
  MapboxMap? _map;
  CircleAnnotationManager? _circleManager;
  CircleAnnotation? _driverCircle;

  // oppId → circle, circleId → opp
  final Map<String, CircleAnnotation> _circleByOppId = {};
  final Map<String, TransportOpportunity> _oppByCircleId = {};

  TransportOpportunity? _selectedOpp;
  List<TransportOpportunity> _latestOpps = [];
  bool _isInitialLoad = true;
  bool _syncing = false;

  final Set<String> _dismissedOppIds = {};
  final Set<String> _notifiedOppIds = {};

  // Voice state
  bool _isListening = false;
  int _listeningCountdown = 0;
  Timer? _listenTimer;

  // Polling
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _listenTimer?.cancel();
    VoiceService.stop();
    super.dispose();
  }

  void _refresh() {
    final user = ref.read(authProvider);
    if (user != null) {
      ref.read(opportunitiesProvider(user.id).notifier).refresh();
    }
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    _map = map;
    await map.gestures.updateSettings(GesturesSettings(rotateEnabled: false));
    await map.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    _circleManager = await map.annotations.createCircleAnnotationManager();
    _circleManager?.addOnCircleAnnotationClickListener(_CircleClickListener(this));
    await _locateMe();
    await _syncOpportunities(_latestOpps);
  }

  Future<void> _locateMe() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition();
      await _map?.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(pos.longitude, pos.latitude)),
          zoom: 11.0,
        ),
        MapAnimationOptions(duration: 800),
      );
      if (_driverCircle == null && _circleManager != null) {
        _driverCircle = await _circleManager!.create(CircleAnnotationOptions(
          geometry: Point(coordinates: Position(pos.longitude, pos.latitude)),
          circleRadius: 10.0,
          circleColor: const Color(0xFF00C896).value,
          circleStrokeWidth: 3.0,
          circleStrokeColor: Colors.white.value,
        ));
      }
    } catch (_) {}
  }

  Future<void> _syncOpportunities(List<TransportOpportunity> rawList) async {
    if (_circleManager == null || _syncing) return;
    _syncing = true;

    try {
      // Filter out dismissed ones
      final newList = rawList.where((o) => !_dismissedOppIds.contains(o.id)).toList();
      final newIds = newList.map((o) => o.id).toSet();
      final currentIds = Set<String>.from(_circleByOppId.keys);

      // Remove stale circles (except if it's the currently selected one!)
      for (final id in currentIds.difference(newIds)) {
        if (id == _selectedOpp?.id) continue; // Keep selected one sticky

        final circle = _circleByOppId.remove(id);
        if (circle != null) {
          _oppByCircleId.remove(circle.id);
          try {
            await _circleManager!.delete(circle);
          } catch (_) {}
        }
      }

      // Add new circles
      for (final opp in newList.where((o) => !currentIds.contains(o.id))) {
        final circle = await _circleManager!.create(CircleAnnotationOptions(
          geometry: Point(coordinates: Position(opp.pickupLng, opp.pickupLat)),
          circleRadius: 12.0,
          circleColor: const Color(0xFF0B1E3D).value,
          circleStrokeWidth: 3.0,
          circleStrokeColor: Colors.white.value,
        ));
        _circleByOppId[opp.id] = circle;
        _oppByCircleId[circle.id] = opp;

        // Auto-select and notify by voice ONLY if we've never seen this ID before in this session
        if (!_isInitialLoad && !_notifiedOppIds.contains(opp.id)) {
          _notifiedOppIds.add(opp.id);
          if (mounted) setState(() => _selectedOpp = opp);
          
          await _map?.flyTo(
            CameraOptions(
              center: Point(coordinates: Position(opp.pickupLng, opp.pickupLat)),
              zoom: 13.0,
            ),
            MapAnimationOptions(duration: 800),
          );
          
          final text = opp.clientVoiceInstruction ??
              'Nouvelle mission : ${opp.pickupLocation} vers ${opp.deliveryDestination}. '
                  'Revenus supplémentaires : ${formatPrice(opp.additionalRevenue)}. '
                  'Dites oui pour accepter.';
          
          final ttsError = await VoiceService.speak(text);
          if (ttsError != null && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Voix IA : $ttsError'),
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      }

      _isInitialLoad = false;
    } finally {
      _syncing = false;
    }
  }

  Future<void> _startVoiceAccept(TransportOpportunity opp) async {
    await VoiceService.stop();
    final started = await VoiceService.startListening();
    if (!started) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone indisponible')),
        );
      }
      return;
    }

    const duration = 5;
    setState(() {
      _isListening = true;
      _listeningCountdown = duration;
    });

    _listenTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted) {
        t.cancel();
        return;
      }
      final remaining = _listeningCountdown - 1;
      setState(() => _listeningCountdown = remaining);

      if (remaining <= 0) {
        t.cancel();
        final words = await VoiceService.stopListening();
        if (mounted) setState(() => _isListening = false);
        if (words == null) return;
        if (words.contains('oui') ||
            words.contains('accept') ||
            words.contains('ok') ||
            words.contains('accord')) {
          _acceptOpportunity(opp);
        } else if (words.contains('non') ||
            words.contains('refus')) {
          _refuseOpportunity(opp);
        }
      }
    });
  }

  Future<void> _acceptOpportunity(TransportOpportunity opp) async {
    final user = ref.read(authProvider);
    if (user == null) return;
    await ref.read(opportunitiesProvider(user.id).notifier).accept(opp.id);
    if (mounted) {
      setState(() => _selectedOpp = null);
      context.push('/driver/missions/${opp.id}/ecmr');
    }
  }

  Future<void> _refuseOpportunity(TransportOpportunity opp) async {
    final user = ref.read(authProvider);
    if (user == null) return;
    await ref.read(opportunitiesProvider(user.id).notifier).refuse(opp.id);
    if (mounted) setState(() => _selectedOpp = null);
  }

  void _onMarkerTapped(String circleId) {
    final opp = _oppByCircleId[circleId];
    if (opp != null) {
      setState(() => _selectedOpp = opp);
      _map?.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(opp.pickupLng, opp.pickupLat)),
          zoom: 14.0,
        ),
        MapAnimationOptions(duration: 500),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);

    ref.listen(
      opportunitiesProvider(user?.id ?? ''),
      (_, next) {
        next.whenData((list) {
          _latestOpps = list;
          _syncOpportunities(list);
        });
      },
    );

    return Scaffold(
      body: Stack(
        children: [
          // ── Map ──────────────────────────────────────────────────────────
          MapWidget(
            key: const ValueKey('driverMapbox'),
            cameraOptions: CameraOptions(
              center: Point(coordinates: Position(2.3522, 48.8566)),
              zoom: 5.0,
            ),
            styleUri: ref.watch(themeModeProvider) == ThemeMode.dark
                ? MapboxStyles.DARK
                : MapboxStyles.LIGHT,
            textureView: true,
            onMapCreated: _onMapCreated,
          ),

          // ── Top bar ───────────────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Row(
              children: [
                _Chip(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_shipping_rounded,
                          size: 15, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        user?.name ?? '',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.of(context).textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                _Chip(
                  padding: const EdgeInsets.all(4),
                  child: IconButton(
                    icon: Icon(Icons.logout_rounded,
                        size: 18, color: AppColors.of(context).textPrimary),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                        minWidth: 32, minHeight: 32),
                    onPressed: () {
                      ref.read(authProvider.notifier).logout();
                      context.go('/role');
                    },
                  ),
                ),
              ],
            ),
          ),

          // ── Listening indicator ───────────────────────────────────────────
          if (_isListening)
            Positioned(
              top: MediaQuery.of(context).padding.top + 68,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 16)
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.mic_rounded, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Parlez maintenant… ${_listeningCountdown}s',
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Opportunity card ──────────────────────────────────────────────
          if (_selectedOpp != null)
            Positioned(
              bottom: 32,
              left: 16,
              right: 16,
              child: _OpportunityCard(
                opp: _selectedOpp!,
                isListening: _isListening,
                onAccept: () => _acceptOpportunity(_selectedOpp!),
                onRefuse: () => _refuseOpportunity(_selectedOpp!),
                onVoice: () => _startVoiceAccept(_selectedOpp!),
                onDetails: () =>
                    context.push('/driver/missions/${_selectedOpp!.id}'),
                onDismiss: () {
                  final id = _selectedOpp?.id;
                  if (id != null) {
                    _dismissedOppIds.add(id);
                    final circle = _circleByOppId.remove(id);
                    if (circle != null) {
                      _oppByCircleId.remove(circle.id);
                      _circleManager?.delete(circle);
                    }
                  }
                  setState(() => _selectedOpp = null);
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────────

class _CircleClickListener extends OnCircleAnnotationClickListener {
  final _DriverMapScreenState state;
  _CircleClickListener(this.state);

  @override
  void onCircleAnnotationClick(CircleAnnotation annotation) {
    state._onMarkerTapped(annotation.id);
  }
}

class _Chip extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const _Chip({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.12), blurRadius: 12)
        ],
      ),
      child: child,
    );
  }
}

// ── Opportunity card ───────────────────────────────────────────────────────────

class _OpportunityCard extends StatelessWidget {
  final TransportOpportunity opp;
  final bool isListening;
  final VoidCallback onAccept;
  final VoidCallback onRefuse;
  final VoidCallback? onVoice;
  final VoidCallback onDetails;
  final VoidCallback onDismiss;

  const _OpportunityCard({
    required this.opp,
    required this.isListening,
    required this.onAccept,
    required this.onRefuse,
    this.onVoice,
    required this.onDetails,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 24,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 10, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${opp.pickupLocation} → ${opp.deliveryDestination}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '+${formatPrice(opp.additionalRevenue)}',
                            style: const TextStyle(
                              color: AppColors.compatibleCertain,
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '· +${formatDuration(opp.routeImpact)}',
                            style: TextStyle(fontSize: 12, color: c.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, size: 18, color: c.textMuted),
                  onPressed: onDismiss,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),

          // ── Cargo ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
            child: Row(
              children: [
                Icon(Icons.inventory_2_rounded, size: 14, color: c.textMuted),
                const SizedBox(width: 6),
                Text(
                  '${opp.merchandiseType} · ${formatWeight(opp.weightKg)}',
                  style: TextStyle(fontSize: 13, color: c.textPrimary),
                ),
              ],
            ),
          ),

          // ── Voice instruction ──────────────────────────────────────────
          if (opp.clientVoiceInstruction != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: AppColors.accent.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.record_voice_over_rounded,
                        color: AppColors.accent, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        opp.clientVoiceInstruction!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const Divider(height: 1),

          // ── Actions ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onRefuse,
                        style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger),
                        child: const Text('Refuser'),
                      ),
                    ),
                    if (onVoice != null) ...[
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: isListening ? null : onVoice,
                        icon: Icon(
                            isListening
                                ? Icons.hearing_rounded
                                : Icons.mic_rounded,
                            size: 20),
                        style: IconButton.styleFrom(
                          backgroundColor: isListening
                              ? AppColors.accent
                              : AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: onAccept,
                        child: const Text('Accepter'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: onDetails,
                  child: const Text(
                    'Voir les détails →',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
