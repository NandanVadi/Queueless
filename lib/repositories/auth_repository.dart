import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../services/notification_service.dart';

class AuthRepository {
  final ApiService apiService;
  static const String _tokenKey = 'queueless_auth_token';

  AuthRepository(this.apiService);

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token != null) {
      ApiService.authToken = token;
      SocketService.instance.connect();
    }
  }

  Future<User> register(String name, String email, String password) async {
    final response = await apiService.register(name, email, password);
    final token = response['token'] as String;
    final userJson = response['user'] as Map<String, dynamic>;
    
    await _persistToken(token);
    
    return User.fromJson(userJson);
  }

  Future<User> login(String email, String password) async {
    final response = await apiService.login(email, password);
    final token = response['token'] as String;
    final userJson = response['user'] as Map<String, dynamic>;
    
    await _persistToken(token);
    
    return User.fromJson(userJson);
  }

  Future<void> logout() async {
    ApiService.authToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    SocketService.instance.disconnect();
    NotificationService.instance.clearState();
  }

  Future<User?> getCurrentUser() async {
    if (ApiService.authToken == null) return null;
    try {
      return await apiService.getCurrentUser();
    } catch (e) {
      // If unauthorized or network failure, we might want to handle it.
      // For now, if unauthorized, log them out.
      if (e is ApiException && e.message == 'Unauthorized') {
        await logout();
      }
      return null;
    }
  }

  Future<User> updateProfile(String name) async {
    return await apiService.updateProfile(name);
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    await apiService.changePassword(currentPassword, newPassword);
  }

  bool get isAuthenticated => ApiService.authToken != null;

  Future<void> _persistToken(String token) async {
    ApiService.authToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    SocketService.instance.connect();
  }
}
