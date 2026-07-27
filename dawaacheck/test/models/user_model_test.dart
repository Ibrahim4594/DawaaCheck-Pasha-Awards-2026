import 'package:flutter_test/flutter_test.dart';
import 'package:dawaacheck/data/models/user_model.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Map<String, dynamic> _buildUserJson({
  String id = 'uid_001',
  String? email = 'ibrahim@example.com',
  String? displayName = 'Ibrahim Samad',
  String? photoUrl = 'https://example.com/photo.jpg',
  String? deviceToken = 'fcm_token_abc',
  bool isAnonymous = false,
  String createdAt = '2026-01-15T09:00:00.000Z',
  String updatedAt = '2026-03-20T14:30:00.000Z',
}) {
  return {
    'id': id,
    'email': email,
    'display_name': displayName,
    'photo_url': photoUrl,
    'device_token': deviceToken,
    'is_anonymous': isAnonymous,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };
}

Map<String, dynamic> _buildAnonymousUserJson() {
  return _buildUserJson(
    id: 'anon_001',
    email: null,
    displayName: null,
    photoUrl: null,
    deviceToken: null,
    isAnonymous: true,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('UserModel.fromJson', () {
    test('parses complete JSON with all fields', () {
      final json = _buildUserJson();
      final model = UserModel.fromJson(json);

      expect(model.id, 'uid_001');
      expect(model.email, 'ibrahim@example.com');
      expect(model.displayName, 'Ibrahim Samad');
      expect(model.photoUrl, 'https://example.com/photo.jpg');
      expect(model.deviceToken, 'fcm_token_abc');
      expect(model.isAnonymous, isFalse);
      expect(model.createdAt, DateTime.utc(2026, 1, 15, 9, 0));
      expect(model.updatedAt, DateTime.utc(2026, 3, 20, 14, 30));
    });

    test('parses anonymous user with null optional fields', () {
      final json = _buildAnonymousUserJson();
      final model = UserModel.fromJson(json);

      expect(model.id, 'anon_001');
      expect(model.email, isNull);
      expect(model.displayName, isNull);
      expect(model.photoUrl, isNull);
      expect(model.deviceToken, isNull);
      expect(model.isAnonymous, isTrue);
    });

    test('defaults isAnonymous to false when missing', () {
      final json = _buildUserJson();
      json.remove('is_anonymous');
      final model = UserModel.fromJson(json);
      expect(model.isAnonymous, isFalse);
    });
  });

  group('UserModel.toJson', () {
    test('serializes all fields', () {
      final json = _buildUserJson();
      final model = UserModel.fromJson(json);
      final output = model.toJson();

      expect(output['id'], 'uid_001');
      expect(output['email'], 'ibrahim@example.com');
      expect(output['display_name'], 'Ibrahim Samad');
      expect(output['photo_url'], 'https://example.com/photo.jpg');
      expect(output['device_token'], 'fcm_token_abc');
      expect(output['is_anonymous'], isFalse);
      expect(output['created_at'], isA<String>());
      expect(output['updated_at'], isA<String>());
    });

    test('round-trip fromJson(toJson(model)) preserves data', () {
      final original = UserModel.fromJson(_buildUserJson());
      final roundTripped = UserModel.fromJson(original.toJson());

      expect(roundTripped.id, original.id);
      expect(roundTripped.email, original.email);
      expect(roundTripped.displayName, original.displayName);
      expect(roundTripped.photoUrl, original.photoUrl);
      expect(roundTripped.deviceToken, original.deviceToken);
      expect(roundTripped.isAnonymous, original.isAnonymous);
      expect(roundTripped.createdAt, original.createdAt);
      expect(roundTripped.updatedAt, original.updatedAt);
    });

    test('round-trip preserves null optional fields', () {
      final original = UserModel.fromJson(_buildAnonymousUserJson());
      final roundTripped = UserModel.fromJson(original.toJson());

      expect(roundTripped.email, isNull);
      expect(roundTripped.displayName, isNull);
      expect(roundTripped.photoUrl, isNull);
      expect(roundTripped.deviceToken, isNull);
      expect(roundTripped.isAnonymous, isTrue);
    });
  });

  group('UserModel.copyWith', () {
    test('creates new instance with changed displayName', () {
      final original = UserModel.fromJson(_buildUserJson());
      final copied = original.copyWith(displayName: 'New Name');

      expect(copied.displayName, 'New Name');
      // Unchanged fields
      expect(copied.id, original.id);
      expect(copied.email, original.email);
      expect(copied.photoUrl, original.photoUrl);
      expect(copied.isAnonymous, original.isAnonymous);
      expect(copied.createdAt, original.createdAt);
    });

    test('creates new instance with changed photoUrl', () {
      final original = UserModel.fromJson(_buildUserJson());
      final copied = original.copyWith(photoUrl: 'https://example.com/new.jpg');

      expect(copied.photoUrl, 'https://example.com/new.jpg');
      expect(copied.displayName, original.displayName);
    });

    test('creates new instance with changed deviceToken', () {
      final original = UserModel.fromJson(_buildUserJson());
      final copied = original.copyWith(deviceToken: 'new_fcm_token');

      expect(copied.deviceToken, 'new_fcm_token');
      expect(copied.id, original.id);
    });

    test('preserves fields not specified in copyWith', () {
      final original = UserModel.fromJson(_buildUserJson());
      final copied = original.copyWith(displayName: 'Changed');

      expect(copied.email, original.email);
      expect(copied.photoUrl, original.photoUrl);
      expect(copied.deviceToken, original.deviceToken);
      expect(copied.isAnonymous, original.isAnonymous);
      expect(copied.createdAt, original.createdAt);
    });

    test('updates updatedAt timestamp', () {
      final original = UserModel.fromJson(_buildUserJson());
      final beforeCopy = DateTime.now();
      final copied = original.copyWith(displayName: 'Updated');

      // updatedAt should be at or after the time we called copyWith
      expect(
        copied.updatedAt.millisecondsSinceEpoch,
        greaterThanOrEqualTo(beforeCopy.millisecondsSinceEpoch),
      );
    });
  });

  group('UserModel anonymous flag', () {
    test('anonymous user has isAnonymous true', () {
      final model = UserModel.fromJson(_buildAnonymousUserJson());
      expect(model.isAnonymous, isTrue);
    });

    test('regular user has isAnonymous false', () {
      final model = UserModel.fromJson(_buildUserJson());
      expect(model.isAnonymous, isFalse);
    });
  });

  group('UserModel Equatable', () {
    test('two models with same id, email, displayName, isAnonymous are equal', () {
      final a = UserModel.fromJson(_buildUserJson());
      final jsonB = _buildUserJson(deviceToken: 'different_token');
      final b = UserModel.fromJson(jsonB);
      expect(a, equals(b));
    });

    test('two models with different ids are not equal', () {
      final a = UserModel.fromJson(_buildUserJson(id: 'uid_001'));
      final b = UserModel.fromJson(_buildUserJson(id: 'uid_002'));
      expect(a, isNot(equals(b)));
    });
  });
}
