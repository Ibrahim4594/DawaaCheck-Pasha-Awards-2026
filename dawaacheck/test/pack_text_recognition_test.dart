import 'package:flutter_test/flutter_test.dart';
import 'package:dawaacheck/data/datasources/local/reference_catalog.dart';
import 'package:dawaacheck/data/services/pack_recognition_service.dart';

String? _key(String ocr) => PackRecognitionService.matchByText(ocr)?.key;

String _verdict(String key) =>
    kReferencePacks.firstWhere((s) => s.key == key).verdict;

void main() {
  group('PackRecognitionService.matchByText — fresh-photo OCR identification', () {
    test('verified brands resolve from realistic OCR text', () {
      expect(
          _key('CENTRUM Adult A to Zinc Multivitamin 30 Tablets Haleon'),
          'centrum');
      expect(
          _key("SeaCal Bone Strength Calcium Vitamin D3 K2 Wilson's"),
          'seacal');
      expect(_key('ZYME Q10 Coenzyme Q10 100mg Softgel Glitz'), 'zyme');
      expect(
          _key('Terbimax Terbinafine HCl 250mg Maxitech Pharma'), 'terbimax');
      expect(_key('STAT-A Atorvastatin 40mg High-Q Pharma'), 'stata');
      expect(_key('Loretin Loratadine 10mg Delux Chemical'), 'loretin');
    });

    test('DANGER packs resolve to their danger scenario (never green)', () {
      for (final ocr in const [
        'Olcuf Syrup Ivy Leaf Extract Getz Pharma 120ml', // olcuf
        'Hydryllin Expectorant Aminophylline Diphenhydramine Searle',
        'Vitux Herbal Cough Syrup Paul Brooks',
        'Calvit-K Sachet Calcium Vitamin C D K2 Bio Cool',
        'Chiltan Pure Sea Buckthorn Powder 200g',
      ]) {
        final key = _key(ocr);
        expect(key, isNotNull, reason: 'should identify: $ocr');
        expect(_verdict(key!), 'DANGER',
            reason: '$ocr resolved to $key which is not DANGER');
      }
    });

    test('matches on registration number alone', () {
      expect(_key('Registration No 013121280002 Tablets'), 'centrum');
    });

    test('matches on barcode alone', () {
      expect(_key('EAN 8964000729106'), 'seacal');
    });

    test('tolerates a single OCR character error in the brand', () {
      // "Hydrylin" (one missing l) + a mangled active still lands on hydryllin.
      expect(_key('Hydrylin Syrup Aminophyline compound'), 'hydryllin');
    });

    test('a medicine not in the set stays unknown (alien path)', () {
      expect(_key('Panadol Extra Paracetamol Caffeine GSK'), isNull);
      expect(_key('Brufen 400mg Ibuprofen Abbott'), isNull);
    });

    test('empty or noise text returns null', () {
      expect(_key(''), isNull);
      expect(_key('   ...  --- '), isNull);
      expect(_key('30 tablets store below 30c'), isNull);
    });

    test('all 20 scenarios self-identify from their own label text', () {
      expect(kReferencePacks.length, 20);
      for (final s in kReferencePacks) {
        // Simulate the OCR reading the printed brand + maker off the pack.
        final ocr = '${s.name} ${s.manufacturer}';
        final matched = PackRecognitionService.matchByText(ocr);
        expect(matched?.key, s.key,
            reason: '"$ocr" resolved to ${matched?.key}, expected ${s.key}');
      }
    });

    test('scenario set is 10 verified / 5 unverified / 5 danger', () {
      int count(String v) =>
          kReferencePacks.where((s) => s.verdict == v).length;
      expect(count('VERIFIED'), 10);
      expect(count('UNVERIFIED'), 5);
      expect(count('DANGER'), 5);
    });
  });
}
