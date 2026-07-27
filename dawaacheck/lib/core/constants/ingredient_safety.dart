// Ingredient-based safety rules. Scans the medicine name + composition text and
// returns consumer warnings — e.g. aspirin is dangerous for children (Reye's
// syndrome), antibiotics must be prescription-only. Applied to BOTH known
// catalogued packs and labels read on-device.

class _SafetyRule {
  final List<String> keywords;
  final String warning;
  const _SafetyRule(this.keywords, this.warning);
}

const List<_SafetyRule> _rules = [
  _SafetyRule(
    ['aspirin', 'acetylsalicylic', 'aspirin'],
    '⚠ Contains Aspirin — do NOT give to children or teenagers under 16. It can trigger Reye’s syndrome, a rare but often fatal illness.',
  ),
  _SafetyRule(
    [
      'antibiotic', 'amoxicillin', 'augmentin', 'clavulanic', 'azithromycin',
      'clarithromycin', 'ciprofloxacin', 'levofloxacin', 'ofloxacin',
      'cephalexin', 'cefixime', 'ceftriaxone', 'cefuroxime', 'metronidazole',
      'penicillin', 'erythromycin', 'gentamicin', 'co-amoxiclav',
    ],
    '⚠ Contains an antibiotic — use ONLY on a doctor’s prescription and finish the full course. Misuse drives antibiotic resistance (a major risk in Pakistan).',
  ),
  _SafetyRule(
    ['codeine'],
    '⚠ Contains Codeine — not for children under 12, and not for breastfeeding mothers.',
  ),
  _SafetyRule(
    ['tetracycline', 'doxycycline', 'minocycline'],
    '⚠ Tetracycline antibiotic — avoid in children under 8 and during pregnancy (can stain teeth and affect bone growth).',
  ),
  _SafetyRule(
    ['nimesulide'],
    '⚠ Contains Nimesulide — NOT recommended for children due to serious liver-safety concerns.',
  ),
  _SafetyRule(
    ['aminophylline', 'theophylline'],
    '⚠ Contains aminophylline/theophylline — narrow safety margin; use the exact dose and keep away from children.',
  ),
];

// Actives/keywords that indicate a serious, chronic or high-risk condition
// (heart, blood pressure, diabetes, blood thinners, epilepsy, psych, thyroid).
const List<String> _seriousConditionKeywords = [
  // Heart / blood pressure / cholesterol
  'amlodipine', 'valsartan', 'losartan', 'telmisartan', 'atenolol',
  'bisoprolol', 'carvedilol', 'metoprolol', 'enalapril', 'lisinopril',
  'ramipril', 'nitroglycerin', 'isosorbide', 'digoxin', 'atorvastatin',
  'rosuvastatin', 'simvastatin', 'blood pressure', 'hypertension',
  'cardiovascular', 'cardiac', 'heart',
  // Blood thinners
  'warfarin', 'clopidogrel', 'rivaroxaban', 'heparin',
  // Diabetes
  'metformin', 'glimepiride', 'gliclazide', 'insulin', 'sitagliptin',
  'diabet',
  // Epilepsy / neuro
  'phenytoin', 'carbamazepine', 'valproate', 'levetiracetam', 'gabapentin',
  'pregabalin',
  // Psychiatric
  'sertraline', 'fluoxetine', 'escitalopram', 'alprazolam', 'diazepam',
  'olanzapine', 'risperidone',
  // Thyroid
  'levothyroxine', 'carbimazole',
];

/// If [text] looks like a serious-condition medicine, returns a strong
/// "consult a doctor before buying" warning — otherwise null. Meant to be shown
/// only on UNVERIFIED / DANGER (yellow / red) verdicts.
String? consultDoctorWarning(String text) {
  final low = text.toLowerCase();
  if (_seriousConditionKeywords.any(low.contains)) {
    return '🩺 This medicine is used for a serious condition (heart, blood pressure, diabetes, etc.). As this scan is NOT fully verified, it is better to consult a doctor before buying or using it.';
  }
  return null;
}

/// Best-effort halal assessment for an unknown medicine, from its OCR text +
/// dosage form. Returns a status (HALAL / VERIFY / NOT_HALAL) and a reason.
({String status, String reason}) halalAssessment(String text, String? form) {
  final low = text.toLowerCase();
  final f = (form ?? '').toLowerCase();

  if (low.contains('pork') || low.contains('porcine') || low.contains('lard')) {
    return (
      status: 'NOT_HALAL',
      reason: 'Label suggests a pork/porcine-derived ingredient.',
    );
  }
  if (low.contains('gelatin') || low.contains('gelatine')) {
    if (low.contains('halal') ||
        low.contains('bovine') ||
        low.contains('fish') ||
        low.contains('plant') ||
        low.contains('vegetarian')) {
      return (status: 'HALAL', reason: 'Gelatin from a permissible source.');
    }
    return (
      status: 'VERIFY',
      reason:
          'Contains gelatin — animal source not stated. Ask for a halal-certified batch.',
    );
  }
  if (low.contains('alcohol') || low.contains('ethanol')) {
    return (
      status: 'VERIFY',
      reason: 'May contain alcohol — confirm a halal-certified version.',
    );
  }
  if (f.contains('capsule') || f.contains('softgel')) {
    return (
      status: 'VERIFY',
      reason:
          'Capsule shell is usually gelatin of unconfirmed source. Ask for a halal-certified or vegetarian capsule.',
    );
  }
  if (f.contains('tablet') ||
      f.contains('caplet') ||
      f.contains('sachet') ||
      f.contains('powder') ||
      f.contains('drops')) {
    return (
      status: 'HALAL',
      reason: 'No animal-derived ingredients detected in the read text.',
    );
  }
  return (
    status: 'VERIFY',
    reason: 'Could not confirm — check the halal certification on the pack.',
  );
}

/// Returns de-duplicated warnings for any risky actives found in [text]
/// (medicine name + ingredients + agent messages, combined).
List<String> ingredientSafetyWarnings(String text) {
  final low = text.toLowerCase();
  final out = <String>[];
  for (final rule in _rules) {
    if (rule.keywords.any(low.contains) && !out.contains(rule.warning)) {
      out.add(rule.warning);
    }
  }
  return out;
}
