import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/models/enums.dart';
import '../providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';

class RoleSelectionScreen extends ConsumerWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              // Logo / Brand
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.local_shipping_rounded,
                    color: AppColors.accent, size: 32),
              ),
              const SizedBox(height: 24),
              const Text(
                'NUX\nLogistics',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  letterSpacing: -1.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'La capacité inutilisée\ntransformée en valeur.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              const Spacer(),
              Text(
                'Continuer en tant que',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 14),
              _RoleCard(
                icon: Icons.person_rounded,
                title: 'Client expéditeur',
                subtitle: 'Envoyer et suivre vos marchandises',
                onTap: () {
                  ref.read(authProvider.notifier).loginAs(UserRole.client);
                  context.go('/client');
                },
              ),
              const SizedBox(height: 12),
              _RoleCard(
                icon: Icons.local_shipping_outlined,
                title: 'Chauffeur / Transporteur',
                subtitle: 'Gérer vos missions et opportunités',
                onTap: () {
                  ref.read(authProvider.notifier).loginAs(UserRole.driver);
                  context.go('/driver');
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.accent, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: Colors.white.withOpacity(0.4)),
            ],
          ),
        ),
      ),
    );
  }
}
