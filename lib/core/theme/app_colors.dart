import 'package:flutter/material.dart';

class AppColors extends ThemeExtension<AppColors> {
  // ── Brand (static — same in both modes) ─────────────────────────────────
  static const Color primary           = Color(0xFF3B82F6);
  static const Color accent            = Color(0xFF00C896);
  static const Color warning           = Color(0xFFFF9F0A);
  static const Color danger            = Color(0xFFFF453A);
  static const Color compatibleCertain = Color(0xFF30D158);
  static const Color compatibleEffort  = Color(0xFFFF9F0A);
  static const Color rejected          = Color(0xFFFF453A);

  // ── Adaptive (instance — varies per theme) ───────────────────────────────
  final Color background;
  final Color surface;
  final Color card;
  final Color cardBg;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  const AppColors({
    required this.background,
    required this.surface,
    required this.card,
    required this.cardBg,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
  });

  // ── Convenience accessor ─────────────────────────────────────────────────
  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>()!;

  // ── Presets ──────────────────────────────────────────────────────────────
  static const AppColors dark = AppColors(
    background:    Color(0xFF18181C),
    surface:       Color(0xFF222228),
    card:          Color(0xFF2C2C34),
    cardBg:        Color(0xFF2C2C34),
    border:        Color(0xFF38383F),
    textPrimary:   Color(0xFFF2F2F7),
    textSecondary: Color(0xFF9898A0),
    textMuted:     Color(0xFF5A5A64),
  );

  static const AppColors light = AppColors(
    background:    Color(0xFFF5F5F7),
    surface:       Color(0xFFFFFFFF),
    card:          Color(0xFFF2F2F7),
    cardBg:        Color(0xFFF2F2F7),
    border:        Color(0xFFD8D8DF),
    textPrimary:   Color(0xFF1C1C1E),
    textSecondary: Color(0xFF6C6C70),
    textMuted:     Color(0xFFAEAEB2),
  );

  // ── ThemeExtension impl ──────────────────────────────────────────────────
  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? card,
    Color? cardBg,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
  }) =>
      AppColors(
        background:    background    ?? this.background,
        surface:       surface       ?? this.surface,
        card:          card          ?? this.card,
        cardBg:        cardBg        ?? this.cardBg,
        border:        border        ?? this.border,
        textPrimary:   textPrimary   ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        textMuted:     textMuted     ?? this.textMuted,
      );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      background:    Color.lerp(background,    other.background,    t)!,
      surface:       Color.lerp(surface,       other.surface,       t)!,
      card:          Color.lerp(card,          other.card,          t)!,
      cardBg:        Color.lerp(cardBg,        other.cardBg,        t)!,
      border:        Color.lerp(border,        other.border,        t)!,
      textPrimary:   Color.lerp(textPrimary,   other.textPrimary,   t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted:     Color.lerp(textMuted,     other.textMuted,     t)!,
    );
  }
}
