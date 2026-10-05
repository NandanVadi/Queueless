import '../database/database_helper.dart';
import '../models/queue_token.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../services/notification_service.dart';

class QueueRepository {
  final ApiService _apiService;
  final DatabaseHelper _databaseHelper;

  QueueRepository({ApiService? apiService, DatabaseHelper? databaseHelper})
    : _apiService = apiService ?? ApiService(),
      _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  /// Creates a new queue token via API and synchronizes it to local SQLite.
  /// If the API fails, it propagates the error rather than creating a fake local token.
  Future<QueueToken> createQueueToken(int serviceId) async {
    try {
      // 1. Create authoritative token on the backend
      final token = await _apiService.createQueueToken(serviceId);

      // 2. Synchronize to local SQLite cache
      await _databaseHelper.synchronizeQueueToken(token);

      return token;
    } catch (e) {
      // Propagate the error. We do not invent authoritative tokens locally.
      rethrow;
    }
  }

  /// Fetches active queue tokens. Tries API first, falls back to SQLite on failure.
  Future<List<QueueToken>> getActiveQueueTokens() async {
    late List<QueueToken> tokens;
    try {
      tokens = await _apiService.getActiveQueueTokens();
    } catch (e) {
      // Only a failed API request may use the last known cache.
      return _databaseHelper.getActiveQueueTokens();
    }

    // Cache failures must not be mistaken for network failures or silently
    // return stale data after the server has responded successfully.
    await _databaseHelper.synchronizeActiveQueueTokens(tokens);
    
    // Evaluate authoritative state for notifications
    NotificationService.instance.processTokens(tokens);

    // Join socket rooms for active queue tokens
    for (final token in tokens) {
      SocketService.instance.joinServiceRoom(token.serviceId);
    }
    
    return tokens;
  }

  /// Fetches a single queue token by ID. Tries API first, falls back to SQLite.
  Future<QueueToken?> getQueueTokenById(int id) async {
    late QueueToken token;
    try {
      token = await _apiService.getQueueTokenById(id);
    } catch (e) {
      return _databaseHelper.getQueueTokenById(id);
    }
    await _databaseHelper.synchronizeQueueToken(token);
    return token;
  }

  /// Cancels a queue token via API and updates the local SQLite cache.
  Future<QueueToken> cancelQueueToken(int id) async {
    try {
      // 1. Cancel on the backend
      final token = await _apiService.cancelQueueToken(id);

      // 2. Synchronize cancellation to local SQLite cache
      await _databaseHelper.synchronizeQueueToken(token);
      
      // Leave socket room since we cancelled
      SocketService.instance.leaveServiceRoom(token.serviceId);

      return token;
    } catch (e) {
      // Propagate the error. We must ensure the backend acknowledges the cancellation.
      rethrow;
    }
  }
}
