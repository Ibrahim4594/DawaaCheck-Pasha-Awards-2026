// Converts official geoBoundaries GeoJSON (public domain) into a compact
// const Dart source file for offline rendering.
const fs = require('fs');

const SP = __dirname;

// ── Douglas–Peucker line simplification ────────────────────────────────────
function perpDist(p, a, b) {
  const [x, y] = p, [x1, y1] = a, [x2, y2] = b;
  const dx = x2 - x1, dy = y2 - y1;
  if (dx === 0 && dy === 0) return Math.hypot(x - x1, y - y1);
  const t = ((x - x1) * dx + (y - y1) * dy) / (dx * dx + dy * dy);
  const cx = x1 + Math.max(0, Math.min(1, t)) * dx;
  const cy = y1 + Math.max(0, Math.min(1, t)) * dy;
  return Math.hypot(x - cx, y - cy);
}

function simplify(pts, tol) {
  if (pts.length < 3) return pts;
  let maxD = 0, idx = 0;
  for (let i = 1; i < pts.length - 1; i++) {
    const d = perpDist(pts[i], pts[0], pts[pts.length - 1]);
    if (d > maxD) { maxD = d; idx = i; }
  }
  if (maxD > tol) {
    const left = simplify(pts.slice(0, idx + 1), tol);
    const right = simplify(pts.slice(idx), tol);
    return left.slice(0, -1).concat(right);
  }
  return [pts[0], pts[pts.length - 1]];
}

/** Simplifies to roughly `target` points by binary-searching the tolerance. */
function simplifyTo(pts, target) {
  let lo = 0.0001, hi = 1.0, best = pts;
  for (let i = 0; i < 40; i++) {
    const mid = (lo + hi) / 2;
    const out = simplify(pts, mid);
    if (out.length > target) { lo = mid; } else { hi = mid; best = out; }
  }
  return best;
}

/** Largest ring from a Polygon / MultiPolygon geometry. */
function biggestRing(geom) {
  const polys = geom.type === 'MultiPolygon'
    ? geom.coordinates
    : [geom.coordinates];
  let best = null;
  for (const poly of polys) {
    const ring = poly[0];
    if (!best || ring.length > best.length) best = ring;
  }
  return best;
}

function area(ring) {
  let a = 0;
  for (let i = 0; i < ring.length - 1; i++) {
    a += ring[i][0] * ring[i + 1][1] - ring[i + 1][0] * ring[i][1];
  }
  return a / 2;
}

function centroid(ring) {
  let cx = 0, cy = 0, a = 0;
  for (let i = 0; i < ring.length - 1; i++) {
    const f = ring[i][0] * ring[i + 1][1] - ring[i + 1][0] * ring[i][1];
    cx += (ring[i][0] + ring[i + 1][0]) * f;
    cy += (ring[i][1] + ring[i + 1][1]) * f;
    a += f;
  }
  a /= 2;
  return [cx / (6 * a), cy / (6 * a)];
}

// ── Load ───────────────────────────────────────────────────────────────────
const adm0 = JSON.parse(fs.readFileSync(`${SP}/pak_adm0.geojson`, 'utf8'));
const adm1 = JSON.parse(fs.readFileSync(`${SP}/pak_adm1.geojson`, 'utf8'));

let border = biggestRing(adm0.features[0].geometry);
border = simplifyTo(border, 300);
console.log('border pts:', border.length);

// ── Coastline: the low-latitude run between the southern tip and the Iran
//    corner. Picked by walking both ways round the ring and keeping the path
//    that never climbs inland. ──
function extractCoast(ring) {
  let iSouth = 0;
  for (let i = 0; i < ring.length; i++) {
    if (ring[i][1] < ring[iSouth][1]) iSouth = i;
  }
  let iWest = -1;
  for (let i = 0; i < ring.length; i++) {
    if (ring[i][1] < 26.0 && (iWest < 0 || ring[i][0] < ring[iWest][0])) iWest = i;
  }
  const walk = (from, to, step) => {
    const out = [];
    let i = from;
    for (let n = 0; n < ring.length; n++) {
      out.push(ring[i]);
      if (i === to) break;
      i = (i + step + ring.length) % ring.length;
    }
    return out;
  };
  const fwd = walk(iSouth, iWest, 1);
  const bwd = walk(iSouth, iWest, -1);
  const maxLat = (p) => Math.max(...p.map((q) => q[1]));
  return maxLat(fwd) <= maxLat(bwd) ? fwd : bwd;
}
const coast = extractCoast(border);
console.log('coast pts:', coast.length,
  'lat range', Math.min(...coast.map(p => p[1])).toFixed(2),
  '-', Math.max(...coast.map(p => p[1])).toFixed(2));

// ── Provinces ──────────────────────────────────────────────────────────────
const SHORT = {
  'Balochistan': 'BALOCHISTAN',
  'Sindh': 'SINDH',
  'Punjab': 'PUNJAB',
  'Khyber Pakhtunkhwa': 'KHYBER PAKHTUNKHWA',
  'Gilgit-Baltistan': 'GILGIT-BALTISTAN',
  'Azad Kashmir': 'AZAD KASHMIR',
  'Islamabad Capital Territory': 'ICT',
};

const provinces = adm1.features.map((f) => {
  const raw = biggestRing(f.geometry);
  const ring = simplifyTo(raw, f.properties.shapeName === 'Islamabad Capital Territory' ? 40 : 140);
  const c = centroid(raw);
  return {
    name: f.properties.shapeName,
    short: SHORT[f.properties.shapeName] || f.properties.shapeName.toUpperCase(),
    ring,
    label: c,
    size: Math.abs(area(raw)),
  };
}).sort((a, b) => b.size - a.size);

provinces.forEach((p) =>
  console.log(' -', p.short, 'pts', p.ring.length,
    'label', p.label.map(v => v.toFixed(2)).join(',')));

// ── Emit Dart ──────────────────────────────────────────────────────────────
const fmt = (p) => `Offset(${p[0].toFixed(3)}, ${p[1].toFixed(3)})`;
const emitRing = (ring, indent) => {
  const lines = [];
  for (let i = 0; i < ring.length; i += 3) {
    lines.push(indent + ring.slice(i, i + 3).map(fmt).join(', ') + ',');
  }
  return lines.join('\n');
};

let out = `// GENERATED FILE — do not edit by hand.
//
// Source: geoBoundaries gbOpen release (https://www.geoboundaries.org),
// Pakistan ADM0 + ADM1, Public Domain. Rings are simplified with
// Douglas–Peucker for phone-scale rendering; coordinates are
// \`Offset(longitude, latitude)\` in decimal degrees (WGS84).
//
// Regenerate with tool/gen_pakistan_geo.js.
library;

import 'dart:ui';

/// One administrative unit, ready to fill and label.
class PakProvince {
  final String name;

  /// Outer ring, \`Offset(lon, lat)\`.
  final List<Offset> ring;

  /// Area-weighted centroid — where the name is drawn.
  final Offset labelAt;

  const PakProvince(this.name, this.ring, this.labelAt);
}

/// National outline (${border.length} points).
const List<Offset> kPakBorder = [
${emitRing(border, '  ')}
];

/// Arabian Sea coastline, extracted from the national outline.
const List<Offset> kPakCoast = [
${emitRing(coast, '  ')}
];

/// Provinces and territories, largest first.
const List<PakProvince> kPakProvinces = [
`;

for (const p of provinces) {
  out += `  PakProvince(\n    '${p.short}',\n    [\n${emitRing(p.ring, '      ')}\n    ],\n    Offset(${p.label[0].toFixed(3)}, ${p.label[1].toFixed(3)}),\n  ),\n`;
}
out += '];\n';

const dest = 'C:/Users/ibrah/Desktop/Dawacheck/dawaacheck/lib/core/constants/pakistan_geo_data.dart';
fs.writeFileSync(dest, out);
console.log('\nwrote', dest, (out.length / 1024).toFixed(1) + ' KB');
