import 'package:equatable/equatable.dart';

class MedicineModel extends Equatable {
  final String registrationNumber;
  final String brandName;
  final String? genericName;
  final String manufacturer;
  final List<ActiveIngredient> activeIngredients;
  final String? dosageForm;
  final String? strength;
  final String? packSize;
  final double? mrp;
  final String? registrationDate;
  final String? expiryDate;
  final String? status;

  const MedicineModel({
    required this.registrationNumber,
    required this.brandName,
    this.genericName,
    required this.manufacturer,
    this.activeIngredients = const [],
    this.dosageForm,
    this.strength,
    this.packSize,
    this.mrp,
    this.registrationDate,
    this.expiryDate,
    this.status,
  });

  factory MedicineModel.fromJson(Map<String, dynamic> json) {
    return MedicineModel(
      registrationNumber: json['registration_number'] as String,
      brandName: json['brand_name'] as String,
      genericName: json['generic_name'] as String?,
      manufacturer: json['manufacturer'] as String,
      activeIngredients: (json['active_ingredients'] as List<dynamic>?)
              ?.map((e) => ActiveIngredient.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      dosageForm: json['dosage_form'] as String?,
      strength: json['strength'] as String?,
      packSize: json['pack_size'] as String?,
      mrp: (json['mrp'] as num?)?.toDouble(),
      registrationDate: json['registration_date'] as String?,
      expiryDate: json['expiry_date'] as String?,
      status: json['status'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'registration_number': registrationNumber,
      'brand_name': brandName,
      'generic_name': genericName,
      'manufacturer': manufacturer,
      'active_ingredients': activeIngredients.map((e) => e.toJson()).toList(),
      'dosage_form': dosageForm,
      'strength': strength,
      'pack_size': packSize,
      'mrp': mrp,
      'registration_date': registrationDate,
      'expiry_date': expiryDate,
      'status': status,
    };
  }

  @override
  List<Object?> get props => [registrationNumber, brandName];
}

class ActiveIngredient extends Equatable {
  final String name;
  final String strength;
  final String? unit;

  const ActiveIngredient({
    required this.name,
    required this.strength,
    this.unit,
  });

  factory ActiveIngredient.fromJson(Map<String, dynamic> json) {
    return ActiveIngredient(
      name: json['name'] as String,
      strength: json['strength'] as String,
      unit: json['unit'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {'name': name, 'strength': strength, 'unit': unit};

  @override
  List<Object?> get props => [name, strength];
}
