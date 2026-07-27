import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// DawaaCheck typography — IBM Plex family.
///
/// **Plex Sans** for Latin content (weights 300 italic, 400, 500, 600 — never above 600).
/// **Plex Mono** for all data-bearing surfaces (scan IDs, timestamps, prices, counts).
/// **Plex Sans Arabic** wires up as fallback via `app_theme.dart` for Urdu.
///
/// Public API matches the prior Plus Jakarta Sans file so every call site
/// (`AppTextStyles.display`, `.h1`, `.sectionHeader` …) keeps compiling. Only
/// the rendered font changes. See `.claude/skills/dawaacheck-ui/references/typography.md`.
class AppTextStyles {
  AppTextStyles._();

  // ── Urdu fallback (sans + serif only, NOT mono) ──
  //
  // Urdu renders in **Noto Naskh Arabic**. Nastaliq is the traditional
  // calligraphic script, but its steep diagonal baseline needs roughly double
  // the line height and turns into an unreadable tangle at UI sizes (12–14px),
  // which is where almost all of this app's text lives. Naskh keeps the same
  // horizontal baseline as the Latin face, so Urdu screens stay as clean and
  // as tightly spaced as English ones.
  //
  // `AppTheme._withUrduFallback` wires the same family into the global
  // `textTheme`, but styles built by the private `_sans/_serif` helpers below
  // bypass that theme entirely (they go straight to `GoogleFonts`), so they
  // need the fallback set explicitly here too.
  //
  // **Mono deliberately has NO Urdu fallback.** Mono is a Latin-only role per
  // CLAUDE.md (scan codes, timestamps, prices, counts — firmware-plate data).
  // Flutter sizes line metrics to the tallest fallback font even when the text
  // is pure Latin, so keeping mono fallback-free keeps its metrics tight and
  // predictable.
  static final List<String> _urduFallback = () {
    final f = GoogleFonts.notoNaskhArabic().fontFamily;
    return f == null ? const <String>[] : <String>[f];
  }();

  // ── Private constructors ──

  static TextStyle _sans({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    FontStyle style = FontStyle.normal,
    Color color = AppColors.textPrimary,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      fontStyle: style,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    ).copyWith(fontFamilyFallback: _urduFallback);
  }

  static TextStyle _mono({
    double size = 13,
    FontWeight weight = FontWeight.w500,
    Color color = AppColors.textPrimary,
    double? height,
    double? letterSpacing,
  }) {
    // No Urdu fallback — see block comment above.
    return GoogleFonts.ibmPlexMono(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  /// Plex Serif — reserved for VerdictHeadline only. Adds medical-journal
  /// gravitas to absolute verdicts ("Authentic." / "Counterfeit." /
  /// "Unconfirmed.") without breaking the Plex family identity. The rest of
  /// the app stays on Plex Sans.
  static TextStyle _serif({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    FontStyle style = FontStyle.normal,
    Color color = AppColors.textPrimary,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.ibmPlexSerif(
      fontSize: size,
      fontWeight: weight,
      fontStyle: style,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    ).copyWith(fontFamilyFallback: _urduFallback);
  }

  // ── Display & Headings ──
  // Weight ceiling is 600. Plex is engineered for clarity at 400-600; 700+ reads AI-inflated.

  static TextStyle get display => _sans(
    size: 34,
    weight: FontWeight.w600,
    letterSpacing: -0.8,
    height: 1.1,
  );

  static TextStyle get h1 => _sans(
    size: 28,
    weight: FontWeight.w600,
    letterSpacing: -0.6,
    height: 1.15,
  );

  static TextStyle get h2 => _sans(
    size: 22,
    weight: FontWeight.w600,
    letterSpacing: -0.4,
    height: 1.2,
  );

  static TextStyle get h3 => _sans(
    size: 18,
    weight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.25,
  );

  static TextStyle get h4 => _sans(
    size: 15,
    weight: FontWeight.w600,
    letterSpacing: -0.1,
    height: 1.3,
  );

  // ── Verdict headline (two-line signature on result screens) ──
  // Pattern: verdictHeadline renders the absolute statement ("Authentic."),
  // verdictHeadlineSoft renders the italic-light emotional payoff beneath it.
  //
  // These two styles use **IBM Plex Serif** (not Sans) — the only place in
  // the app where serif appears. Plex Serif gives the verdict medical-journal
  // gravitas — "Authentic." reads as a doctor's signed verdict, not a product
  // claim. Same Plex family → no brand break. Reverting to _sans(...) is a
  // 30-second change if the serif reads too formal on a specific screen.

  static TextStyle get verdictHeadline => _serif(
    size: 26,
    weight: FontWeight.w600,
    letterSpacing: -0.5,
    height: 1.05,
  );

  static TextStyle get verdictHeadlineSoft => _serif(
    size: 26,
    weight: FontWeight.w300,
    style: FontStyle.italic,
    letterSpacing: -0.5,
    height: 1.05,
  );

  // ── Body ──

  static TextStyle get body => _sans(
    color: AppColors.textSecondary,
    height: 1.55,
    letterSpacing: 0,
  );

  static TextStyle get bodyMedium => _sans(
    weight: FontWeight.w500,
    height: 1.5,
    letterSpacing: 0,
  );

  /// Emphasized inline text (medicine names, agent names, key terms).
  static TextStyle get bodyStrong => _sans(
    weight: FontWeight.w600,
    height: 1.5,
    letterSpacing: 0,
  );

  /// Legacy name — kept for compatibility with existing call sites.
  /// Prefer `bodyStrong` in new code.
  static TextStyle get bodySemibold => bodyStrong;

  // ── Labels & Captions ──

  static TextStyle get label => _sans(
    size: 12,
    weight: FontWeight.w500,
    color: AppColors.textHint,
    letterSpacing: 0.2,
    height: 1.4,
  );

  /// Uppercase mono mini-label — "RECENT SCANS", "VERDICT", "VERIFIED · CLASS B".
  /// Plex Mono + wide tracking reads as a field tag in medical forms.
  static TextStyle get sectionHeader => _mono(
    size: 10,
    weight: FontWeight.w600,
    color: AppColors.primary,
    letterSpacing: 1.8,
    height: 1.3,
  );

  static TextStyle get caption => _sans(
    size: 11,
    color: AppColors.textHint,
    letterSpacing: 0.3,
    height: 1.4,
  );

  static TextStyle get badge => _sans(
    size: 11,
    weight: FontWeight.w600,
    letterSpacing: 0.5,
  );

  // ── Numbers & Stats (all mono for tabular figures) ──

  static TextStyle get displayNumber => _mono(
    size: 44,
    weight: FontWeight.w700,
    letterSpacing: -1.0,
    height: 1.0,
  );

  static TextStyle get statNumber => _mono(
    size: 28,
    weight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.1,
  );

  static TextStyle get statLabel => _mono(
    size: 10,
    weight: FontWeight.w600,
    color: AppColors.textHint,
    letterSpacing: 1.2,
    height: 1.3,
  );

  // ── Mono data roles (scan IDs, timestamps, lot codes, prices) ──

  /// Default mono run. Use for agent bylines, inline timestamps, scan codes.
  static TextStyle get mono => _mono(
    size: 13,
    weight: FontWeight.w500,
  );

  /// Smaller mono for card corners and secondary timestamps.
  static TextStyle get monoSmall => _mono(
    size: 11,
    weight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  /// Uppercase mono labels — "AUTH 94", "RISK LOW", "LOT-4QX".
  ///
  /// Explicit `height: 1.1` keeps intrinsic line height deterministic at
  /// `10 * 1.1 = 11px`. Without it, Plex Mono's metric-derived default
  /// (~1.3-1.4) pushes `MonoDataRow`'s Column past its IntrinsicHeight cap
  /// when cells are tight (e.g. the 3-column welcome/onboarding stat grid),
  /// overflowing by ~5px.
  static TextStyle get monoCaption => _mono(
    size: 10,
    weight: FontWeight.w600,
    color: AppColors.textHint,
    letterSpacing: 0.8,
    height: 1.1,
  );

  /// Data-grid cell values — prominent mono numbers inside a MonoDataRow.
  static TextStyle get monoData => _mono(
    size: 18,
    weight: FontWeight.w700,
    letterSpacing: -0.2,
    height: 1.1,
  );

  // ── Buttons ──

  static TextStyle get buttonPrimary => _sans(
    size: 15,
    weight: FontWeight.w600,
    color: AppColors.white,
    letterSpacing: 0.2,
  );

  // ── Onboarding (kept for compat — still Plex Sans, still white) ──

  static TextStyle get onboardingHeadline => _sans(
    size: 26,
    weight: FontWeight.w600,
    color: AppColors.white,
    height: 1.15,
    letterSpacing: -0.5,
  );
}
