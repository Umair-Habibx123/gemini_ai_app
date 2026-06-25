import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized color tokens for the app, exposed as a [ThemeExtension] so every
/// widget can read the right value for the active (light / dark) theme via
/// `context.colors` instead of hardcoding hex values.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color background; // scaffold background
  final Color surface; // cards, input bar, bubbles
  final Color surfaceAlt; // appbar, drawer, sheets
  final Color textPrimary;
  final Color textSecondary;
  final Color textFaint;
  final Color border;
  final Color primary; // brand purple
  final Color secondary; // brand teal
  final Color userBubble; // start of user bubble gradient
  final Color userBubbleEnd;

  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.textPrimary,
    required this.textSecondary,
    required this.textFaint,
    required this.border,
    required this.primary,
    required this.secondary,
    required this.userBubble,
    required this.userBubbleEnd,
  });

  /// Brand gradient — identical across both themes for a consistent identity.
  LinearGradient get brandGradient => LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const _purple = Color(0xFF6C63FF);
  static const _teal = Color(0xFF00D4AA);

  static const dark = AppColors(
    background: Color(0xFF0A0A12),
    surface: Color(0xFF13131F),
    surfaceAlt: Color(0xFF0D0D18),
    textPrimary: Colors.white,
    textSecondary: Color(0xB3FFFFFF), // white 70%
    textFaint: Color(0x59FFFFFF), // white 35%
    border: Color(0x14FFFFFF), // white 8%
    primary: _purple,
    secondary: _teal,
    userBubble: _purple,
    userBubbleEnd: Color(0xFF8B84FF),
  );

  static const light = AppColors(
    background: Color(0xFFF4F5FA),
    surface: Colors.white,
    surfaceAlt: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF15151F),
    textSecondary: Color(0xCC15151F),
    textFaint: Color(0x8815151F),
    border: Color(0x14000000), // black 8%
    primary: _purple,
    secondary: Color(0xFF00B392),
    userBubble: _purple,
    userBubbleEnd: Color(0xFF8B84FF),
  );

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? textPrimary,
    Color? textSecondary,
    Color? textFaint,
    Color? border,
    Color? primary,
    Color? secondary,
    Color? userBubble,
    Color? userBubbleEnd,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textFaint: textFaint ?? this.textFaint,
      border: border ?? this.border,
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      userBubble: userBubble ?? this.userBubble,
      userBubbleEnd: userBubbleEnd ?? this.userBubbleEnd,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textFaint: Color.lerp(textFaint, other.textFaint, t)!,
      border: Color.lerp(border, other.border, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      userBubble: Color.lerp(userBubble, other.userBubble, t)!,
      userBubbleEnd: Color.lerp(userBubbleEnd, other.userBubbleEnd, t)!,
    );
  }
}

/// Convenience accessor: `context.colors.primary`
extension AppColorsX on BuildContext {
  AppColors get colors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.dark;
}

class AppTheme {
  static ThemeData _base(AppColors c, Brightness brightness) {
    final scheme =
        brightness == Brightness.dark
            ? ColorScheme.dark(
              primary: c.primary,
              secondary: c.secondary,
              surface: c.surface,
            )
            : ColorScheme.light(
              primary: c.primary,
              secondary: c.secondary,
              surface: c.surface,
            );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: c.background,
      colorScheme: scheme,
      textTheme: GoogleFonts.dmSansTextTheme(
        brightness == Brightness.dark
            ? ThemeData.dark().textTheme
            : ThemeData.light().textTheme,
      ),
      extensions: [c],
    );
  }

  static ThemeData get dark => _base(AppColors.dark, Brightness.dark);
  static ThemeData get light => _base(AppColors.light, Brightness.light);
}
