import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../../core/../../data/datasources/local/reference_catalog.dart';

/// Pre-computed 8x8 average-hashes (16-char hex) of the 20 bundled reference
/// medicine fronts. Baked at build time by `tool/gen_ahash.dart` so the app
/// never decodes the reference images at runtime — only the single uploaded
/// photo is hashed, and that runs in a background isolate. Keeps scanning fast.
const Map<String, String> kRefHashes = {
  'bistrum': 'f4fde0c017fcff00',
  'calvit': '00be7ee0fcfefaff',
  'centrum': 'c9f0e15e7e1c320e',
  'cipotic': '0000089c1c187ef5',
  'dioplus': 'e7e6a400f8efff5d',
  'hydryllin': 'bfc2b8e0df131f1f',
  'lederplex': '1e1e1e1e181e1c1c',
  'lemsip': 'f7ffe7e49ce00001',
  'loretin': '00ffffffdff3ffcf',
  'maxflow': 'ffc0c0ac80c0fff0',
  'olcuf': '7c7cfc5c7c743c30',
  'prostryl': '0000fffffcf9f0e6',
  'renitec': 'e4ece4ececececec',
  'seabuckthorn': '0301ffc6fec6e6c6',
  'seacal': '0dc1c1be7f7e6b6d',
  'sgindrop': '00000071637b7c66',
  'stata': 'cfcc4201fe3f5b02',
  'terbimax': '00ffff7dfcf0fcf8',
  'vitux': 'f8f40404003c34a0',
  'zyme': 'ecca7f471f43057f',
};

/// Distinctive text tokens per scenario, used to identify a medicine from a
/// FRESH photo via on-device OCR (angle/lighting/pack-independent). Brand names
/// plus actives that are unique across the 20 — deliberately NO shared words
/// like "vitamin", "calcium" or "ivy" that would cause cross-matches.
const Map<String, List<String>> kScenarioKeywords = {
  'centrum': ['centrum'],
  'seacal': ['seacal', 'sea cal', 'bone strength', 'wilson'],
  'zyme': ['zyme q10', 'zyme', 'coenzyme q10'],
  'terbimax': ['terbimax', 'terbinafine'],
  'bistrum': ['bistrum'],
  'lemsip': ['lemsip'],
  'dioplus': ['dioplus', 'amlodipine', 'valsartan'],
  'renitec': ['renitec', 'enalapril'],
  'prostryl': ['prostryl', 'finasteride'],
  'stata': ['stat-a', 'stata', 'atorvastatin'],
  'loretin': ['loretin', 'loratadine'],
  'maxflow': ['maxflow', 'max flow', 'dutasteride', 'tamsulosin'],
  'cipotic': ['cipotic', 'ciprofloxacin'],
  'sgindrop': ['sgindrop', 'sg indrop', 'indrop'],
  'lederplex': ['lederplex'],
  'hydryllin': ['hydryllin', 'aminophylline'],
  'seabuckthorn': ['sea buckthorn', 'buckthorn', 'chiltan'],
  'calvit': ['calvit'],
  'vitux': ['vitux'],
  'olcuf': ['olcuf'],
};

/// Identifies which catalogued pack was scanned. Two independent
/// signals so a fresh, real-world photo still resolves to the RIGHT verdict:
///   • [matchExact] / [matchByHash] — pixel signals (fast for re-uploads)
///   • [matchByText] — OCR text signal (robust for fresh captures)
class PackRecognitionService {
  PackRecognitionService._();

  /// Max Hamming distance (of 64 bits) to accept a known medicine. Known boxes
  /// match their own reference at 0–5; an unknown box lands far above this.
  static const int _maxDistance = 16;

  /// Minimum text score to accept an OCR match. A distinctive 4+ char brand
  /// token scores 16; a registration number 60; a barcode 100.
  static const double _minTextScore = 16;

  /// Legacy combined entry point (byte-size then hash). Kept for callers/tests
  /// that identify a bundled reference image directly.
  static Future<ReferencePack?> match(Uint8List frontBytes) async {
    return matchExact(frontBytes) ?? await matchByHash(frontBytes);
  }

  // ── Tier 1 — exact byte size (unmodified reference upload) ──
  static ReferencePack? matchExact(Uint8List frontBytes) {
    for (final s in kReferencePacks) {
      if (frontBytes.length == s.frontByteSize) return s;
    }
    return null;
  }

  // ── Tier 2 — OCR text match (fresh photo of a real pack) ──
  static ReferencePack? matchByText(String rawText) {
    final hay = rawText.toLowerCase();
    final hayCompact = hay.replaceAll(RegExp(r'[^a-z0-9]'), '');
    final hayDigits = rawText.replaceAll(RegExp(r'[^0-9]'), '');
    if (hayCompact.length < 3) return null;
    final hayWords = hay.split(RegExp(r'[^a-z0-9]+')).where((w) => w.length >= 4);

    ReferencePack? best;
    double bestScore = 0;
    double secondScore = 0;
    for (final s in kReferencePacks) {
      final score = _scoreScenario(s, hayCompact, hayDigits, hayWords);
      if (score > bestScore) {
        secondScore = bestScore;
        bestScore = score;
        best = s;
      } else if (score > secondScore) {
        secondScore = score;
      }
    }

    if (best == null || bestScore < _minTextScore) return null;
    // Guard against an ambiguous tie between two scenarios with no corroborating
    // reg/barcode signal — better to fall through to label OCR than mislabel.
    if (bestScore - secondScore < 8 && bestScore < 60) return null;

    debugPrint('[OFFLINE] text-matched ${best.key} (score=$bestScore)');
    return best;
  }

  static double _scoreScenario(
    ReferencePack s,
    String hayCompact,
    String hayDigits,
    Iterable<String> hayWords,
  ) {
    double score = 0;

    for (final k in _keywordsFor(s)) {
      final kc = k.replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (kc.length < 4) continue;
      if (hayCompact.contains(kc)) {
        score += kc.length * 4;
      } else if (kc.length >= 6 && hayWords.any((w) => _within1(w, kc))) {
        score += kc.length * 2; // tolerate a single OCR character error
      }
    }

    final reg = _digitsOf(s.regNumber);
    if (reg.length >= 5 && hayDigits.contains(reg)) score += 60;

    final bc = _digitsOf(s.barcode);
    if (bc.length >= 8 && hayDigits.contains(bc)) score += 100;

    return score;
  }

  static Set<String> _keywordsFor(ReferencePack s) {
    final out = <String>{...?kScenarioKeywords[s.key]};
    // Auto-add the brand's first word when it's distinctive (>= 5 chars) so a
    // scenario without an explicit entry still matches on its name.
    final head = s.name.split('(').first.trim();
    final first = head.split(RegExp(r'\s+')).first.toLowerCase();
    final compact = first.replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (compact.length >= 5) out.add(compact);
    return out;
  }

  static String _digitsOf(String? s) =>
      s == null ? '' : s.replaceAll(RegExp(r'[^0-9]'), '');

  /// True if [a] and [b] differ by at most one edit (Levenshtein ≤ 1).
  static bool _within1(String a, String b) {
    if ((a.length - b.length).abs() > 1) return false;
    if (a == b) return true;
    int i = 0, j = 0, edits = 0;
    while (i < a.length && j < b.length) {
      if (a[i] == b[j]) {
        i++;
        j++;
      } else {
        if (++edits > 1) return false;
        if (a.length > b.length) {
          i++;
        } else if (a.length < b.length) {
          j++;
        } else {
          i++;
          j++;
        }
      }
    }
    if (i < a.length || j < b.length) edits++;
    return edits <= 1;
  }

  // ── Tier 3 — perceptual hash fallback ──
  static Future<ReferencePack?> matchByHash(Uint8List frontBytes) async {
    final probe = await compute(aHashOf, frontBytes);
    if (probe == null) return null;

    ReferencePack? best;
    int bestDist = 1 << 30;
    for (final s in kReferencePacks) {
      final hex = kRefHashes[s.key];
      if (hex == null) continue;
      final d = _hammingHex(probe, hex);
      if (d < bestDist) {
        bestDist = d;
        best = s;
      }
    }

    if (best != null && bestDist <= _maxDistance) {
      debugPrint('[OFFLINE] hash-matched ${best.key} (hamming=$bestDist)');
      return best;
    }
    debugPrint('[OFFLINE] no pixel match (nearest hamming=$bestDist)');
    return null;
  }

  /// Hamming distance between a 64-bit bit list and a 16-char hex hash.
  static int _hammingHex(List<bool> bits, String hex) {
    var d = 0;
    for (var i = 0; i < 16; i++) {
      final nibble = int.parse(hex[i], radix: 16);
      for (var j = 0; j < 4; j++) {
        final bit = (nibble >> (3 - j)) & 1 == 1;
        final idx = i * 4 + j;
        if (idx < bits.length && bits[idx] != bit) d++;
      }
    }
    return d;
  }
}

/// 8×8 average-hash on the center 60% of the image. Top-level so it can run via
/// `compute()` in a background isolate. Returns 64 bits, or null if undecodable.
List<bool>? aHashOf(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;

  final cw = (decoded.width * 0.6).round().clamp(1, decoded.width);
  final ch = (decoded.height * 0.6).round().clamp(1, decoded.height);
  final cx = ((decoded.width - cw) / 2).round();
  final cy = ((decoded.height - ch) / 2).round();

  final cropped = img.copyCrop(decoded, x: cx, y: cy, width: cw, height: ch);
  final small = img.copyResize(img.grayscale(cropped), width: 8, height: 8);

  final lums = <double>[];
  double sum = 0;
  for (var y = 0; y < 8; y++) {
    for (var x = 0; x < 8; x++) {
      final l = small.getPixel(x, y).luminance.toDouble();
      lums.add(l);
      sum += l;
    }
  }
  final mean = sum / lums.length;
  return [for (final l in lums) l >= mean];
}
