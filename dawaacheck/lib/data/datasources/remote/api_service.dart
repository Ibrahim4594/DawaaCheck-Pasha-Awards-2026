import 'dart:convert';
import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/errors/app_exceptions.dart';

/// API service for backend communication (FastAPI endpoints).
/// For direct Supabase queries, use SupabaseService instead.
class ApiService {
  late final Dio _dio;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout:
          const Duration(milliseconds: ApiConstants.connectTimeout),
      receiveTimeout:
          const Duration(milliseconds: ApiConstants.receiveTimeout),
      headers: {'Content-Type': 'application/json'},
    ));
  }

  // -----------------------------------------------------------------------
  // Scan & Verify (SSE streaming)
  // -----------------------------------------------------------------------

  Stream<Map<String, dynamic>> scanVerify({
    required String frontImage,
    required String backImage,
    required String ingredientsImage,
    required String userId,
    String patientType = 'adult',
    int? childAge,
    double? childWeight,
    double? latitude,
    double? longitude,
    List<String>? currentMedicines,
  }) async* {
    try {
      final response = await _dio.post(
        ApiConstants.scanVerify,
        data: {
          'front_image': frontImage,
          'back_image': backImage,
          'ingredients_image': ingredientsImage,
          'user_id': userId,
          'patient_type': patientType,
          'child_age': childAge,
          'child_weight': childWeight,
          'latitude': latitude,
          'longitude': longitude,
          'current_medicines': currentMedicines,
        },
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout:
              const Duration(milliseconds: ApiConstants.scanTimeout),
        ),
      );

      final stream = response.data.stream as Stream<List<int>>;
      String buffer = '';
      // SSE frames arrive as an `event:` line followed by a `data:` line. The
      // event name carries the routing information (agent_update vs verdict vs
      // error), so it is tracked here and attached to the decoded payload
      // under `_event` for the caller to switch on.
      String? pendingEvent;

      await for (final chunk in stream) {
        buffer += utf8.decode(chunk);
        final lines = buffer.split('\n');
        buffer = lines.removeLast();

        for (final line in lines) {
          if (line.startsWith('event: ')) {
            pendingEvent = line.substring(7).trim();
          } else if (line.startsWith('data: ')) {
            final data = line.substring(6).trim();
            if (data.isNotEmpty && data != '[DONE]') {
              final decoded = json.decode(data) as Map<String, dynamic>;
              yield {...decoded, '_event': pendingEvent ?? 'message'};
            }
            pendingEvent = null;
          }
        }
      }
    } on DioException catch (e) {
      throw NetworkException(
        e.message ?? 'Network error occurred',
        originalError: e,
      );
    }
  }

  /// Non-streaming scan — sends images and waits for full JSON result.
  /// Works on all platforms including web.
  Future<Map<String, dynamic>> scanVerifyJson({
    required String frontImage,
    required String backImage,
    required String ingredientsImage,
    required String userId,
    String patientType = 'adult',
    int? childAge,
    double? childWeight,
    List<String>? currentMedicines,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.scanVerifyJson,
        data: {
          'front_image': frontImage,
          'back_image': backImage,
          'ingredients_image': ingredientsImage,
          'user_id': userId,
          'patient_type': patientType,
          'child_age': childAge,
          'child_weight': childWeight,
          'current_medicines': currentMedicines,
        },
        options: Options(
          receiveTimeout:
              const Duration(milliseconds: ApiConstants.scanTimeout),
        ),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw NetworkException(
        e.message ?? 'Scan failed',
        originalError: e,
      );
    }
  }

  // -----------------------------------------------------------------------
  // Medicines
  // -----------------------------------------------------------------------

  Future<Map<String, dynamic>> searchMedicines(
    String query, {
    int page = 1,
    int pageSize = 20,
    String? category,
  }) async {
    try {
      final params = <String, dynamic>{
        'q': query,
        'page': page,
        'page_size': pageSize,
      };
      if (category != null) params['category'] = category;

      final response = await _dio.get(
        ApiConstants.medicineSearch,
        queryParameters: params,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw NetworkException(e.message ?? 'Search failed', originalError: e);
    }
  }

  Future<Map<String, dynamic>> getMedicineDetail(
    String registrationNumber,
  ) async {
    try {
      final response = await _dio.get(
        '${ApiConstants.medicineDetail}/$registrationNumber',
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw NetworkException(
        e.message ?? 'Failed to get details',
        originalError: e,
      );
    }
  }

  Future<Map<String, dynamic>> getDrugInteractions(String drugName) async {
    try {
      final response = await _dio.get(
        ApiConstants.medicineInteractions,
        queryParameters: {'drug': drugName},
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw NetworkException(
        e.message ?? 'Failed to check interactions',
        originalError: e,
      );
    }
  }

  Future<Map<String, dynamic>> checkInteractionPair(
    String drugA,
    String drugB,
  ) async {
    try {
      final response = await _dio.get(
        ApiConstants.medicineInteractionPair,
        queryParameters: {'drug_a': drugA, 'drug_b': drugB},
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw NetworkException(
        e.message ?? 'Failed to check interaction pair',
        originalError: e,
      );
    }
  }

  Future<Map<String, dynamic>> getSideEffects(String drugName) async {
    try {
      final response = await _dio.get(
        '${ApiConstants.medicineSideEffects}/$drugName',
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw NetworkException(
        e.message ?? 'Failed to get side effects',
        originalError: e,
      );
    }
  }

  Future<Map<String, dynamic>> getGenericAlternatives(
    String brandName,
  ) async {
    try {
      final response = await _dio.get(
        '${ApiConstants.medicineAlternatives}/$brandName',
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw NetworkException(
        e.message ?? 'Failed to get alternatives',
        originalError: e,
      );
    }
  }

  Future<Map<String, dynamic>> getDatabaseStats() async {
    try {
      final response = await _dio.get(ApiConstants.medicineStats);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw NetworkException(
        e.message ?? 'Failed to get stats',
        originalError: e,
      );
    }
  }

  // -----------------------------------------------------------------------
  // Recalls
  // -----------------------------------------------------------------------

  Future<Map<String, dynamic>> getRecalls({
    int page = 1,
    int pageSize = 20,
    String? search,
  }) async {
    try {
      final params = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      };
      if (search != null) params['search'] = search;

      final response = await _dio.get(
        ApiConstants.recalls,
        queryParameters: params,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw NetworkException(
        e.message ?? 'Failed to fetch recalls',
        originalError: e,
      );
    }
  }

  Future<Map<String, dynamic>> checkRecallStatus(String medicineName) async {
    try {
      final response = await _dio.get(
        '${ApiConstants.recallCheck}/$medicineName',
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw NetworkException(
        e.message ?? 'Failed to check recall',
        originalError: e,
      );
    }
  }

  // -----------------------------------------------------------------------
  // ADR Reports
  // -----------------------------------------------------------------------

  Future<Map<String, dynamic>> submitAdrReport(
    Map<String, dynamic> report,
  ) async {
    try {
      final response = await _dio.post(ApiConstants.adrReport, data: report);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw NetworkException(
        e.message ?? 'Failed to submit report',
        originalError: e,
      );
    }
  }
}
