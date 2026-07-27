/// Projection and map context for the Safety Map.
///
/// The geometry itself (national border, coastline, provinces) is official
/// geoBoundaries data — see the generated `pakistan_geo_data.dart`. Everything
/// is `Offset(longitude, latitude)` in decimal degrees (WGS84), the same
/// convention GeoJSON uses, so every point on the map is a real place.
library;

import 'dart:math' as math;
import 'dart:ui';

/// Equirectangular (plate carrée) projection with a standard-parallel
/// correction — what most single-country reference maps use.
///
/// Longitude degrees are compressed by `cos(midLatitude)` so the country keeps
/// its true proportions instead of looking stretched east-to-west.
class MapProjection {
  /// Map frame in degrees. Pakistan spans roughly 60.9–77.8°E and 23.7–37.1°N;
  /// the frame adds ~1° of margin so the country never touches the neat line
  /// and there is room for the sea and neighbouring-country labels.
  static const double lonMin = 59.9;
  static const double lonMax = 78.8;
  static const double latMin = 22.5;
  static const double latMax = 37.9;

  /// cos(30.2°) — the mid-latitude of the frame.
  static const double _parallel = 0.8639;

  static const double _projWidth = (lonMax - lonMin) * _parallel;
  static const double _projHeight = latMax - latMin;

  /// Aspect ratio (width / height) of the projected frame. The map panel uses
  /// this so the country fills the box with no wasted space.
  static const double aspectRatio = _projWidth / _projHeight;

  /// Pixels per projected degree.
  final double scale;

  /// Canvas offset of the frame's top-left corner.
  final Offset origin;

  const MapProjection._(this.scale, this.origin);

  /// Fits the whole frame inside [size], centred, preserving aspect ratio.
  factory MapProjection.fit(Size size) {
    final s = math.min(size.width / _projWidth, size.height / _projHeight);
    return MapProjection._(
      s,
      Offset(
        (size.width - _projWidth * s) / 2,
        (size.height - _projHeight * s) / 2,
      ),
    );
  }

  /// Projects a `(longitude, latitude)` pair to a canvas point.
  Offset project(Offset lonLat) => Offset(
        origin.dx + (lonLat.dx - lonMin) * _parallel * scale,
        origin.dy + (latMax - lonLat.dy) * scale,
      );

  Offset latLon(double lat, double lon) => project(Offset(lon, lat));

  /// Ground distance covered by one logical pixel (1° latitude ≈ 111.32 km).
  double get kmPerPixel => 111.32 / scale;

  /// Builds a [Path] through a ring of `(lon, lat)` points.
  Path pathOf(List<Offset> ring, {bool close = true}) {
    final path = Path();
    for (var i = 0; i < ring.length; i++) {
      final p = project(ring[i]);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    if (close) path.close();
    return path;
  }
}

/// Surrounding territories, for map context. Placed outside the border.
const List<(String, Offset)> kNeighbours = [
  ('AFGHANISTAN', Offset(63.60, 33.90)),
  ('CHINA', Offset(76.90, 36.90)),
  ('INDIA', Offset(76.30, 27.20)),
  ('IRAN', Offset(60.90, 28.40)),
  ('ARABIAN SEA', Offset(65.60, 23.75)),
];

/// Major rivers — the Indus system. Generalised course, real coordinates.
const List<List<Offset>> kPakRivers = [
  // Indus: Karakoram to the delta
  [
    Offset(75.60, 35.30), Offset(74.60, 35.20), Offset(73.60, 35.05),
    Offset(72.90, 34.90), Offset(72.50, 34.40), Offset(72.25, 33.90),
    Offset(71.80, 33.40), Offset(71.55, 32.96), Offset(71.30, 32.40),
    Offset(70.90, 31.83), Offset(70.70, 31.20), Offset(70.60, 30.50),
    Offset(70.50, 29.80), Offset(70.40, 28.90), Offset(69.70, 28.30),
    Offset(69.10, 27.90), Offset(68.85, 27.70), Offset(68.60, 27.00),
    Offset(68.50, 26.40), Offset(68.40, 25.40), Offset(68.20, 24.80),
    Offset(67.80, 24.30), Offset(67.50, 24.10),
  ],
  // Chenab / Jhelum
  [
    Offset(74.30, 32.80), Offset(73.50, 32.30), Offset(72.80, 31.80),
    Offset(72.20, 31.20), Offset(71.70, 30.70), Offset(71.20, 30.20),
    Offset(70.90, 29.70), Offset(70.55, 29.35),
  ],
  // Sutlej
  [
    Offset(74.60, 31.10), Offset(73.80, 30.60), Offset(73.00, 30.10),
    Offset(72.20, 29.60), Offset(71.60, 29.30), Offset(71.00, 29.10),
    Offset(70.60, 29.30),
  ],
];
