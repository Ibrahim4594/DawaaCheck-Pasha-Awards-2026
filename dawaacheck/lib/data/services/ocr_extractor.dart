import 'package:flutter/foundation.dart';

import 'ocr_line.dart';
// Platform OCR backend: real ML Kit on mobile, no-op on web/desktop.
import 'ocr_recognizer_stub.dart'
    if (dart.library.io) 'ocr_recognizer_io.dart';

/// What the on-device OCR pulled off a medicine box.
@immutable
class OcrResult {
  final String? name;
  final List<String> ingredients;
  final String? manufacturer;
  final String? strength; // e.g. "500mg"
  final String? form; // e.g. "Tablets"

  const OcrResult({
    this.name,
    this.ingredients = const [],
    this.manufacturer,
    this.strength,
    this.form,
  });

  /// "Panadol 500mg Tablets" — best human label we can build.
  String displayName(String fallback) {
    final n = (name != null && name!.isNotEmpty) ? name! : fallback;
    final parts = <String>[n];
    if (strength != null && !n.toLowerCase().contains(strength!.toLowerCase())) {
      parts.add(strength!);
    }
    if (form != null) parts.add(form!);
    return parts.join(' ');
  }
}

/// Reads printed text off a medicine photo on-device (Google ML Kit on mobile;
/// gracefully no-ops on web). Used for medicines that aren't one of the known
/// the reference catalogue, so the result shows the real printed name and
/// composition rather than a generic placeholder.
class OcrExtractor {
  OcrExtractor._();

  static const _nameStop = [
    'tablet', 'tablets', 'capsule', 'capsules', 'syrup', 'suspension',
    'drops', 'sachet', 'sachets', 'injection', 'cream', 'ointment', 'gel',
    'solution', 'softgel', 'spray', 'inhaler', 'composition', 'each',
    'contains', 'store', 'keep', 'warning', 'caution', 'dosage', 'directions',
    'indications', 'manufactured', 'marketed', 'product', 'batch', 'mfg',
    'exp', 'reg', 'm.r.p', 'mrp', 'rs', 'price', 'usp', 'b.p', 'ph.eur',
    'oral', 'sterile', 'for', 'use', 'read', 'leaflet', 'ingredients',
    'premium', 'natural', 'halal', 'iso', 'certified', 'www', '.com',
  ];

  static const _makerHints = [
    'pharma', 'laborator', 'labs', 'ltd', 'pvt', 'industries', 'healthcare',
    'health care', 'chemical', 'nutrition', 'lifecare', 'life care',
    'company', 'limited',
  ];

  static const _formWords = {
    'tablets': 'Tablets', 'tablet': 'Tablets', 'caplets': 'Caplets',
    'capsules': 'Capsules', 'capsule': 'Capsules', 'softgel': 'Softgel Capsules',
    'syrup': 'Syrup', 'suspension': 'Suspension', 'drops': 'Drops',
    'sachet': 'Sachets', 'sachets': 'Sachets', 'injection': 'Injection',
    'cream': 'Cream', 'ointment': 'Ointment', 'gel': 'Gel', 'lotion': 'Lotion',
    'spray': 'Spray', 'inhaler': 'Inhaler', 'solution': 'Solution',
    'powder': 'Powder',
  };

  static const _actives = [
    'paracetamol', 'acetaminophen', 'ibuprofen', 'aspirin', 'diclofenac',
    'naproxen', 'mefenamic', 'amoxicillin', 'augmentin', 'clavulanic',
    'azithromycin', 'ciprofloxacin', 'levofloxacin', 'cephalexin', 'cefixime',
    'ceftriaxone', 'metronidazole', 'omeprazole', 'esomeprazole', 'pantoprazole',
    'ranitidine', 'famotidine', 'metformin', 'glimepiride', 'amlodipine',
    'valsartan', 'losartan', 'telmisartan', 'atenolol', 'bisoprolol',
    'carvedilol', 'enalapril', 'lisinopril', 'atorvastatin', 'rosuvastatin',
    'simvastatin', 'loratadine', 'cetirizine', 'fexofenadine', 'montelukast',
    'salbutamol', 'prednisolone', 'dexamethasone', 'hydrocortisone',
    'terbinafine', 'fluconazole', 'itraconazole', 'dutasteride', 'tamsulosin',
    'finasteride', 'guaifenesin', 'phenylephrine', 'pseudoephedrine',
    'chlorpheniramine', 'diphenhydramine', 'dextromethorphan', 'aminophylline',
    'theophylline', 'domperidone', 'metoclopramide', 'ondansetron', 'tramadol',
    'codeine', 'gabapentin', 'pregabalin', 'sertraline', 'fluoxetine',
    'escitalopram', 'alprazolam', 'diazepam', 'levothyroxine', 'insulin',
    'vitamin', 'calcium', 'folic', 'iron', 'zinc', 'magnesium', 'coenzyme',
    'multivitamin', 'ascorbic', 'cholecalciferol', 'cyanocobalamin',
    'pyridoxine', 'thiamine', 'riboflavin', 'niacinamide', 'biotin',
    'ivy leaf', 'glycyrrhiza', 'thymus',
  ];

  // English active → Urdu name (bilingual ingredient output).
  static const _activeUrdu = {
    'paracetamol': 'پیراسیٹامول',
    'acetaminophen': 'پیراسیٹامول',
    'ibuprofen': 'آئبوپروفین',
    'aspirin': 'اسپرین',
    'diclofenac': 'ڈائیکلوفینیک',
    'amoxicillin': 'اموکسیسلن',
    'azithromycin': 'ایزیتھرومائسن',
    'ciprofloxacin': 'سپروفلوکساسن',
    'cephalexin': 'سیفالیکسن',
    'cefixime': 'سیفکسیم',
    'metronidazole': 'میٹرونیڈازول',
    'omeprazole': 'اومیپرازول',
    'esomeprazole': 'ایسومیپرازول',
    'ranitidine': 'رینیٹیڈین',
    'metformin': 'میٹفارمن',
    'amlodipine': 'ایملوڈپین',
    'valsartan': 'والسارٹن',
    'losartan': 'لوسارٹن',
    'telmisartan': 'ٹیلمیسارٹن',
    'atenolol': 'ایٹینولول',
    'bisoprolol': 'بایسوپرولول',
    'enalapril': 'اینالاپرل',
    'atorvastatin': 'اٹورواسٹیٹن',
    'rosuvastatin': 'روزواسٹیٹن',
    'simvastatin': 'سمواسٹیٹن',
    'loratadine': 'لوریٹاڈین',
    'cetirizine': 'سیٹیریزین',
    'fexofenadine': 'فیکسوفیناڈین',
    'montelukast': 'مونٹیلوکاسٹ',
    'salbutamol': 'سالبوٹامول',
    'prednisolone': 'پریڈنیسولون',
    'dexamethasone': 'ڈیکسامیتھازون',
    'terbinafine': 'ٹربینافین',
    'fluconazole': 'فلوکونازول',
    'dutasteride': 'ڈوٹاسٹرائیڈ',
    'tamsulosin': 'ٹامسولوسن',
    'finasteride': 'فائناسٹرائیڈ',
    'guaifenesin': 'گوائفینیسن',
    'phenylephrine': 'فینائلایفرین',
    'chlorpheniramine': 'کلورفینیرامین',
    'diphenhydramine': 'ڈائفین ہائیڈرامین',
    'dextromethorphan': 'ڈیکسٹرومیتھورفن',
    'aminophylline': 'امینوفلین',
    'domperidone': 'ڈومپیریڈون',
    'ondansetron': 'اونڈانسیٹرون',
    'tramadol': 'ٹرامادول',
    'gabapentin': 'گاباپینٹن',
    'pregabalin': 'پری گابالین',
    'sertraline': 'سرٹرالین',
    'fluoxetine': 'فلوکسٹین',
    'levothyroxine': 'لیووتھائروکسن',
    'insulin': 'انسولین',
    'vitamin': 'وٹامن',
    'calcium': 'کیلشیم',
    'folic': 'فولک ایسڈ',
    'iron': 'آئرن',
    'zinc': 'زنک',
    'magnesium': 'میگنیشیم',
    'coenzyme': 'کوآنزائم',
    'multivitamin': 'ملٹی وٹامن',
    'ascorbic': 'ایسکاربک ایسڈ',
    'cholecalciferol': 'وٹامن ڈی۳',
    'ivy leaf': 'آئیوی لیف',
    'glycyrrhiza': 'ملٹھی',
    'thymus': 'جنگلی اجوائن',
  };

  static final _strengthRe =
      RegExp(r'\b\d+(?:[.,]\d+)?\s?(?:mg|mcg|g|ml|iu|%)\b', caseSensitive: false);
  static final _digitsOnly = RegExp(r'^[\d\s.,/:-]+$');

  /// Extract the medicine details. Never throws — returns an empty [OcrResult]
  /// if anything goes wrong (or on platforms without an OCR model, e.g. web).
  static Future<OcrResult> extract(
    Uint8List frontBytes, [
    Uint8List? backBytes,
    Uint8List? ingredientsBytes,
  ]) async {
    return (await read(frontBytes, backBytes, ingredientsBytes)).parsed;
  }

  /// Like [extract] but also returns the raw recognised text, so the caller can
  /// both (a) text-match the photo against known medicines and (b) fall back to
  /// the parsed [OcrResult] for an unknown box — all from a single OCR pass.
  static Future<({OcrResult parsed, String rawText})> read(
    Uint8List frontBytes, [
    Uint8List? backBytes,
    Uint8List? ingredientsBytes,
  ]) async {
    try {
      final front = await recognizeImage(frontBytes);
      final extra = <OcrLine>[
        if (backBytes != null) ...await recognizeImage(backBytes),
        if (ingredientsBytes != null) ...await recognizeImage(ingredientsBytes),
      ];
      final all = [...front, ...extra];
      if (all.isEmpty) return (parsed: const OcrResult(), rawText: '');

      final parsed = OcrResult(
        name: _pickName(front.isNotEmpty ? front : all),
        manufacturer: _pickManufacturer(all),
        ingredients: _pickIngredients(all),
        strength: _pickStrength(all),
        form: _pickForm(all),
      );
      final rawText = all.map((l) => l.text).join(' ');
      return (parsed: parsed, rawText: rawText);
    } catch (e) {
      debugPrint('[OCR] failed: $e');
      return (parsed: const OcrResult(), rawText: '');
    }
  }

  static String? _pickName(List<OcrLine> lines) {
    if (lines.isEmpty) return null;
    final maxTop =
        lines.map((l) => l.top).fold<double>(1, (a, b) => a > b ? a : b);

    OcrLine? best;
    double bestScore = -1;
    for (final l in lines) {
      final t = l.text;
      if (t.length < 3 || t.length > 34) continue;
      final low = t.toLowerCase();
      if (_digitsOnly.hasMatch(t)) continue;
      if (_nameStop.any(low.contains)) continue;
      if (_makerHints.any(low.contains)) continue;
      if (_strengthRe.hasMatch(t)) continue;
      final letters = t.replaceAll(RegExp(r'[^A-Za-z]'), '').length;
      if (letters < 3) continue;
      final topFactor = maxTop > 0 ? (1 - l.top / maxTop) : 0.0;
      final score = l.height * (1 + 0.6 * topFactor);
      if (score > bestScore) {
        bestScore = score;
        best = l;
      }
    }
    return best == null ? null : _titleCase(_stripTm(best.text));
  }

  static String? _pickManufacturer(List<OcrLine> lines) {
    for (final l in lines) {
      final low = l.text.toLowerCase();
      if (_makerHints.any(low.contains) && l.text.length <= 48) {
        return _titleCase(_stripTm(l.text));
      }
    }
    return null;
  }

  static List<String> _pickIngredients(List<OcrLine> lines) {
    final out = <String>[];
    void add(String s) {
      final c = _stripTm(s);
      if (c.length >= 3 && c.length <= 80 && !out.contains(c)) out.add(c);
    }

    for (final l in lines) {
      if (out.length >= 6) break;
      final low = l.text.toLowerCase();
      String? matchedActive;
      for (final a in _actives) {
        if (low.contains(a)) {
          matchedActive = a;
          break;
        }
      }
      final hasUnit = _strengthRe.hasMatch(l.text);
      final hasParen = l.text.contains('(') && l.text.contains(')');

      if (matchedActive != null) {
        var text = _stripTm(l.text);
        final urdu = _activeUrdu[matchedActive];
        if (urdu != null && !text.contains(urdu)) text = '$text ($urdu)';
        add(text);
      } else if ((hasUnit && !_digitsOnly.hasMatch(l.text)) || hasParen) {
        add(l.text);
      }
    }
    return out;
  }

  static String? _pickStrength(List<OcrLine> lines) {
    for (final l in lines) {
      final m = _strengthRe.firstMatch(l.text);
      if (m != null) return m.group(0)!.replaceAll(' ', '');
    }
    return null;
  }

  static String? _pickForm(List<OcrLine> lines) {
    for (final l in lines) {
      final low = l.text.toLowerCase();
      for (final entry in _formWords.entries) {
        if (RegExp('\\b${entry.key}\\b').hasMatch(low)) return entry.value;
      }
    }
    return null;
  }

  static String _stripTm(String s) =>
      s.replaceAll(RegExp(r'[®™©]'), '').replaceAll(RegExp(r'\s+'), ' ').trim();

  static String _titleCase(String s) {
    return s.split(' ').map((w) {
      if (w.isEmpty) return w;
      if (w.length <= 3 && w == w.toUpperCase()) return w;
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');
  }
}
