import '../models/service.dart';
import '../services/api_service.dart';
import '../database/database_helper.dart';

/// Repository for managing Service data.
/// 
/// Responsibilities:
/// - Acts as the single source of truth for the UI (HomeScreen).
/// - Fetches the latest service catalog from the backend via [ApiService].
/// - Synchronizes the fetched services into the local SQLite database via [DatabaseHelper].
/// - Falls back to the SQLite cache if the backend is unavailable or the network fails.
class ServiceRepository {
  final ApiService _apiService;
  final DatabaseHelper _dbHelper;

  ServiceRepository({
    ApiService? apiService,
    DatabaseHelper? dbHelper,
  })  : _apiService = apiService ?? ApiService(),
        _dbHelper = dbHelper ?? DatabaseHelper.instance;

  /// Retrieves the list of active services.
  /// 
  /// Flow:
  /// 1. Attempt to fetch from API.
  /// 2. If successful, upsert into SQLite. Return the fetched list.
  /// 3. If failed, catch the error, read from SQLite, and return cached list.
  /// 4. If API failed and SQLite is empty, returns an empty list.
  Future<List<Service>> getServices() async {
    try {
      // 1. Attempt to fetch from the backend
      final apiServices = await _apiService.getServices();

      // 2. Synchronize with SQLite cache
      for (final service in apiServices) {
        await _dbHelper.upsertService(service);
      }

      // Return the fresh data
      return _filterActive(apiServices);
    } catch (e) {
      // 3. Fallback: Network or API error occurred, load from local cache
      final cachedServices = await _dbHelper.getServices();
      return _filterActive(cachedServices);
    }
  }

  /// Filters out inactive services
  List<Service> _filterActive(List<Service> services) {
    return services.where((s) => s.isActive).toList();
  }

  // ── Admin Operations ────────────────────────────────────────────────────────

  /// Fetches all services (active and inactive) for admin view.
  Future<List<Service>> getAllServicesForAdmin() async {
    try {
      final apiServices = await _apiService.getAllServicesForAdmin();
      // Synchronize with local cache
      for (final service in apiServices) {
        await _dbHelper.upsertService(service);
      }
      return apiServices;
    } catch (e) {
      // Fallback to SQLite
      return _dbHelper.getServices();
    }
  }

  /// Creates a new service.
  Future<Service> createService(Service service) async {
    final createdService = await _apiService.createService(service);
    await _dbHelper.upsertService(createdService);
    return createdService;
  }

  /// Updates an existing service.
  Future<Service> updateService(int id, Service service) async {
    final updatedService = await _apiService.updateService(id, service);
    await _dbHelper.upsertService(updatedService);
    return updatedService;
  }

  /// Sets the active status of a service.
  Future<Service> setServiceActive(int id, bool isActive) async {
    final updatedService = await _apiService.setServiceActive(id, isActive);
    await _dbHelper.upsertService(updatedService);
    return updatedService;
  }
}
