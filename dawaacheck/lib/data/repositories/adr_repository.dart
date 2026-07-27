import '../datasources/remote/api_service.dart';
import '../datasources/remote/supabase_service.dart';
import '../models/adr_report_model.dart';

/// Repository for ADR (Adverse Drug Reaction) reports
class AdrRepository {
  final ApiService _api = ApiService();
  final SupabaseService _supabase = SupabaseService();

  Future<void> submitReport(AdrReportModel report) async {
    // Save to Supabase
    await _supabase.submitAdrReport(report);
    // Also send to backend for Agent 9 processing
    await _api.submitAdrReport(report.toJson());
  }
}
