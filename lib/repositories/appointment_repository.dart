import '../models/appointment.dart';
import '../services/api_service.dart';
import '../database/database_helper.dart';

/// Repository for managing Appointments.
/// Coordinates between the remote ApiService and local SQLite DatabaseHelper.
class AppointmentRepository {
  final ApiService _apiService;
  final DatabaseHelper _dbHelper;

  AppointmentRepository({ApiService? apiService, DatabaseHelper? dbHelper})
    : _apiService = apiService ?? ApiService(),
      _dbHelper = dbHelper ?? DatabaseHelper.instance;

  /// Creates an appointment via the API, then synchronizes it to SQLite.
  Future<Appointment> createAppointment(Appointment appointment) async {
    // 1. Remote-First: Send to backend
    final remoteAppointment = await _apiService.createAppointment(appointment);

    // 2. Sync to local database
    await _dbHelper.synchronizeAppointment(remoteAppointment);

    return remoteAppointment;
  }

  /// Retrieves all appointments. Falls back to SQLite if API fails.
  Future<List<Appointment>> getAppointments() async {
    late List<Appointment> remoteAppointments;
    try {
      remoteAppointments = await _apiService.getAppointments();
    } catch (e) {
      // Only an unreachable/failed API may use the last known cache.
      return _dbHelper.getAppointments();
    }

    await _dbHelper.synchronizeAppointments(remoteAppointments);
    return remoteAppointments;
  }

  /// Retrieves an appointment by ID. Falls back to SQLite if API fails.
  Future<Appointment?> getAppointmentById(int id) async {
    late Appointment remoteAppointment;
    try {
      remoteAppointment = await _apiService.getAppointmentById(id);
    } catch (e) {
      return _dbHelper.getAppointmentById(id);
    }
    await _dbHelper.synchronizeAppointment(remoteAppointment);
    return remoteAppointment;
  }

  /// Cancels an appointment via the API, then updates SQLite.
  Future<Appointment> cancelAppointment(int id) async {
    // 1. Remote-First: Cancel on backend
    final cancelledAppointment = await _apiService.cancelAppointment(id);

    // 2. Sync updated status to local database
    await _dbHelper.synchronizeAppointment(cancelledAppointment);

    return cancelledAppointment;
  }
}
