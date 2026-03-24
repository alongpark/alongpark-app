import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart' hide Position;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart' as img_picker;
import '../../send_request/providers/send_request_provider.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/status_badge.dart';
import 'scan_estimate_screen.dart';
import '../../../../core/config/app_secrets.dart';

// ── Suggestions ───────────────────────────────────────────────────────────────
typedef _Place = ({String label, double lng, double lat});

// ── Screen ────────────────────────────────────────────────────────────────────
class ClientMapScreen extends ConsumerStatefulWidget {
  const ClientMapScreen({super.key});

  @override
  ConsumerState<ClientMapScreen> createState() => _ClientMapScreenState();
}

class _ClientMapScreenState extends ConsumerState<ClientMapScreen> {
  final _sheetController = DraggableScrollableController();
  final _destinationController = TextEditingController();
  final _weightController = TextEditingController();

  MapboxMap? _map;
  CircleAnnotationManager? _circleManager;
  PolylineAnnotationManager? _polylineManager;
  CircleAnnotation? _pickupCircle;
  CircleAnnotation? _destinationCircle;
  PolylineAnnotation? _routeLine;

  double _pickupLng = 2.3522;
  double _pickupLat = 48.8566;

  List<_Place> _suggestions = [];
  bool _showSuggestions = false;
  bool _isLoadingSuggestions = false;
  bool _isEstimating = false;
  Timer? _debounce;

  static const _mapboxToken = AppSecrets.mapboxToken;

  @override
  void initState() {
    super.initState();
    _locateMe();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _destinationController.dispose();
    _weightController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  // ── Map setup ──────────────────────────────────────────────────────────────
  Future<void> _onMapCreated(MapboxMap map) async {
    _map = map;
    await map.gestures.updateSettings(GesturesSettings(rotateEnabled: false));
    await map.scaleBar.updateSettings(ScaleBarSettings(enabled: false));

    _circleManager =
        await map.annotations.createCircleAnnotationManager();
    _polylineManager =
        await map.annotations.createPolylineAnnotationManager();

    _pickupCircle = await _circleManager?.create(CircleAnnotationOptions(
      geometry: Point(coordinates: Position(_pickupLng, _pickupLat)),
      circleRadius: 9.0,
      circleColor: const Color(0xFF0B1E3D).value,
      circleStrokeWidth: 3.0,
      circleStrokeColor: Colors.white.value,
    ));
  }

  // ── Location ───────────────────────────────────────────────────────────────
  Future<void> _locateMe() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition();
      _pickupLng = pos.longitude;
      _pickupLat = pos.latitude;

      await _map?.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(_pickupLng, _pickupLat)),
          zoom: 13.0,
        ),
        MapAnimationOptions(duration: 800),
      );

      // Update pickup circle position
      if (_pickupCircle != null) {
        _pickupCircle!.geometry =
            Point(coordinates: Position(_pickupLng, _pickupLat));
        await _circleManager?.update(_pickupCircle!);
      }
    } catch (_) {}
  }

  // ── Destination ────────────────────────────────────────────────────────────
  void _onDestinationChanged(String value) {
    final q = value.trim();
    if (q.isEmpty) {
      _debounce?.cancel();
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
        _isLoadingSuggestions = false;
      });
      if (_sheetController.size > 0.30) {
        _sheetController.animateTo(
          0.30,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
      return;
    }

    if (_sheetController.size < 0.90) {
      _sheetController.animateTo(
        0.90,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _fetchSuggestions(q));
  }

  Future<void> _fetchSuggestions(String query) async {
    setState(() => _isLoadingSuggestions = true);
    try {
      final url = Uri.parse(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/'
        '${Uri.encodeComponent(query)}.json'
        '?access_token=$_mapboxToken&language=fr&country=fr&limit=6',
      );
      final res = await http.get(url);
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        final features = data['features'] as List? ?? [];
        final results = features.map<_Place>((f) {
          final coords = (f['geometry']['coordinates'] as List);
          return (
            label: f['place_name'] as String,
            lng: (coords[0] as num).toDouble(),
            lat: (coords[1] as num).toDouble(),
          );
        }).toList();
        setState(() {
          _suggestions = results;
          _showSuggestions = results.isNotEmpty;
          _isLoadingSuggestions = false;
        });
      } else {
        setState(() => _isLoadingSuggestions = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingSuggestions = false);
    }
  }

  Future<void> _selectDestination(_Place place) async {
    _destinationController.text = place.label;
    setState(() => _showSuggestions = false);
    ref
        .read(sendRequestProvider.notifier)
        .setDestination(destination: place.label);
    FocusScope.of(context).unfocus();

    // Draw route in background — sheet stays open to continue the process
    _drawRoute(place.lng, place.lat);

    _sheetController.animateTo(
      0.35,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  Future<void> _drawRoute(double lng, double lat) async {
    // Remove old elements
    if (_routeLine != null) {
      await _polylineManager?.delete(_routeLine!);
      _routeLine = null;
    }
    if (_destinationCircle != null) {
      await _circleManager?.delete(_destinationCircle!);
      _destinationCircle = null;
    }

    // Fetch real road route from Mapbox Directions API
    final routeCoords = await _fetchRoute(_pickupLng, _pickupLat, lng, lat);

    _routeLine = await _polylineManager?.create(PolylineAnnotationOptions(
      geometry: LineString(coordinates: routeCoords),
      lineWidth: 4.0,
      lineColor: const Color(0xFF00C896).value,
      lineBorderWidth: 1.5,
      lineBorderColor: const Color(0xFF005C45).value,
    ));

    _destinationCircle = await _circleManager?.create(CircleAnnotationOptions(
      geometry: Point(coordinates: Position(lng, lat)),
      circleRadius: 10.0,
      circleColor: const Color(0xFF00C896).value,
      circleStrokeWidth: 3.0,
      circleStrokeColor: Colors.white.value,
    ));

    // Fit camera — center between pickup and destination
    final midLng = (_pickupLng + lng) / 2;
    final midLat = (_pickupLat + lat) / 2;
    await _map?.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(midLng, midLat)),
        zoom: 5.5,
        padding: MbxEdgeInsets(top: 80, left: 40, bottom: 340, right: 40),
      ),
      MapAnimationOptions(duration: 1000),
    );
  }

  Future<List<Position>> _fetchRoute(
    double fromLng, double fromLat, double toLng, double toLat) async {
    try {
      final url = Uri.parse(
        'https://api.mapbox.com/directions/v5/mapbox/driving/'
        '$fromLng,$fromLat;$toLng,$toLat'
        '?geometries=geojson&overview=full&access_token=$_mapboxToken',
      );
      final res = await http.get(url);
      if (res.statusCode != 200) {
        return [Position(fromLng, fromLat), Position(toLng, toLat)];
      }
      final data = json.decode(res.body) as Map<String, dynamic>;
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) {
        return [Position(fromLng, fromLat), Position(toLng, toLat)];
      }
      final coords =
          routes[0]['geometry']['coordinates'] as List;
      return coords
          .map((c) => Position((c[0] as num).toDouble(), (c[1] as num).toDouble()))
          .toList();
    } catch (_) {
      // Fallback to straight line
      return [Position(fromLng, fromLat), Position(toLng, toLat)];
    }
  }

  // ── Camera + Scan ───────────────────────────────────────────────────────────
  Future<void> _onPickImagePressed() async {
    final c = AppColors.of(context);
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Source de l\'image', 
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.textPrimary)
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _SourceTile(
                    icon: Icons.camera_alt_rounded,
                    label: 'Appareil photo',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(img_picker.ImageSource.camera);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SourceTile(
                    icon: Icons.photo_library_rounded,
                    label: 'Galerie photo',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(img_picker.ImageSource.gallery);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(img_picker.ImageSource source) async {
    if (_isEstimating) return;

    final picker = img_picker.ImagePicker();
    final image = await picker.pickImage(
      source: source,
      imageQuality: 75,
      maxWidth: 1080,
      maxHeight: 1080,
      preferredCameraDevice: img_picker.CameraDevice.rear,
    );
    if (image == null || !mounted) return;

    setState(() => _isEstimating = true);

    final result = await Navigator.push<({String type, double weightKg, double volumeM3})>(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            ScanEstimateScreen(imagePath: image.path),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 250),
        fullscreenDialog: true,
      ),
    );

    if (!mounted) return;
    setState(() => _isEstimating = false);

    if (result != null) {
      ref.read(sendRequestProvider.notifier)
        ..setImage(image.path)
        ..setMerchandiseInfo(
            type: result.type,
            volumeM3: result.volumeM3,
            weightKg: result.weightKg);
      _weightController.text = result.weightKg.toStringAsFixed(1);
      _sheetController.animateTo(0.35,
          duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
    }
  }

  // ── Search / confirm ───────────────────────────────────────────────────────
  Future<void> _search() async {
    final user = ref.read(authProvider);
    if (user == null) return;
    await ref.read(sendRequestProvider.notifier).search(user.id);
  }

  Future<void> _confirm() async {
    await ref.read(sendRequestProvider.notifier).confirm();
    if (mounted) {
      context.push('/client/tracking');
      ref.read(sendRequestProvider.notifier).reset();
      _resetForm();
    }
  }

  void _resetForm() {
    _destinationController.clear();
    _weightController.clear();
    setState(() {
      _suggestions = [];
      _showSuggestions = false;
    });
    _routeLine = null;
    _destinationCircle = null;
    _polylineManager?.deleteAll();
    _circleManager?.deleteAll();
    // Re-add pickup circle
    _circleManager?.create(CircleAnnotationOptions(
      geometry: Point(coordinates: Position(_pickupLng, _pickupLat)),
      circleRadius: 9.0,
      circleColor: const Color(0xFF0B1E3D).value,
      circleStrokeWidth: 3.0,
      circleStrokeColor: Colors.white.value,
    ));
    _map?.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(_pickupLng, _pickupLat)),
        zoom: 13.0,
      ),
      MapAnimationOptions(duration: 600),
    );
    _sheetController.animateTo(0.30,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(sendRequestProvider);

    // Auto-expand sheet when proposal arrives
    ref.listen<SendRequestState>(sendRequestProvider, (prev, next) {
      if (prev?.proposal == null && next.proposal != null) {
        _sheetController.animateTo(0.58,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut);
      }
    });

    // Switch map style with theme
    ref.listen<ThemeMode>(themeModeProvider, (_, mode) {
      _map?.loadStyleURI(
        mode == ThemeMode.dark ? MapboxStyles.DARK : MapboxStyles.MAPBOX_STREETS,
      );
    });

    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: Stack(
        children: [
          // ── Mapbox ───────────────────────────────────────────────────────
          MapWidget(
            key: const ValueKey('mapbox'),
            styleUri: MapboxStyles.DARK,
            cameraOptions: CameraOptions(
              center: Point(
                  coordinates: Position(_pickupLng, _pickupLat)),
              zoom: 13.0,
            ),
            onMapCreated: _onMapCreated,
          ),

          // ── Top-right FABs ───────────────────────────────────────────────
          Positioned(
            top: topPad + 12,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _MapFab(icon: Icons.my_location_rounded, onTap: _locateMe),
                const SizedBox(height: 10),
                Consumer(builder: (context, ref, _) {
                  final mode = ref.watch(themeModeProvider);
                  final isDark = mode == ThemeMode.dark;
                  return _MapFab(
                    icon: isDark
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded,
                    onTap: () => ref.read(themeModeProvider.notifier).state =
                        isDark ? ThemeMode.light : ThemeMode.dark,
                  );
                }),
              ],
            ),
          ),

          // ── Bottom sheet ─────────────────────────────────────────────────
          DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: 0.35,
            minChildSize: 0.15,
            maxChildSize: 0.90,
            snap: true,
            snapSizes: const [0.15, 0.35, 0.68, 0.90],
            builder: (context, scrollController) => _Sheet(
              scrollController: scrollController,
              state: state,
              destinationController: _destinationController,
              suggestions: _suggestions,
              showSuggestions: _showSuggestions,
              isLoadingSuggestions: _isLoadingSuggestions,
              onDestinationChanged: _onDestinationChanged,
              onSelectDestination: _selectDestination,
              weightController: _weightController,
              onWeightChanged: (w) {
                final kg = double.tryParse(w);
                if (kg != null) {
                  ref.read(sendRequestProvider.notifier)
                      .setMerchandiseInfo(weightKg: kg);
                }
              },
              onPickImage: _onPickImagePressed,
              isEstimating: _isEstimating,
              onSearch: _search,
              onConfirm: _confirm,
              onReset: () {
                ref.read(sendRequestProvider.notifier).reset();
                _resetForm();
              },
              onTracking: () => context.push('/client/tracking'),
              onLogout: () {
                ref.read(authProvider.notifier).logout();
                context.go('/role');
              },
            ),
          ),
        ],
      ),
    );
  }
}


// ── Sheet ─────────────────────────────────────────────────────────────────────
class _Sheet extends StatelessWidget {
  final ScrollController scrollController;
  final SendRequestState state;
  final TextEditingController destinationController;
  final List<_Place> suggestions;
  final bool showSuggestions;
  final bool isLoadingSuggestions;
  final void Function(String) onDestinationChanged;
  final void Function(_Place) onSelectDestination;
  final TextEditingController weightController;
  final void Function(String) onWeightChanged;
  final VoidCallback onPickImage;
  final bool isEstimating;
  final VoidCallback onSearch;
  final VoidCallback onConfirm;
  final VoidCallback onReset;
  final VoidCallback onTracking;
  final VoidCallback onLogout;

  const _Sheet({
    required this.scrollController,
    required this.state,
    required this.destinationController,
    required this.suggestions,
    required this.showSuggestions,
    required this.isLoadingSuggestions,
    required this.onDestinationChanged,
    required this.onSelectDestination,
    required this.weightController,
    required this.onWeightChanged,
    required this.onPickImage,
    required this.isEstimating,
    required this.onSearch,
    required this.onConfirm,
    required this.onReset,
    required this.onTracking,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ListView(
        controller: scrollController,
        padding: EdgeInsets.zero,
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 6),
              child: Container(
                width: 32,
                height: 3,
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
                20, 4, 20, MediaQuery.of(context).padding.bottom + 20),
            child: _buildContent(context),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (state.isSearching) return const _SearchingView();
    if (state.proposal != null) {
      return _ProposalView(state: state, onConfirm: onConfirm, onReset: onReset);
    }

    final c = AppColors.of(context);
    final hasDestination = state.destination != null;
    final hasEstimation = state.imagePath != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Title row
        Row(
          children: [
            Expanded(
              child: Text(
                'Expédier un colis',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.1,
                  color: c.textPrimary,
                ),
              ),
            ),
            if (hasDestination)
              GestureDetector(
                onTap: onReset,
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: c.border),
                  ),
                  child: Icon(Icons.close_rounded, size: 15, color: c.textMuted),
                ),
              )
            else ...[
              GestureDetector(
                onTap: onTracking,
                child: const Text('Mes envois',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.accent,
                        fontWeight: FontWeight.w500)),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: onLogout,
                child: Text('Quitter',
                    style: TextStyle(fontSize: 12, color: c.textMuted)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),

        // ── Journey card — toutes les étapes connectées
        _JourneyCard(
          destinationController: destinationController,
          weightController: weightController,
          destinationDone: hasDestination,
          hasEstimation: hasEstimation,
          isEstimating: isEstimating,
          state: state,
          onDestinationChanged: onDestinationChanged,
          onPickImage: onPickImage,
          onWeightChanged: onWeightChanged,
        ),

        // ── Suggestions (sous la carte)
        if (isLoadingSuggestions) ...[
          const SizedBox(height: 8),
          const Center(
            child: SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.accent),
            ),
          ),
        ] else if (showSuggestions) ...[
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.border),
            ),
            child: Column(
              children: suggestions
                  .map((p) => _SuggestionTile(
                      label: p.label, onTap: () => onSelectDestination(p)))
                  .toList(),
            ),
          ),
        ],

        // ── CTA
        if (state.isReadyToSearch) ...[
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onSearch,
              style: FilledButton.styleFrom(
                backgroundColor: c.textPrimary,
                foregroundColor: c.surface,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text(
                'Trouver un transporteur',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Sub-views ──────────────────────────────────────────────────────────────────
class _SearchingView extends StatelessWidget {
  const _SearchingView();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
                color: AppColors.accent, strokeWidth: 3),
          ),
          const SizedBox(height: 18),
          Text('Recherche en cours…',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary)),
          const SizedBox(height: 4),
          Text("Nous trouvons le meilleur transporteur",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12, color: c.textSecondary, height: 1.4)),
        ],
      ),
    );
  }
}

class _ProposalView extends StatelessWidget {
  final SendRequestState state;
  final VoidCallback onConfirm;
  final VoidCallback onReset;

  const _ProposalView(
      {required this.state, required this.onConfirm, required this.onReset});

  Widget _buildVehicleImage(String desc) {
    final d = desc.toLowerCase();
    if (d.contains('vélo') || d.contains('velo')) return Image.asset('asset/veloCargo.png', height: 28);
    if (d.contains('fourgon') || d.contains('van')) return Image.asset('asset/fourgon.png', height: 28);
    if (d.contains('porteur') || d.contains('camion')) return Image.asset('asset/porteur.png', height: 28);
    return Image.asset('asset/fourgon.png', height: 28); // fallback
  }

  @override
  Widget build(BuildContext context) {
    final p = state.proposal!;
    final c = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Expanded(
              child: Text('Transport trouvé',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                      color: c.textPrimary)),
            ),
            CompatibilityBadge(status: p.compatibilityStatus),
          ],
        ),
        const SizedBox(height: 4),
        Text(state.destination ?? '',
            style: TextStyle(fontSize: 13, color: c.textSecondary),
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 24),

        // Big price
        Center(
          child: Column(
            children: [
              Text(formatPrice(p.price),
                  style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.8,
                      color: c.textPrimary)),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: c.border),
                ),
                child: Text('Livraison ${formatEta(p.estimatedArrival)}',
                    style:
                        TextStyle(fontSize: 12, color: c.textSecondary)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Driver card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_rounded,
                    color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.description,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: c.textPrimary),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('+${formatDuration(p.routeImpact)} sur le trajet',
                        style:
                            TextStyle(fontSize: 12, color: c.textSecondary)),
                  ],
                ),
              ),
              _buildVehicleImage(p.description),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Actions
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onReset,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: c.border),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('Annuler',
                    style: TextStyle(color: c.textSecondary)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: onConfirm,
                style: FilledButton.styleFrom(
                  backgroundColor: c.textPrimary,
                  foregroundColor: c.surface,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text("Confirmer l'envoi",
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Journey card — toutes étapes connectées ───────────────────────────────────
class _JourneyCard extends StatelessWidget {
  final TextEditingController destinationController;
  final TextEditingController weightController;
  final bool destinationDone;
  final bool hasEstimation;
  final bool isEstimating;
  final SendRequestState state;
  final void Function(String) onDestinationChanged;
  final VoidCallback onPickImage;
  final void Function(String) onWeightChanged;

  const _JourneyCard({
    required this.destinationController,
    required this.weightController,
    required this.destinationDone,
    required this.hasEstimation,
    required this.isEstimating,
    required this.state,
    required this.onDestinationChanged,
    required this.onPickImage,
    required this.onWeightChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Row 1 : Ma position
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(children: [
              _DotIcon(color: AppColors.primary, filled: true),
              const SizedBox(width: 10),
              Text('Ma position',
                  style: TextStyle(
                      fontSize: 13,
                      color: c.textSecondary,
                      fontWeight: FontWeight.w400)),
            ]),
          ),

          // ── Connector 1
          _Connector(),

          // ── Row 2 : Destination
          Padding(
            padding: EdgeInsets.fromLTRB(14, 0, 14, destinationDone ? 0 : 12),
            child: Row(children: [
              _DotIcon(
                color: destinationDone ? AppColors.accent : c.border,
                filled: destinationDone,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: destinationController,
                  onChanged: onDestinationChanged,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: destinationDone ? FontWeight.w500 : FontWeight.w400,
                    color: c.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Où livrer ?',
                    hintStyle: TextStyle(color: c.textMuted, fontSize: 13),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    filled: false,
                  ),
                ),
              ),
              if (destinationDone)
                const Icon(Icons.check_circle_rounded,
                    size: 13, color: AppColors.accent),
            ]),
          ),

          // ── Connector 2 + Step estimation (si destination remplie)
          if (destinationDone) ...[
            _Connector(),
            // ── Row 3 : Estimation / Poids
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: hasEstimation
                  ? _EstimationRow(
                      state: state,
                      weightController: weightController,
                      onWeightChanged: onWeightChanged,
                      onRetake: onPickImage,
                    )
                  : _MeasureRow(
                      isEstimating: isEstimating,
                      onTap: onPickImage,
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Connector extends StatelessWidget {
  const _Connector();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 21),
      child: Container(width: 1, height: 14, color: AppColors.of(context).border),
    );
  }
}

class _MeasureRow extends StatelessWidget {
  final bool isEstimating;
  final VoidCallback onTap;
  const _MeasureRow({required this.isEstimating, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: isEstimating ? null : onTap,
      child: Row(children: [
        SizedBox(
          width: 8, height: 8,
          child: isEstimating
              ? const CircularProgressIndicator(
                  strokeWidth: 1.5, color: AppColors.accent)
              : Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: c.border, width: 1.5),
                  ),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            isEstimating ? 'Analyse en cours…' : 'Estimer les dimensions',
            style: TextStyle(
              fontSize: 13,
              color: isEstimating ? c.textMuted : c.textSecondary,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        if (!isEstimating)
          Icon(Icons.chevron_right_rounded, size: 16, color: c.textMuted),
      ]),
    );
  }
}

class _EstimationRow extends StatelessWidget {
  final SendRequestState state;
  final TextEditingController weightController;
  final void Function(String) onWeightChanged;
  final VoidCallback onRetake;

  const _EstimationRow({
    required this.state,
    required this.weightController,
    required this.onWeightChanged,
    required this.onRetake,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final type = state.estimatedType ?? 'Colis';
    final volume = state.estimatedVolumeM3?.toStringAsFixed(2) ?? '—';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _DotIcon(color: AppColors.accent, filled: true),
        const SizedBox(width: 12),
        // Inline weight field
        IntrinsicWidth(
          child: TextField(
            controller: weightController,
            onChanged: onWeightChanged,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.textPrimary),
            decoration: InputDecoration(
              hintText: '—',
              hintStyle: TextStyle(color: c.textMuted),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              filled: false,
            ),
          ),
        ),
        Text(' kg',
            style: TextStyle(fontSize: 12, color: c.textSecondary)),
        const SizedBox(width: 10),
        _MiniChip(label: type),
        const SizedBox(width: 6),
        _MiniChip(label: '$volume m³'),
        const Spacer(),
        GestureDetector(
          onTap: onRetake,
          child: const Text('Ré-estimer',
              style: TextStyle(
                  fontSize: 11,
                  color: AppColors.accent,
                  fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}

class _SourceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SourceTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Material(
      color: c.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              Icon(icon, color: AppColors.primary, size: 28),
              const SizedBox(height: 10),
              Text(label, 
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: c.textPrimary)
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  const _MiniChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: c.textSecondary)),
    );
  }
}

class _DotIcon extends StatelessWidget {
  final Color color;
  final bool filled;

  const _DotIcon({required this.color, required this.filled});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? color : Colors.transparent,
        border: Border.all(color: color, width: 1.5),
      ),
    );
  }
}


// ── Map FAB ───────────────────────────────────────────────────────────────────
class _MapFab extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MapFab({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Material(
      color: c.surface,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, size: 20, color: c.textPrimary),
        ),
      ),
    );
  }
}

// ── Suggestion tile ───────────────────────────────────────────────────────────
class _SuggestionTile extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SuggestionTile({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Icon(Icons.location_on_outlined, size: 16, color: c.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: TextStyle(fontSize: 14, color: c.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            Icon(Icons.north_west_rounded, size: 12, color: c.textMuted),
          ],
        ),
      ),
    );
  }
}
