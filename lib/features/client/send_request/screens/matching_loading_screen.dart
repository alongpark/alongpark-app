import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/send_request_provider.dart';
import '../../../../core/theme/app_colors.dart';

class MatchingLoadingScreen extends ConsumerStatefulWidget {
  const MatchingLoadingScreen({super.key});

  @override
  ConsumerState<MatchingLoadingScreen> createState() =>
      _MatchingLoadingScreenState();
}

class _MatchingLoadingScreenState extends ConsumerState<MatchingLoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _stepIndex = 0;

  static const _steps = [
    'Analyse des disponibilités…',
    'Recherche du meilleur transport…',
    'Vérification de la compatibilité…',
    'Calcul de la route optimale…',
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _cycleSteps();
    _watchForResult();
  }

  void _cycleSteps() {
    Future.delayed(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      setState(() => _stepIndex = (_stepIndex + 1) % _steps.length);
      _cycleSteps();
    });
  }

  void _watchForResult() {
    // Poll state until search is done
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      final state = ref.read(sendRequestProvider);
      if (!state.isSearching) {
        if (state.proposal != null) {
          context.pushReplacement('/client/proposal');
        } else if (state.error != null) {
          context.pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.error!),
              backgroundColor: AppColors.danger,
            ),
          );
        }
        return;
      }
      _watchForResult();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(36),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated icon
              AnimatedBuilder(
                animation: _controller,
                builder: (_, __) => Transform.scale(
                  scale: 1.0 + _controller.value * 0.06,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.local_shipping_rounded,
                      color: AppColors.accent,
                      size: 48,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 48),

              const Text(
                'Moteur IA en cours',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),

              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _steps[_stepIndex],
                  key: ValueKey(_stepIndex),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 15,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 48),

              // Progress dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  return AnimatedBuilder(
                    animation: _controller,
                    builder: (_, __) {
                      final delay = i * 0.33;
                      final value =
                          (((_controller.value + delay) % 1.0) * 2 - 1).abs();
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        width: 8 + value * 4,
                        height: 8 + value * 4,
                        decoration: BoxDecoration(
                          color: AppColors.accent
                              .withOpacity(0.4 + value * 0.6),
                          shape: BoxShape.circle,
                        ),
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
