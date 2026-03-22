import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/screens/role_selection_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/client/map/screens/client_map_screen.dart';
import '../../features/client/tracking/screens/tracking_list_screen.dart';
import '../../features/client/tracking/screens/tracking_detail_screen.dart';
import '../../features/driver/map/screens/driver_map_screen.dart';
import '../../features/driver/missions/screens/missions_list_screen.dart';
import '../../features/driver/missions/screens/mission_detail_screen.dart';
import '../../features/driver/missions/screens/ecmr_signature_screen.dart';
import '../../features/driver/incidents/screens/incident_report_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/role',
    redirect: (context, state) {
      final isOnRole = state.matchedLocation == '/role';
      if (auth == null && !isOnRole) return '/role';
      if (auth != null && isOnRole) {
        return auth.role.name == 'client' ? '/client' : '/driver';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/role',
        builder: (_, __) => const RoleSelectionScreen(),
      ),

      // ── Client ──────────────────────────────────────────────────────────
      GoRoute(
        path: '/client',
        builder: (_, __) => const ClientMapScreen(),
        routes: [
          GoRoute(
            path: 'tracking',
            builder: (_, __) => const TrackingListScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) => TrackingDetailScreen(
                  shipmentId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
        ],
      ),

      // ── Driver ──────────────────────────────────────────────────────────
      GoRoute(
        path: '/driver',
        builder: (_, __) => const DriverMapScreen(),
        routes: [
          GoRoute(
            path: 'missions',
            builder: (_, __) => const MissionsListScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) => MissionDetailScreen(
                  opportunityId: state.pathParameters['id']!,
                ),
              ),
              GoRoute(
                path: ':id/ecmr',
                builder: (_, state) => EcmrSignatureScreen(
                  opportunityId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'incident',
            builder: (_, state) => IncidentReportScreen(
              missionId: state.extra as String? ?? 'unknown',
            ),
          ),
        ],
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Page introuvable : ${state.error}')),
    ),
  );
});
