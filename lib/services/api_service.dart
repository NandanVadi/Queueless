import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/service.dart';
import '../models/queue_token.dart';
import '../models/appointment.dart';
import '../models/user.dart';
import '../models/dashboard.dart';
import '../utils/api_config.dart';

class ApiService {
  static http.Client? globalTestClient;
  final http.Client client;
  static String? authToken;

  ApiService({http.Client? client}) : client = client ?? globalTestClient ?? http.Client();

  Map<String, String> _getHeaders() {
    final headers = {'Content-Type': 'application/json'};
    if (authToken != null) {
      headers['Authorization'] = 'Bearer $authToken';
    }
    return headers;
  }

  /// Fetches the list of services from the backend API.
  Future<List<Service>> getServices() async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/services');
      final response = await client.get(url, headers: _getHeaders());

      if (response.statusCode == 200) {
        final Map<String, dynamic> decodedJson = jsonDecode(response.body);
        
        if (!decodedJson.containsKey('services') || decodedJson['services'] is! List) {
          throw const FormatException('Expected JSON to contain a "services" list');
        }

        final List<dynamic> servicesList = decodedJson['services'];
        
        return servicesList.map((item) {
          if (item is! Map<String, dynamic>) {
            throw const FormatException('Expected JSON object for Service');
          }
          if (!item.containsKey('name') || !item.containsKey('description') || !item.containsKey('icon')) {
            throw const FormatException('Missing required Service fields');
          }
          return Service.fromJson(item);
        }).toList();
      } else {
        throw HttpException('Failed to load services: ${response.statusCode}');
      }
    } on FormatException catch (e) {
      throw ApiException('Data format error: ${e.message}');
    } on http.ClientException catch (e) {
      throw NetworkException('Network error occurred: ${e.message}');
    } catch (e) {
      if (e is ApiException || e is HttpException || e is NetworkException) {
        rethrow;
      }
      throw ApiException('An unexpected error occurred: $e');
    }
  }

  // ── Admin Service API ────────────────────────────────────────────────────────

  Future<List<Service>> getAllServicesForAdmin() async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/admin/services');
      final response = await client.get(url, headers: _getHeaders());

      if (response.statusCode == 200) {
        final Map<String, dynamic> decodedJson = jsonDecode(response.body);
        if (!decodedJson.containsKey('services') || decodedJson['services'] is! List) {
          throw const FormatException('Expected JSON to contain a "services" list');
        }
        final List<dynamic> servicesList = decodedJson['services'];
        return servicesList.map((item) => Service.fromJson(item)).toList();
      } else if (response.statusCode == 403) {
        throw ApiException('Forbidden: Admin access required');
      } else {
        throw HttpException('Failed to load admin services: ${response.statusCode}');
      }
    } on FormatException catch (e) {
      throw ApiException('Data format error: ${e.message}');
    } on http.ClientException catch (e) {
      throw NetworkException('Network error occurred: ${e.message}');
    } catch (e) {
      if (e is ApiException || e is HttpException || e is NetworkException) rethrow;
      throw ApiException('An unexpected error occurred: $e');
    }
  }

  Future<Service> createService(Service service) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/admin/services');
      final response = await client.post(
        url,
        headers: _getHeaders(),
        body: jsonEncode(service.toJson()),
      );

      if (response.statusCode == 201) {
        final Map<String, dynamic> decodedJson = jsonDecode(response.body);
        if (!decodedJson.containsKey('service')) {
          throw const FormatException('Expected JSON to contain "service"');
        }
        return Service.fromJson(decodedJson['service']);
      } else if (response.statusCode == 403) {
        throw ApiException('Forbidden: Admin access required');
      } else {
        throw HttpException('Failed to create service: ${response.statusCode}');
      }
    } on FormatException catch (e) {
      throw ApiException('Data format error: ${e.message}');
    } on http.ClientException catch (e) {
      throw NetworkException('Network error occurred: ${e.message}');
    } catch (e) {
      if (e is ApiException || e is HttpException || e is NetworkException) rethrow;
      throw ApiException('An unexpected error occurred: $e');
    }
  }

  Future<Service> updateService(int id, Service service) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/admin/services/$id');
      final response = await client.patch(
        url,
        headers: _getHeaders(),
        body: jsonEncode(service.toJson()),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> decodedJson = jsonDecode(response.body);
        if (!decodedJson.containsKey('service')) {
          throw const FormatException('Expected JSON to contain "service"');
        }
        return Service.fromJson(decodedJson['service']);
      } else if (response.statusCode == 403) {
        throw ApiException('Forbidden: Admin access required');
      } else {
        throw HttpException('Failed to update service: ${response.statusCode}');
      }
    } on FormatException catch (e) {
      throw ApiException('Data format error: ${e.message}');
    } on http.ClientException catch (e) {
      throw NetworkException('Network error occurred: ${e.message}');
    } catch (e) {
      if (e is ApiException || e is HttpException || e is NetworkException) rethrow;
      throw ApiException('An unexpected error occurred: $e');
    }
  }

  Future<Service> setServiceActive(int id, bool isActive) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/admin/services/$id/status');
      final response = await client.patch(
        url,
        headers: _getHeaders(),
        body: jsonEncode({'isActive': isActive}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> decodedJson = jsonDecode(response.body);
        if (!decodedJson.containsKey('service')) {
          throw const FormatException('Expected JSON to contain "service"');
        }
        return Service.fromJson(decodedJson['service']);
      } else if (response.statusCode == 403) {
        throw ApiException('Forbidden: Admin access required');
      } else {
        throw HttpException('Failed to update service status: ${response.statusCode}');
      }
    } on FormatException catch (e) {
      throw ApiException('Data format error: ${e.message}');
    } on http.ClientException catch (e) {
      throw NetworkException('Network error occurred: ${e.message}');
    } catch (e) {
      if (e is ApiException || e is HttpException || e is NetworkException) rethrow;
      throw ApiException('An unexpected error occurred: $e');
    }
  }

  // ── Queue Token API ─────────────────────────────────────────────────────────

  /// Creates a queue token for the given [serviceId].
  Future<QueueToken> createQueueToken(int serviceId) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/queue');
      final response = await client.post(
        url,
        headers: _getHeaders(),
        body: jsonEncode({'serviceId': serviceId}),
      );

      if (response.statusCode == 201) {
        final Map<String, dynamic> decodedJson = jsonDecode(response.body);
        if (!decodedJson.containsKey('queueToken')) {
          throw const FormatException('Expected JSON to contain "queueToken"');
        }
        return QueueToken.fromJson(decodedJson['queueToken']);
      } else {
        throw HttpException('Failed to create queue token: ${response.statusCode}');
      }
    } on FormatException catch (e) {
      throw ApiException('Data format error: ${e.message}');
    } on http.ClientException catch (e) {
      throw NetworkException('Network error occurred: ${e.message}');
    } catch (e) {
      if (e is ApiException || e is HttpException || e is NetworkException) {
        rethrow;
      }
      throw ApiException('An unexpected error occurred: $e');
    }
  }

  /// Fetches all active queue tokens.
  Future<List<QueueToken>> getActiveQueueTokens() async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/queue/active');
      final response = await client.get(url, headers: _getHeaders());

      if (response.statusCode == 200) {
        final Map<String, dynamic> decodedJson = jsonDecode(response.body);
        if (!decodedJson.containsKey('queueTokens') || decodedJson['queueTokens'] is! List) {
          throw const FormatException('Expected JSON to contain a "queueTokens" list');
        }
        final List<dynamic> list = decodedJson['queueTokens'];
        return list.map((item) {
          if (item is! Map<String, dynamic>) {
            throw const FormatException('Expected JSON object for QueueToken');
          }
          return QueueToken.fromJson(item);
        }).toList();
      } else {
        throw HttpException('Failed to load active queue tokens: ${response.statusCode}');
      }
    } on FormatException catch (e) {
      throw ApiException('Data format error: ${e.message}');
    } on http.ClientException catch (e) {
      throw NetworkException('Network error occurred: ${e.message}');
    } catch (e) {
      if (e is ApiException || e is HttpException || e is NetworkException) {
        rethrow;
      }
      throw ApiException('An unexpected error occurred: $e');
    }
  }

  /// Fetches a specific queue token by [id].
  Future<QueueToken> getQueueTokenById(int id) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/queue/$id');
      final response = await client.get(url, headers: _getHeaders());

      if (response.statusCode == 200) {
        final Map<String, dynamic> decodedJson = jsonDecode(response.body);
        if (!decodedJson.containsKey('queueToken')) {
          throw const FormatException('Expected JSON to contain "queueToken"');
        }
        return QueueToken.fromJson(decodedJson['queueToken']);
      } else if (response.statusCode == 404) {
        throw ApiException('Queue token not found');
      } else {
        throw HttpException('Failed to fetch queue token: ${response.statusCode}');
      }
    } on FormatException catch (e) {
      throw ApiException('Data format error: ${e.message}');
    } on http.ClientException catch (e) {
      throw NetworkException('Network error occurred: ${e.message}');
    } catch (e) {
      if (e is ApiException || e is HttpException || e is NetworkException) {
        rethrow;
      }
      throw ApiException('An unexpected error occurred: $e');
    }
  }

  /// Cancels an existing queue token by [id].
  Future<QueueToken> cancelQueueToken(int id) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/queue/$id/cancel');
      final response = await client.patch(url, headers: _getHeaders());

      if (response.statusCode == 200) {
        final Map<String, dynamic> decodedJson = jsonDecode(response.body);
        if (!decodedJson.containsKey('queueToken')) {
          throw const FormatException('Expected JSON to contain "queueToken"');
        }
        return QueueToken.fromJson(decodedJson['queueToken']);
      } else if (response.statusCode == 404) {
        throw ApiException('Queue token not found');
      } else {
        throw HttpException('Failed to cancel queue token: ${response.statusCode}');
      }
    } on FormatException catch (e) {
      throw ApiException('Data format error: ${e.message}');
    } on http.ClientException catch (e) {
      throw NetworkException('Network error occurred: ${e.message}');
    } catch (e) {
      if (e is ApiException || e is HttpException || e is NetworkException) {
        rethrow;
      }
      throw ApiException('An unexpected error occurred: $e');
    }
  }

  // ── Operator API ─────────────────────────────────────────────────────────

  /// Retrieves the entire queue for a specific service (Operator View)
  Future<List<QueueToken>> getServiceQueue(int serviceId) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/operator/queue/$serviceId');
      final response = await client.get(url, headers: _getHeaders());

      if (response.statusCode == 200) {
        final Map<String, dynamic> decodedJson = jsonDecode(response.body);
        if (!decodedJson.containsKey('queueTokens') || decodedJson['queueTokens'] is! List) {
          throw const FormatException('Expected JSON to contain a "queueTokens" list');
        }
        final List<dynamic> list = decodedJson['queueTokens'];
        return list.map((item) {
          if (item is! Map<String, dynamic>) {
            throw const FormatException('Expected JSON object for QueueToken');
          }
          return QueueToken.fromJson(item);
        }).toList();
      } else if (response.statusCode == 403) {
        throw ApiException('Forbidden: Operator access required');
      } else {
        throw HttpException('Failed to load service queue: ${response.statusCode}');
      }
    } on FormatException catch (e) {
      throw ApiException('Data format error: ${e.message}');
    } on http.ClientException catch (e) {
      throw NetworkException('Network error occurred: ${e.message}');
    } catch (e) {
      if (e is ApiException || e is HttpException || e is NetworkException) {
        rethrow;
      }
      throw ApiException('An unexpected error occurred: $e');
    }
  }

  /// Calls the next token for a service
  Future<QueueToken> callNextToken(int serviceId) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/operator/queue/$serviceId/next');
      final response = await client.post(url, headers: _getHeaders());

      if (response.statusCode == 200) {
        final Map<String, dynamic> decodedJson = jsonDecode(response.body);
        if (!decodedJson.containsKey('queueToken')) {
          throw const FormatException('Expected JSON to contain "queueToken"');
        }
        return QueueToken.fromJson(decodedJson['queueToken']);
      } else if (response.statusCode == 404) {
        throw ApiException('Queue is empty');
      } else if (response.statusCode == 409) {
        throw ApiException('A token is already being served');
      } else if (response.statusCode == 403) {
        throw ApiException('Forbidden: Operator access required');
      } else {
        throw HttpException('Failed to call next token: ${response.statusCode}');
      }
    } on FormatException catch (e) {
      throw ApiException('Data format error: ${e.message}');
    } on http.ClientException catch (e) {
      throw NetworkException('Network error occurred: ${e.message}');
    } catch (e) {
      if (e is ApiException || e is HttpException || e is NetworkException) {
        rethrow;
      }
      throw ApiException('An unexpected error occurred: $e');
    }
  }

  /// Completes a currently serving token
  Future<QueueToken> completeToken(int id) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/operator/queue/$id/complete');
      final response = await client.post(url, headers: _getHeaders());

      if (response.statusCode == 200) {
        final Map<String, dynamic> decodedJson = jsonDecode(response.body);
        if (!decodedJson.containsKey('queueToken')) {
          throw const FormatException('Expected JSON to contain "queueToken"');
        }
        return QueueToken.fromJson(decodedJson['queueToken']);
      } else if (response.statusCode == 404) {
        throw ApiException('Queue token not found');
      } else if (response.statusCode == 409) {
        throw ApiException('Only serving tokens can be completed');
      } else if (response.statusCode == 403) {
        throw ApiException('Forbidden: Operator access required');
      } else {
        throw HttpException('Failed to complete token: ${response.statusCode}');
      }
    } on FormatException catch (e) {
      throw ApiException('Data format error: ${e.message}');
    } on http.ClientException catch (e) {
      throw NetworkException('Network error occurred: ${e.message}');
    } catch (e) {
      if (e is ApiException || e is HttpException || e is NetworkException) {
        rethrow;
      }
      throw ApiException('An unexpected error occurred: $e');
    }
  }

  // ── Appointments API ────────────────────────────────────────────────────────

  /// Creates a new appointment on the backend.
  Future<Appointment> createAppointment(Appointment appointment) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/appointments');
      final response = await client.post(
        url,
        headers: _getHeaders(),
        body: jsonEncode(appointment.toJson()),
      );

      if (response.statusCode == 201) {
        final Map<String, dynamic> decodedJson = jsonDecode(response.body);
        if (!decodedJson.containsKey('appointment')) {
          throw const FormatException('Expected JSON to contain "appointment"');
        }
        return Appointment.fromJson(decodedJson['appointment']);
      } else if (response.statusCode == 409) {
        throw ApiException('This time slot is already booked for the selected service.');
      } else {
        throw HttpException('Failed to create appointment: ${response.statusCode}');
      }
    } on FormatException catch (e) {
      throw ApiException('Data format error: ${e.message}');
    } on http.ClientException catch (e) {
      throw NetworkException('Network error occurred: ${e.message}');
    } catch (e) {
      if (e is ApiException || e is HttpException || e is NetworkException) {
        rethrow;
      }
      throw ApiException('An unexpected error occurred: $e');
    }
  }

  /// Retrieves all appointments from the backend.
  Future<List<Appointment>> getAppointments() async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/appointments');
      final response = await client.get(url, headers: _getHeaders());

      if (response.statusCode == 200) {
        final Map<String, dynamic> decodedJson = jsonDecode(response.body);
        if (!decodedJson.containsKey('appointments')) {
          throw const FormatException('Expected JSON to contain "appointments" array');
        }
        final List<dynamic> list = decodedJson['appointments'];
        return list.map((json) => Appointment.fromJson(json)).toList();
      } else {
        throw HttpException('Failed to load appointments: ${response.statusCode}');
      }
    } on FormatException catch (e) {
      throw ApiException('Data format error: ${e.message}');
    } on http.ClientException catch (e) {
      throw NetworkException('Network error occurred: ${e.message}');
    } catch (e) {
      if (e is ApiException || e is HttpException || e is NetworkException) {
        rethrow;
      }
      throw ApiException('An unexpected error occurred: $e');
    }
  }

  /// Retrieves an appointment by ID from the backend.
  Future<Appointment> getAppointmentById(int id) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/appointments/$id');
      final response = await client.get(url, headers: _getHeaders());

      if (response.statusCode == 200) {
        final Map<String, dynamic> decodedJson = jsonDecode(response.body);
        if (!decodedJson.containsKey('appointment')) {
          throw const FormatException('Expected JSON to contain "appointment"');
        }
        return Appointment.fromJson(decodedJson['appointment']);
      } else if (response.statusCode == 404) {
        throw ApiException('Appointment not found');
      } else {
        throw HttpException('Failed to load appointment: ${response.statusCode}');
      }
    } on FormatException catch (e) {
      throw ApiException('Data format error: ${e.message}');
    } on http.ClientException catch (e) {
      throw NetworkException('Network error occurred: ${e.message}');
    } catch (e) {
      if (e is ApiException || e is HttpException || e is NetworkException) {
        rethrow;
      }
      throw ApiException('An unexpected error occurred: $e');
    }
  }

  /// Cancels an appointment by its ID.
  Future<Appointment> cancelAppointment(int id) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/appointments/$id/cancel');
      final response = await client.patch(url, headers: _getHeaders());

      if (response.statusCode == 200) {
        final Map<String, dynamic> decodedJson = jsonDecode(response.body);
        if (!decodedJson.containsKey('appointment')) {
          throw const FormatException('Expected JSON to contain "appointment"');
        }
        return Appointment.fromJson(decodedJson['appointment']);
      } else if (response.statusCode == 404) {
        throw ApiException('Appointment not found');
      } else {
        throw HttpException('Failed to cancel appointment: ${response.statusCode}');
      }
    } on FormatException catch (e) {
      throw ApiException('Data format error: ${e.message}');
    } on http.ClientException catch (e) {
      throw NetworkException('Network error occurred: ${e.message}');
    } catch (e) {
      if (e is ApiException || e is HttpException || e is NetworkException) {
        rethrow;
      }
      throw ApiException('An unexpected error occurred: $e');
    }
  }

  // ── Auth API ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> register(String name, String email, String password) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/auth/register');
      final response = await client.post(
        url,
        headers: _getHeaders(),
        body: jsonEncode({'name': name, 'email': email, 'password': password}),
      );

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final errorMsg = _extractError(response.body);
        throw ApiException(errorMsg ?? 'Failed to register: ${response.statusCode}');
      }
    } on http.ClientException catch (e) {
      throw NetworkException('Network error occurred: ${e.message}');
    } catch (e) {
      if (e is ApiException || e is NetworkException) rethrow;
      throw ApiException('An unexpected error occurred: $e');
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/auth/login');
      final response = await client.post(
        url,
        headers: _getHeaders(),
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final errorMsg = _extractError(response.body);
        throw ApiException(errorMsg ?? 'Failed to login: ${response.statusCode}');
      }
    } on http.ClientException catch (e) {
      throw NetworkException('Network error occurred: ${e.message}');
    } catch (e) {
      if (e is ApiException || e is NetworkException) rethrow;
      throw ApiException('An unexpected error occurred: $e');
    }
  }

  Future<User> getCurrentUser() async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/auth/me');
      final response = await client.get(url, headers: _getHeaders());

      if (response.statusCode == 200) {
        final Map<String, dynamic> decoded = jsonDecode(response.body);
        if (!decoded.containsKey('user')) {
          throw const FormatException('Expected JSON to contain "user"');
        }
        return User.fromJson(decoded['user']);
      } else if (response.statusCode == 401) {
        throw ApiException('Unauthorized');
      } else {
        throw HttpException('Failed to fetch user: ${response.statusCode}');
      }
    } on FormatException catch (e) {
      throw ApiException('Data format error: ${e.message}');
    } on http.ClientException catch (e) {
      throw NetworkException('Network error occurred: ${e.message}');
    } catch (e) {
      if (e is ApiException || e is HttpException || e is NetworkException) rethrow;
      throw ApiException('An unexpected error occurred: $e');
    }
  }

  Future<User> updateProfile(String name) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/auth/me');
      final response = await client.patch(
        url,
        headers: _getHeaders(),
        body: jsonEncode({'name': name}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> decoded = jsonDecode(response.body);
        if (!decoded.containsKey('user')) {
          throw const FormatException('Expected JSON to contain "user"');
        }
        return User.fromJson(decoded['user']);
      } else {
        final errorMsg = _extractError(response.body);
        throw ApiException(errorMsg ?? 'Failed to update profile: ${response.statusCode}');
      }
    } on FormatException catch (e) {
      throw ApiException('Data format error: ${e.message}');
    } on http.ClientException catch (e) {
      throw NetworkException('Network error occurred: ${e.message}');
    } catch (e) {
      if (e is ApiException || e is NetworkException) rethrow;
      throw ApiException('An unexpected error occurred: $e');
    }
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/auth/me/password');
      final response = await client.patch(
        url,
        headers: _getHeaders(),
        body: jsonEncode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      );

      if (response.statusCode != 200) {
        final errorMsg = _extractError(response.body);
        throw ApiException(errorMsg ?? 'Failed to change password: ${response.statusCode}');
      }
    } on http.ClientException catch (e) {
      throw NetworkException('Network error occurred: ${e.message}');
    } catch (e) {
      if (e is ApiException || e is NetworkException) rethrow;
      throw ApiException('An unexpected error occurred: $e');
    }
  }

  // ── Dashboard API ────────────────────────────────────────────────────────

  Future<DashboardData> getAdminDashboard() async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/admin/dashboard');
      final response = await client.get(url, headers: _getHeaders());

      if (response.statusCode == 200) {
        final Map<String, dynamic> decodedJson = jsonDecode(response.body);
        if (!decodedJson.containsKey('dashboard')) {
          throw const FormatException('Expected JSON to contain "dashboard"');
        }
        return DashboardData.fromJson(decodedJson['dashboard']);
      } else if (response.statusCode == 403) {
        throw ApiException('Forbidden: Admin access required');
      } else {
        throw HttpException('Failed to load dashboard data: ${response.statusCode}');
      }
    } on FormatException catch (e) {
      throw ApiException('Data format error: ${e.message}');
    } on http.ClientException catch (e) {
      throw NetworkException('Network error occurred: ${e.message}');
    } catch (e) {
      if (e is ApiException || e is HttpException || e is NetworkException) rethrow;
      throw ApiException('An unexpected error occurred: $e');
    }
  }

  String? _extractError(String body) {
    try {
      final map = jsonDecode(body);
      return map['error'];
    } catch (_) {
      return null;
    }
  }
}

// Custom exception classes for precise error handling
class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class HttpException implements Exception {
  final String message;
  HttpException(this.message);
  @override
  String toString() => message;
}

class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);
  @override
  String toString() => message;
}
