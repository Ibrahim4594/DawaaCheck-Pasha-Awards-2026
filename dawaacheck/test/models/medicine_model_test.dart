import 'package:flutter_test/flutter_test.dart';
import 'package:dawaacheck/data/models/medicine_model.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Map<String, dynamic> _buildIngredientJson({
  String name = 'Paracetamol',
  String strength = '500',
  String? unit = 'mg',
}) {
  return {
    'name': name,
    'strength': strength,
    'unit': ?unit,
  };
}

Map<String, dynamic> _buildMedicineJson({
  String registrationNumber = 'REG-08765',
  String brandName = 'Panadol Extra',
  String? genericName = 'Paracetamol + Caffeine',
  String manufacturer = 'GSK Pakistan',
  List<Map<String, dynamic>>? activeIngredients,
  String? dosageForm = 'Tablet',
  String? strength = '500mg',
  String? packSize = '10 tablets',
  double? mrp = 85.0,
  String? registrationDate = '2020-01-15',
  String? expiryDate = '2027-06-30',
  String? status = 'Active',
}) {
  return {
    'registration_number': registrationNumber,
    'brand_name': brandName,
    'generic_name': genericName,
    'manufacturer': manufacturer,
    'active_ingredients': activeIngredients ??
        [
          _buildIngredientJson(name: 'Paracetamol', strength: '500', unit: 'mg'),
          _buildIngredientJson(name: 'Caffeine', strength: '65', unit: 'mg'),
        ],
    'dosage_form': dosageForm,
    'strength': strength,
    'pack_size': packSize,
    'mrp': mrp,
    'registration_date': registrationDate,
    'expiry_date': expiryDate,
    'status': status,
  };
}

Map<String, dynamic> _buildMinimalMedicineJson() {
  return {
    'registration_number': 'REG-MIN-001',
    'brand_name': 'Test Drug',
    'manufacturer': 'Test Pharma',
  };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ActiveIngredient', () {
    test('fromJson parses all fields', () {
      final json = _buildIngredientJson(
        name: 'Amoxicillin',
        strength: '250',
        unit: 'mg',
      );
      final ingredient = ActiveIngredient.fromJson(json);

      expect(ingredient.name, 'Amoxicillin');
      expect(ingredient.strength, '250');
      expect(ingredient.unit, 'mg');
    });

    test('fromJson handles missing unit', () {
      final json = _buildIngredientJson(unit: null);
      json.remove('unit');
      final ingredient = ActiveIngredient.fromJson(json);
      expect(ingredient.unit, isNull);
    });

    test('toJson serializes correctly', () {
      final ingredient = ActiveIngredient.fromJson(
        _buildIngredientJson(name: 'Ibuprofen', strength: '400', unit: 'mg'),
      );
      final output = ingredient.toJson();

      expect(output['name'], 'Ibuprofen');
      expect(output['strength'], '400');
      expect(output['unit'], 'mg');
    });

    test('round-trip preserves data', () {
      final original = ActiveIngredient.fromJson(
        _buildIngredientJson(name: 'Clavulanate', strength: '125', unit: 'mg'),
      );
      final roundTripped = ActiveIngredient.fromJson(original.toJson());

      expect(roundTripped.name, original.name);
      expect(roundTripped.strength, original.strength);
      expect(roundTripped.unit, original.unit);
    });

    test('Equatable: same name and strength are equal', () {
      final a = ActiveIngredient.fromJson(
        _buildIngredientJson(name: 'X', strength: '100', unit: 'mg'),
      );
      final b = ActiveIngredient.fromJson(
        _buildIngredientJson(name: 'X', strength: '100', unit: 'ml'),
      );
      // props are [name, strength], so unit difference does not matter
      expect(a, equals(b));
    });

    test('Equatable: different name means not equal', () {
      final a = ActiveIngredient.fromJson(
        _buildIngredientJson(name: 'A', strength: '100'),
      );
      final b = ActiveIngredient.fromJson(
        _buildIngredientJson(name: 'B', strength: '100'),
      );
      expect(a, isNot(equals(b)));
    });
  });

  group('MedicineModel.fromJson', () {
    test('parses complete JSON with active ingredients', () {
      final json = _buildMedicineJson();
      final model = MedicineModel.fromJson(json);

      expect(model.registrationNumber, 'REG-08765');
      expect(model.brandName, 'Panadol Extra');
      expect(model.genericName, 'Paracetamol + Caffeine');
      expect(model.manufacturer, 'GSK Pakistan');
      expect(model.activeIngredients, hasLength(2));
      expect(model.activeIngredients[0].name, 'Paracetamol');
      expect(model.activeIngredients[0].strength, '500');
      expect(model.activeIngredients[0].unit, 'mg');
      expect(model.activeIngredients[1].name, 'Caffeine');
      expect(model.activeIngredients[1].strength, '65');
      expect(model.dosageForm, 'Tablet');
      expect(model.strength, '500mg');
      expect(model.packSize, '10 tablets');
      expect(model.mrp, 85.0);
      expect(model.registrationDate, '2020-01-15');
      expect(model.expiryDate, '2027-06-30');
      expect(model.status, 'Active');
    });

    test('parses minimal JSON with defaults for missing optional fields', () {
      final json = _buildMinimalMedicineJson();
      final model = MedicineModel.fromJson(json);

      expect(model.registrationNumber, 'REG-MIN-001');
      expect(model.brandName, 'Test Drug');
      expect(model.manufacturer, 'Test Pharma');
      expect(model.genericName, isNull);
      expect(model.activeIngredients, isEmpty);
      expect(model.dosageForm, isNull);
      expect(model.strength, isNull);
      expect(model.packSize, isNull);
      expect(model.mrp, isNull);
      expect(model.registrationDate, isNull);
      expect(model.expiryDate, isNull);
      expect(model.status, isNull);
    });

    test('handles null active_ingredients list', () {
      final json = _buildMinimalMedicineJson();
      json['active_ingredients'] = null;
      final model = MedicineModel.fromJson(json);
      expect(model.activeIngredients, isEmpty);
    });

    test('handles empty active_ingredients list', () {
      final json = _buildMedicineJson(activeIngredients: []);
      final model = MedicineModel.fromJson(json);
      expect(model.activeIngredients, isEmpty);
    });

    test('parses mrp from int to double', () {
      final json = _buildMedicineJson(mrp: 100.0);
      // Simulate integer mrp from JSON
      json['mrp'] = 100;
      final model = MedicineModel.fromJson(json);
      expect(model.mrp, 100.0);
    });

    test('parses multiple active ingredients correctly', () {
      final json = _buildMedicineJson(
        activeIngredients: [
          _buildIngredientJson(name: 'Amoxicillin', strength: '500', unit: 'mg'),
          _buildIngredientJson(name: 'Clavulanate', strength: '125', unit: 'mg'),
          _buildIngredientJson(name: 'Lactose', strength: '50', unit: 'mg'),
        ],
      );
      final model = MedicineModel.fromJson(json);

      expect(model.activeIngredients, hasLength(3));
      expect(model.activeIngredients[0].name, 'Amoxicillin');
      expect(model.activeIngredients[1].name, 'Clavulanate');
      expect(model.activeIngredients[2].name, 'Lactose');
    });
  });

  group('MedicineModel.toJson', () {
    test('serializes all fields including nested ingredients', () {
      final json = _buildMedicineJson();
      final model = MedicineModel.fromJson(json);
      final output = model.toJson();

      expect(output['registration_number'], 'REG-08765');
      expect(output['brand_name'], 'Panadol Extra');
      expect(output['generic_name'], 'Paracetamol + Caffeine');
      expect(output['manufacturer'], 'GSK Pakistan');
      expect(output['active_ingredients'], isList);
      expect((output['active_ingredients'] as List), hasLength(2));
      expect(output['dosage_form'], 'Tablet');
      expect(output['strength'], '500mg');
      expect(output['pack_size'], '10 tablets');
      expect(output['mrp'], 85.0);
      expect(output['registration_date'], '2020-01-15');
      expect(output['expiry_date'], '2027-06-30');
      expect(output['status'], 'Active');
    });

    test('round-trip fromJson(toJson(model)) preserves all data', () {
      final original = MedicineModel.fromJson(_buildMedicineJson());
      final roundTripped = MedicineModel.fromJson(original.toJson());

      expect(roundTripped.registrationNumber, original.registrationNumber);
      expect(roundTripped.brandName, original.brandName);
      expect(roundTripped.genericName, original.genericName);
      expect(roundTripped.manufacturer, original.manufacturer);
      expect(roundTripped.activeIngredients.length, original.activeIngredients.length);
      for (var i = 0; i < original.activeIngredients.length; i++) {
        expect(roundTripped.activeIngredients[i].name, original.activeIngredients[i].name);
        expect(
          roundTripped.activeIngredients[i].strength,
          original.activeIngredients[i].strength,
        );
        expect(roundTripped.activeIngredients[i].unit, original.activeIngredients[i].unit);
      }
      expect(roundTripped.dosageForm, original.dosageForm);
      expect(roundTripped.strength, original.strength);
      expect(roundTripped.packSize, original.packSize);
      expect(roundTripped.mrp, original.mrp);
      expect(roundTripped.registrationDate, original.registrationDate);
      expect(roundTripped.expiryDate, original.expiryDate);
      expect(roundTripped.status, original.status);
    });

    test('round-trip with minimal data preserves nulls', () {
      final original = MedicineModel.fromJson(_buildMinimalMedicineJson());
      final roundTripped = MedicineModel.fromJson(original.toJson());

      expect(roundTripped.genericName, isNull);
      expect(roundTripped.activeIngredients, isEmpty);
      expect(roundTripped.dosageForm, isNull);
      expect(roundTripped.mrp, isNull);
      expect(roundTripped.status, isNull);
    });
  });

  group('MedicineModel Equatable', () {
    test('two models with same registrationNumber and brandName are equal', () {
      final a = MedicineModel.fromJson(_buildMedicineJson());
      final b = MedicineModel.fromJson(_buildMedicineJson(mrp: 999.0, status: 'Inactive'));
      expect(a, equals(b));
    });

    test('two models with different registrationNumber are not equal', () {
      final a = MedicineModel.fromJson(_buildMedicineJson(registrationNumber: 'REG-001'));
      final b = MedicineModel.fromJson(_buildMedicineJson(registrationNumber: 'REG-002'));
      expect(a, isNot(equals(b)));
    });

    test('two models with different brandName are not equal', () {
      final a = MedicineModel.fromJson(_buildMedicineJson(brandName: 'Drug A'));
      final b = MedicineModel.fromJson(_buildMedicineJson(brandName: 'Drug B'));
      expect(a, isNot(equals(b)));
    });
  });
}
