import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/local/cache_service.dart';
import '../../data/datasources/remote/api_service.dart';
import '../../data/datasources/remote/supabase_service.dart';
import '../../data/models/medicine_model.dart';
import '../../data/repositories/medicine_repository.dart';

final medicineRepositoryProvider = Provider<MedicineRepository>((ref) => MedicineRepository(
  api: ApiService(),
  supabase: SupabaseService(),
  cache: CacheService(),
));

final medicineSearchProvider = FutureProvider.family<List<MedicineModel>, String>((ref, query) async {
  if (query.isEmpty) return [];
  final repo = ref.watch(medicineRepositoryProvider);
  return repo.search(query);
});
