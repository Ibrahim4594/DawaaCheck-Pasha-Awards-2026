import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/pakistan_geo.dart';
import '../../../core/constants/pakistan_geo_data.dart';
import '../../widgets/design_system/design_system.dart';

/// Counterfeit-report map of Pakistan.
///
/// A reference map, not a decorative graphic: official geoBoundaries geometry,
/// an equirectangular projection, province fills, coastline and sea, the Indus
/// river system, scale bar and north arrow. Report volume uses proportional
/// symbols — circle **area** scales with the count, the standard cartographic
/// convention — so the map can be read quantitatively.
class SafetyMapScreen extends StatefulWidget {
  const SafetyMapScreen({super.key});

  @override
  State<SafetyMapScreen> createState() => _SafetyMapScreenState();
}

class _SafetyMapScreenState extends State<SafetyMapScreen> {
  _City? _selected;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final total = _kCities.fold<int>(0, (s, c) => s + c.reports);
    final hotspots = _kCities.where((c) => c.risk == _Risk.high).length;
    final maxReports =
        _kCities.map((c) => c.reports).reduce((a, b) => a > b ? a : b);
    final ranked = [..._kCities]..sort((a, b) => b.reports.compareTo(a.reports));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _MapHeader(),

            // ── Stat strip ──
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
              child: MonoDataGrid(rows: [
                MonoDataRow(
                  label: 'REPORTS',
                  value: _formatNum(total),
                  valueColor: AppColors.primary,
                ),
                MonoDataRow(
                  label: 'HOTSPOTS',
                  value: '$hotspots',
                  valueColor: AppColors.danger,
                ),
                MonoDataRow(
                  label: 'CITIES',
                  value: '${_kCities.length}',
                  valueColor: AppColors.verified,
                ),
              ]),
            ),

            // ── The map. Kept near full width so labels stay legible. ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: _MapPanel(
                maxReports: maxReports,
                selected: _selected,
                onSelect: (city) {
                  HapticFeedback.selectionClick();
                  setState(() => _selected = city);
                },
              ).animate().fadeIn(duration: 450.ms),
            ),

            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                bottomPadding + 100,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Selected-city readout, or the tap hint ──
                  if (_selected != null)
                    _SelectedCityCard(
                      city: _selected!,
                      share: _selected!.reports / total,
                      onClose: () => setState(() => _selected = null),
                    )
                  else
                    Row(
                      children: [
                        const Icon(Icons.touch_app_outlined,
                            size: 14, color: AppColors.textHint),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'heatmapTapHint'.tr(),
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textHint,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: AppSpacing.md),
                  _MapLegend(maxReports: maxReports),
                  const SizedBox(height: AppSpacing.xl),

                  // ── Ranked hotspots ──
                  Text(
                    'heatmapTopHotspots'.tr().toUpperCase(),
                    style: AppTextStyles.sectionHeader.copyWith(
                      fontSize: 11,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  ...List.generate(ranked.length, (i) {
                    final c = ranked[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _CityRow(
                        rank: i + 1,
                        city: c,
                        maxReports: maxReports,
                        isSelected: identical(_selected, c),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() =>
                              _selected = identical(_selected, c) ? null : c);
                        },
                      ),
                    );
                  }),

                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'heatmapDisclaimer'.tr(),
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textHint,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Boundaries: geoBoundaries (gbOpen), public domain.',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textHint,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cartographic tones. Deliberately outside `AppColors` — these are map surface
/// colours (land, water, province fills) with no counterpart in the product
/// token set, and they exist only inside this screen.
class _Map {
  const _Map._();

  static const Color sea = Color(0xFFD8E6F2);
  static const Color seaLine = Color(0xFFB6CCE2);
  static const Color surroundLand = Color(0xFFECEEF2);
  static const Color land = Color(0xFFFAFBFC);
  static const Color coastline = Color(0xFF4E6182);
  static const Color provinceLine = Color(0xFFC6CFDC);
  static const Color river = Color(0xFF9BC0DF);
  static const Color furniture = Color(0xFF6E7E97);
  static const Color placeName = Color(0xFF44546F);

  /// Very light political tints — distinguishable, but quiet enough that the
  /// report symbols stay the loudest thing on the map.
  static const Map<String, Color> province = {
    'BALOCHISTAN': Color(0xFFF6F2EA),
    'PUNJAB': Color(0xFFEEF4EC),
    'SINDH': Color(0xFFF7F0F1),
    'KHYBER PAKHTUNKHWA': Color(0xFFEBF1F7),
    'GILGIT-BALTISTAN': Color(0xFFF0EFF7),
    'AZAD KASHMIR': Color(0xFFF4F1E9),
    'ICT': Color(0xFFE6ECF6),
  };
}

// ═══════════════════════════════════════════════════════════════════════════
// HEADER
// ═══════════════════════════════════════════════════════════════════════════

class _MapHeader extends StatelessWidget {
  const _MapHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: const Border(
          bottom: BorderSide(color: AppColors.borderSubtle, width: 1.5),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'SAFETY MAP · DRAP NETWORK',
                    style: AppTextStyles.sectionHeader.copyWith(
                      color: AppColors.primary,
                      letterSpacing: 1.8,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.verifiedLight,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusPill),
                      border: Border.all(
                        color: AppColors.verified.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: AppColors.verified,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'LIVE',
                          style: AppTextStyles.monoCaption.copyWith(
                            color: AppColors.verified,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('heatmapTitle'.tr(), style: AppTextStyles.h2),
              const SizedBox(height: 4),
              Text(
                'heatmapSubtitle'.tr(),
                style: AppTextStyles.body.copyWith(fontSize: 12.5, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MAP PANEL
// ═══════════════════════════════════════════════════════════════════════════

class _MapPanel extends StatelessWidget {
  final int maxReports;
  final _City? selected;
  final ValueChanged<_City?> onSelect;

  const _MapPanel({
    required this.maxReports,
    required this.selected,
    required this.onSelect,
  });

  /// Inset between the panel edge and the projected frame.
  static const double pad = 8;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        child: AspectRatio(
          aspectRatio: MapProjection.aspectRatio,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final proj = MapProjection.fit(Size(
                constraints.maxWidth - pad * 2,
                constraints.maxHeight - pad * 2,
              ));
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) => onSelect(
                  _hitTest(details.localPosition - const Offset(pad, pad), proj),
                ),
                child: CustomPaint(
                  painter: _MapPainter(
                    proj: proj,
                    pad: pad,
                    maxReports: maxReports,
                    selected: selected,
                  ),
                  child: const SizedBox.expand(),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Nearest marker within a finger-sized radius, else null (deselect).
  _City? _hitTest(Offset local, MapProjection proj) {
    _City? best;
    var bestDist = double.infinity;
    for (final c in _kCities) {
      final d = (proj.latLon(c.lat, c.lon) - local).distance;
      if (d < bestDist) {
        bestDist = d;
        best = c;
      }
    }
    return bestDist <= 26 ? best : null;
  }
}

class _MapPainter extends CustomPainter {
  final MapProjection proj;
  final double pad;
  final int maxReports;
  final _City? selected;

  _MapPainter({
    required this.proj,
    required this.pad,
    required this.maxReports,
    required this.selected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(pad, pad);
    final inner = Size(size.width - pad * 2, size.height - pad * 2);

    final country = proj.pathOf(kPakBorder);

    _paintSurround(canvas, inner);
    _paintLand(canvas, country);
    _paintProvinces(canvas, country);
    _paintRivers(canvas, country);
    _paintBorderLine(canvas, country);
    _paintPlaceNames(canvas, inner);
    _paintSymbols(canvas, inner);
    _paintMarkers(canvas, inner);
    _paintCityLabels(canvas, inner);
    _paintFurniture(canvas, inner);

    canvas.restore();
  }

  // ── Base surfaces ────────────────────────────────────────────────────────

  void _paintSurround(Canvas canvas, Size size) {
    final frame = Offset.zero & size;
    canvas.drawRect(frame, Paint()..color = _Map.surroundLand);

    // Arabian Sea: the real coastline, closed off the bottom of the frame.
    final sea = Path();
    final first = proj.project(kPakCoast.first);
    sea.moveTo(first.dx, first.dy);
    for (final pt in kPakCoast.skip(1)) {
      final p = proj.project(pt);
      sea.lineTo(p.dx, p.dy);
    }
    final last = proj.project(kPakCoast.last);
    sea.lineTo(-size.width, last.dy);
    sea.lineTo(-size.width, size.height * 2);
    sea.lineTo(size.width * 2, size.height * 2);
    sea.lineTo(size.width * 2, first.dy);
    sea.close();

    canvas.save();
    canvas.clipRect(frame);
    canvas.drawPath(sea, Paint()..color = _Map.sea);

    // Depth contours echoing the coast — reads as sea, not a flat fill.
    final contour = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = _Map.seaLine.withValues(alpha: 0.65);
    for (final dy in const [8.0, 17.0]) {
      final line = Path();
      for (var i = 0; i < kPakCoast.length; i++) {
        final p = proj.project(kPakCoast[i]) + Offset(0, dy);
        i == 0 ? line.moveTo(p.dx, p.dy) : line.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(line, contour);
    }
    canvas.restore();
  }

  void _paintLand(Canvas canvas, Path country) {
    // Soft lift so the country reads as a sheet above the surround.
    canvas.drawPath(
      country.shift(const Offset(0, 2)),
      Paint()
        ..color = const Color(0x222B3A55)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 5),
    );
    canvas.drawPath(country, Paint()..color = _Map.land);
  }

  /// Province fills + hairline internal boundaries, clipped to the country so
  /// simplification seams never bleed past the national border.
  void _paintProvinces(Canvas canvas, Path country) {
    canvas.save();
    canvas.clipPath(country);
    for (final p in kPakProvinces) {
      final path = proj.pathOf(p.ring);
      canvas.drawPath(
        path,
        Paint()..color = _Map.province[p.name] ?? _Map.land,
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..color = _Map.provinceLine,
      );
    }
    canvas.restore();
  }

  void _paintRivers(Canvas canvas, Path country) {
    canvas.save();
    canvas.clipPath(country);
    for (var i = 0; i < kPakRivers.length; i++) {
      final pts = kPakRivers[i].map(proj.project).toList();
      // The Indus (index 0) is the trunk — heavier than its tributaries.
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = i == 0 ? 1.6 : 1.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = _Map.river.withValues(alpha: i == 0 ? 0.95 : 0.6);

      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final p in pts.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }
    canvas.restore();
  }

  void _paintBorderLine(Canvas canvas, Path country) {
    canvas.drawPath(
      country,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round
        ..color = _Map.coastline,
    );
  }

  // ── Place names: provinces and neighbouring countries ────────────────────

  void _paintPlaceNames(Canvas canvas, Size size) {
    final provinceStyle = AppTextStyles.monoCaption.copyWith(
      color: _Map.placeName.withValues(alpha: 0.78),
      fontSize: 9.5,
      letterSpacing: 1.3,
    );
    for (final p in kPakProvinces) {
      // ICT is a few kilometres across — the Islamabad marker speaks for it.
      if (p.name == 'ICT') continue;
      final at = proj.project(p.labelAt);
      // Long names get wrapped so they don't overrun narrow provinces.
      final text = p.name == 'KHYBER PAKHTUNKHWA' ? 'KHYBER\nPAKHTUNKHWA' : p.name;
      final tp = _painter(text, provinceStyle, align: TextAlign.center);
      _label(
        canvas,
        text,
        at - Offset(tp.width / 2, tp.height / 2),
        provinceStyle,
        align: TextAlign.center,
        haloWidth: 3.2,
      );
    }

    final neighbourStyle = AppTextStyles.monoCaption.copyWith(
      color: _Map.furniture.withValues(alpha: 0.7),
      fontSize: 8.5,
      letterSpacing: 1.5,
    );
    for (final (name, at) in kNeighbours) {
      final p = proj.project(at);
      final tp = _painter(name, neighbourStyle);
      _label(canvas, name, p - Offset(tp.width / 2, tp.height / 2),
          neighbourStyle,
          halo: _Map.surroundLand.withValues(alpha: 0.9));
    }
  }

  // ── Proportional symbols ─────────────────────────────────────────────────

  /// Circle **area** is proportional to the report count, so the radius scales
  /// with the square root. Scaling radius directly would exaggerate big cities.
  double _radiusFor(int reports, Size size) {
    final maxR = size.width * 0.082;
    final minR = size.width * 0.015;
    return minR + (maxR - minR) * math.sqrt(reports / maxReports);
  }

  void _paintSymbols(Canvas canvas, Size size) {
    // Largest first so smaller symbols stay visible on top.
    final ordered = [..._kCities]
      ..sort((a, b) => b.reports.compareTo(a.reports));

    for (final c in ordered) {
      final center = proj.latLon(c.lat, c.lon);
      final r = _radiusFor(c.reports, size);
      final color = c.risk.color;

      canvas.drawCircle(
          center, r, Paint()..color = color.withValues(alpha: 0.18));
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = color.withValues(alpha: 0.8),
      );
    }
  }

  void _paintMarkers(Canvas canvas, Size size) {
    for (final c in _kCities) {
      final center = proj.latLon(c.lat, c.lon);

      if (identical(selected, c)) {
        canvas.drawCircle(
          center,
          _radiusFor(c.reports, size) + 5,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8
            ..color = AppColors.primary,
        );
      }

      // White collar keeps the dot legible over any fill.
      canvas.drawCircle(center, 4.4, Paint()..color = Colors.white);
      canvas.drawCircle(center, 3.0, Paint()..color = c.risk.color);
    }
  }

  /// Label placement with collision avoidance: cities are labelled in order of
  /// importance, each trying four positions around its marker. A label that
  /// cannot be placed cleanly is dropped rather than allowed to overlap — the
  /// full list is available below the map, so nothing is lost.
  void _paintCityLabels(Canvas canvas, Size size) {
    final nameStyle = AppTextStyles.bodySemibold.copyWith(
      color: AppColors.textPrimary,
      fontSize: 11.5,
      height: 1.1,
    );

    final occupied = <Rect>[
      // Reserve every marker so labels never sit on a symbol.
      for (final c in _kCities)
        Rect.fromCircle(center: proj.latLon(c.lat, c.lon), radius: 7),
    ];

    final ordered = [..._kCities]
      ..sort((a, b) => b.reports.compareTo(a.reports));

    for (final c in ordered) {
      final isSelected = identical(selected, c);
      final center = proj.latLon(c.lat, c.lon);
      final valueStyle = AppTextStyles.monoCaption.copyWith(
        color: c.risk.color,
        fontSize: 9.5,
        letterSpacing: 0.3,
      );

      final name = c.name;
      final value = _formatNum(c.reports);
      final namePainter = _painter(name, nameStyle);
      final valuePainter = _painter(value, valueStyle);
      final w = math.max(namePainter.width, valuePainter.width);
      final h = namePainter.height + valuePainter.height;
      final gap = _radiusFor(c.reports, size) * 0.5 + 8;

      // Right, left, below, above — the classic point-feature preference order.
      final candidates = <Offset>[
        Offset(center.dx + gap, center.dy - h / 2),
        Offset(center.dx - gap - w, center.dy - h / 2),
        Offset(center.dx - w / 2, center.dy + gap),
        Offset(center.dx - w / 2, center.dy - gap - h),
      ];

      Rect? chosen;
      for (final at in candidates) {
        final rect = Rect.fromLTWH(at.dx, at.dy, w, h);
        if (rect.left < 2 ||
            rect.top < 2 ||
            rect.right > size.width - 2 ||
            rect.bottom > size.height - 2) {
          continue;
        }
        if (occupied.any((o) => o.overlaps(rect.inflate(1.5)))) continue;
        chosen = rect;
        break;
      }

      // The selected city is always labelled, even if it has to overlap.
      chosen ??= isSelected
          ? Rect.fromLTWH(
              (center.dx + gap).clamp(2.0, size.width - w - 2),
              (center.dy - h / 2).clamp(2.0, size.height - h - 2),
              w,
              h,
            )
          : null;
      if (chosen == null) continue;

      occupied.add(chosen);
      _label(canvas, name, chosen.topLeft, nameStyle);
      _label(canvas, value,
          chosen.topLeft + Offset(0, namePainter.height), valueStyle);
    }
  }

  // ── Map furniture ────────────────────────────────────────────────────────

  void _paintFurniture(Canvas canvas, Size size) {
    // Neat line — the printed frame of a reference map.
    canvas.drawRect(
      Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = _Map.furniture.withValues(alpha: 0.3),
    );

    _paintNorthArrow(canvas, Offset(size.width - 22, 14));
    _paintScaleBar(canvas, size);
  }

  void _paintNorthArrow(Canvas canvas, Offset at) {
    final path = Path()
      ..moveTo(at.dx, at.dy)
      ..lineTo(at.dx - 4.5, at.dy + 12)
      ..lineTo(at.dx, at.dy + 8.5)
      ..lineTo(at.dx + 4.5, at.dy + 12)
      ..close();
    canvas.drawPath(
        path, Paint()..color = _Map.furniture.withValues(alpha: 0.85));

    final style = AppTextStyles.monoCaption.copyWith(
      color: _Map.furniture.withValues(alpha: 0.85),
      fontSize: 8.5,
    );
    final tp = _painter('N', style);
    _label(canvas, 'N', Offset(at.dx - tp.width / 2, at.dy + 13), style);
  }

  void _paintScaleBar(Canvas canvas, Size size) {
    // Largest round distance that fits in ~30% of the frame width.
    const candidates = [100.0, 200.0, 250.0, 500.0];
    final budget = size.width * 0.30;
    var km = candidates.first;
    for (final c in candidates) {
      if (c / proj.kmPerPixel <= budget) km = c;
    }
    final barW = km / proj.kmPerPixel;
    const left = 10.0;
    final top = size.height - 20;
    final half = barW / 2;

    // Alternating checker — the classic printed scale bar.
    canvas.drawRect(Rect.fromLTWH(left, top, half, 4),
        Paint()..color = _Map.furniture.withValues(alpha: 0.85));
    canvas.drawRect(Rect.fromLTWH(left + half, top, half, 4),
        Paint()..color = Colors.white.withValues(alpha: 0.92));
    canvas.drawRect(
      Rect.fromLTWH(left, top, barW, 4),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = _Map.furniture.withValues(alpha: 0.85),
    );

    final style = AppTextStyles.monoCaption.copyWith(
      color: _Map.furniture.withValues(alpha: 0.9),
      fontSize: 8,
      letterSpacing: 0.5,
    );
    _label(canvas, '0', const Offset(left - 1, 0) + Offset(0, top - 11), style);
    final endLabel = '${km.toInt()} km';
    final tp = _painter(endLabel, style);
    _label(canvas, endLabel,
        Offset(left + barW - tp.width + 1, top - 11), style);
  }

  // ── Text helpers ─────────────────────────────────────────────────────────

  TextPainter _painter(String text, TextStyle style,
          {TextAlign align = TextAlign.left}) =>
      TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: ui.TextDirection.ltr,
        textAlign: align,
      )..layout();

  /// Draws [text] with a halo — the cartographic technique that keeps type
  /// legible where it crosses lines and fills.
  void _label(
    Canvas canvas,
    String text,
    Offset at,
    TextStyle style, {
    Color halo = Colors.white,
    double haloWidth = 2.8,
    TextAlign align = TextAlign.left,
  }) {
    final haloStyle = TextStyle(
      fontFamily: style.fontFamily,
      fontFamilyFallback: style.fontFamilyFallback,
      fontSize: style.fontSize,
      fontWeight: style.fontWeight,
      letterSpacing: style.letterSpacing,
      height: style.height,
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = haloWidth
        ..strokeJoin = StrokeJoin.round
        ..color = halo,
    );
    _painter(text, haloStyle, align: align).paint(canvas, at);
    _painter(text, style, align: align).paint(canvas, at);
  }

  @override
  bool shouldRepaint(covariant _MapPainter old) =>
      old.maxReports != maxReports ||
      !identical(old.selected, selected) ||
      old.proj.scale != proj.scale;
}

// ═══════════════════════════════════════════════════════════════════════════
// SELECTED CITY READOUT
// ═══════════════════════════════════════════════════════════════════════════

class _SelectedCityCard extends StatelessWidget {
  final _City city;
  final double share;
  final VoidCallback onClose;

  const _SelectedCityCard({
    required this.city,
    required this.share,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return ClinicalCard(
      accentStripColor: city.risk.color,
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.sm, AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  city.name,
                  style: AppTextStyles.bodySemibold.copyWith(fontSize: 15),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onClose,
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close_rounded,
                        size: 16, color: AppColors.textHint),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          MonoDataGrid(rows: [
            MonoDataRow(
              label: 'REPORTS',
              value: _formatNum(city.reports),
              valueColor: city.risk.color,
            ),
            MonoDataRow(
              label: 'SHARE',
              value: '${(share * 100).toStringAsFixed(1)}%',
            ),
            MonoDataRow(label: 'RISK', value: city.risk.code),
          ]),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${city.region}  ·  ${city.lat.toStringAsFixed(2)}°N '
            '${city.lon.toStringAsFixed(2)}°E',
            style: AppTextStyles.monoCaption.copyWith(
              color: AppColors.textHint,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MAP KEY
// ═══════════════════════════════════════════════════════════════════════════

class _MapLegend extends StatelessWidget {
  final int maxReports;
  const _MapLegend({required this.maxReports});

  @override
  Widget build(BuildContext context) {
    return ClinicalCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MAP KEY',
            style: AppTextStyles.sectionHeader.copyWith(letterSpacing: 1.8),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.sm,
            children: [
              _LegendDot(
                  color: AppColors.danger, label: 'heatmapLegendHigh'.tr()),
              _LegendDot(
                  color: AppColors.warning, label: 'heatmapLegendMedium'.tr()),
              _LegendDot(
                  color: AppColors.verified, label: 'heatmapLegendLow'.tr()),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const HairlineDivider(),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              CustomPaint(
                size: const Size(100, 46),
                painter: _SymbolKeyPainter(maxReports: maxReports),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'heatmapSymbolKey'.tr(),
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Nested proportional circles — the standard key for a graduated-symbol map.
class _SymbolKeyPainter extends CustomPainter {
  final int maxReports;
  _SymbolKeyPainter({required this.maxReports});

  @override
  void paint(Canvas canvas, Size size) {
    final samples = [
      maxReports,
      (maxReports * 0.4).round(),
      (maxReports * 0.12).round(),
    ];
    final maxR = size.height * 0.4;

    for (final value in samples) {
      final r = maxR * math.sqrt(value / maxReports);
      final center = Offset(maxR + 2, size.height - r - 8);
      canvas.drawCircle(center, r,
          Paint()..color = AppColors.primary.withValues(alpha: 0.10));
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = AppColors.primary.withValues(alpha: 0.55),
      );

      final top = Offset(center.dx, center.dy - r);
      canvas.drawLine(
        top,
        Offset(maxR * 2 + 8, top.dy),
        Paint()
          ..strokeWidth = 0.7
          ..color = AppColors.textHint.withValues(alpha: 0.6),
      );
      TextPainter(
        text: TextSpan(
          text: _formatNum(value),
          style: AppTextStyles.monoCaption.copyWith(
            color: AppColors.textSecondary,
            fontSize: 8.5,
            letterSpacing: 0.4,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )
        ..layout()
        ..paint(canvas, Offset(maxR * 2 + 11, top.dy - 5));
    }
  }

  @override
  bool shouldRepaint(covariant _SymbolKeyPainter old) =>
      old.maxReports != maxReports;
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// RANKED CITY ROW
// ═══════════════════════════════════════════════════════════════════════════

class _CityRow extends StatelessWidget {
  final int rank;
  final _City city;
  final int maxReports;
  final bool isSelected;
  final VoidCallback onTap;

  const _CityRow({
    required this.rank,
    required this.city,
    required this.maxReports,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = city.risk.color;
    final frac = (city.reports / maxReports).clamp(0.0, 1.0);

    return ClinicalCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      accentStripColor: isSelected ? AppColors.primary : color,
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text(
              '$rank',
              style: AppTextStyles.monoData.copyWith(color: AppColors.textHint),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        city.name,
                        style:
                            AppTextStyles.bodySemibold.copyWith(fontSize: 14),
                      ),
                    ),
                    Text(
                      _formatNum(city.reports),
                      style: AppTextStyles.monoData.copyWith(color: color),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'heatmapReportsSuffix'.tr(),
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textHint,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusPill),
                        child: LinearProgressIndicator(
                          value: frac,
                          minHeight: 5,
                          backgroundColor:
                              Theme.of(context).colorScheme.outlineVariant,
                          valueColor: AlwaysStoppedAnimation(color),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      city.region,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textHint,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DATA
// ═══════════════════════════════════════════════════════════════════════════

enum _Risk {
  high(AppColors.danger, 'HIGH'),
  medium(AppColors.warning, 'MED'),
  low(AppColors.verified, 'LOW');

  const _Risk(this.color, this.code);
  final Color color;
  final String code;
}

class _City {
  final String name;
  final String region;

  /// Real WGS84 coordinates — the marker sits where the city actually is.
  final double lat;
  final double lon;

  final int reports;
  final _Risk risk;

  const _City(
    this.name,
    this.region,
    this.lat,
    this.lon,
    this.reports,
    this.risk,
  );
}

const List<_City> _kCities = [
  _City('Karachi', 'Sindh', 24.86, 67.01, 342, _Risk.high),
  _City('Lahore', 'Punjab', 31.55, 74.34, 287, _Risk.high),
  _City('Faisalabad', 'Punjab', 31.42, 73.08, 156, _Risk.medium),
  _City('Rawalpindi', 'Punjab', 33.60, 73.04, 112, _Risk.medium),
  _City('Multan', 'Punjab', 30.20, 71.47, 98, _Risk.medium),
  _City('Islamabad', 'ICT', 33.68, 73.05, 76, _Risk.medium),
  _City('Gujranwala', 'Punjab', 32.16, 74.19, 71, _Risk.medium),
  _City('Peshawar', 'KPK', 34.01, 71.58, 64, _Risk.medium),
  _City('Hyderabad', 'Sindh', 25.40, 68.37, 52, _Risk.low),
  _City('Sialkot', 'Punjab', 32.49, 74.53, 44, _Risk.low),
  _City('Bahawalpur', 'Punjab', 29.40, 71.68, 38, _Risk.low),
  _City('Larkana', 'Sindh', 27.56, 68.21, 33, _Risk.low),
  _City('Quetta', 'Balochistan', 30.18, 66.98, 31, _Risk.low),
  _City('Mardan', 'KPK', 34.20, 72.05, 28, _Risk.low),
  _City('Sukkur', 'Sindh', 27.70, 68.86, 27, _Risk.low),
  _City('Gwadar', 'Balochistan', 25.13, 62.33, 14, _Risk.low),
];

/// Thousands-separator formatter for the mono report counts.
String _formatNum(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}
