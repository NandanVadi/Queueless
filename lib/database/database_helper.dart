import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/service.dart';
import '../models/queue_token.dart';
import '../models/appointment.dart';

/// Centralised SQLite database helper for QueueLess.
///
/// Architecture (Lab 8 pattern):
///   - Singleton: only one instance ever exists ([instance]).
///   - Lazy initialisation: the database is opened on first access via the
///     [database] getter, not at app startup.
///   - The rest of the application never calls [openDatabase] directly.
///
/// Database versioning:
///   - Version is defined in [_databaseVersion].
///   - [onCreate] runs when the database file does not yet exist.
///   - An [onUpgrade] hook is wired in for future schema migrations without
///     requiring a rewrite of this class.
class DatabaseHelper {
  // ── Singleton setup (Lab 8 pattern) ────────────────────────────────────────

  /// The single shared instance of [DatabaseHelper].
  static final DatabaseHelper instance = DatabaseHelper._internal();

  /// Private named constructor — prevents external instantiation.
  DatabaseHelper._internal();

  // ── Database configuration ──────────────────────────────────────────────────

  static const String _databaseName = 'queueless.db';

  /// Increment this when the schema changes.
  /// An [onUpgrade] callback must be added to [openDatabase] when bumping.
  static const int _databaseVersion = 2;

  // ── Table names ─────────────────────────────────────────────────────────────

  static const String tableServices = 'services';
  static const String tableQueueTokens = 'queue_tokens';
  static const String tableAppointments = 'appointments';

  // ── Internal state ──────────────────────────────────────────────────────────

  /// Cached open database connection. Null until first access.
  Database? _database;

  /// Override path used exclusively during tests.
  ///
  /// When non-null, [_initDatabase] uses this path instead of computing one
  /// via [getDatabasesPath]. Set this before the first [database] access in
  /// each test via [setDatabasePathForTesting].
  String? _testDatabasePath;

  // ── Test-only configuration ─────────────────────────────────────────────────

  /// Configures an explicit database path for the current test.
  ///
  /// Call this in [setUp] before any database access. In combination with
  /// [closeDatabase] it ensures each test gets an isolated database.
  ///
  /// Pass [inMemoryDatabasePath] from sqflite to get a true in-memory DB.
  void setDatabasePathForTesting(String path) {
    _testDatabasePath = path;
  }

  // ── Database accessor ───────────────────────────────────────────────────────

  /// Returns the open [Database], initialising it on first call.
  ///
  /// All CRUD methods call this getter, so the database is only opened once.
  Future<Database> get database async {
    // Use the null-coalescing assignment: initialise only if not already open.
    _database ??= await _initDatabase();
    return _database!;
  }

  /// Opens (or creates) the SQLite database file on the device.
  ///
  /// Uses [getDatabasesPath] + [join] from the path package to construct a
  /// platform-appropriate file path (Lab 8 requirement).
  ///
  /// When [_testDatabasePath] is set (during tests), that path is used directly
  /// instead of the computed device path, ensuring test isolation.
  Future<Database> _initDatabase() async {
    final String path;
    if (_testDatabasePath != null) {
      // Test mode: use the injected path (typically inMemoryDatabasePath).
      path = _testDatabasePath!;
    } else {
      // Production mode: build the path using getDatabasesPath + join.
      final dbPath = await getDatabasesPath();
      path = join(dbPath, _databaseName);
    }

    return openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      // onUpgrade is wired here so future migrations can be added without
      // changing the structure of this method.
      onUpgrade: _onUpgrade,
    );
  }

  // ── Schema creation ─────────────────────────────────────────────────────────

  /// Called by sqflite when the database file does not yet exist.
  ///
  /// Creates all tables in one transaction. Keeping schema here (not in
  /// individual screens) is the Lab 8 centralised-helper principle.
  Future<void> _onCreate(Database db, int version) async {
    // ── services table ──────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE $tableServices (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        name        TEXT    NOT NULL,
        description TEXT    NOT NULL,
        icon        TEXT    NOT NULL,
        is_active   INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // ── queue_tokens table ──────────────────────────────────────────────────
    // service_id references services(id) — foreign key relationship.
    await db.execute('''
      CREATE TABLE $tableQueueTokens (
        id                  INTEGER PRIMARY KEY AUTOINCREMENT,
        service_id          INTEGER NOT NULL,
        token_number        INTEGER NOT NULL,
        status              TEXT    NOT NULL,
        created_at          TEXT    NOT NULL,
        estimated_wait_time INTEGER NOT NULL DEFAULT 0,
        is_active           INTEGER NOT NULL DEFAULT 1,
        people_ahead        INTEGER,
        current_token_number INTEGER,
        FOREIGN KEY (service_id) REFERENCES $tableServices (id)
      )
    ''');

    // ── appointments table ──────────────────────────────────────────────────
    // service_id references services(id) — foreign key relationship.
    await db.execute('''
      CREATE TABLE $tableAppointments (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        service_id       INTEGER NOT NULL,
        customer_name    TEXT    NOT NULL,
        appointment_date TEXT    NOT NULL,
        appointment_time TEXT    NOT NULL,
        status           TEXT    NOT NULL,
        created_at       TEXT    NOT NULL,
        FOREIGN KEY (service_id) REFERENCES $tableServices (id)
      )
    ''');

    // Populate the services table with a small set of default records so
    // a fresh installation is not empty. These are real database rows, not
    // mock UI data. They are inserted only once — here in onCreate.
    await _seedDefaultServices(db);
  }

  /// Inserts default service records into a freshly created database.
  ///
  /// Called exclusively from [_onCreate], which only runs when the database
  /// file is created for the first time. This guarantees the seeds are never
  /// duplicated on subsequent app launches.
  Future<void> _seedDefaultServices(Database db) async {
    // db.insert is called directly here (not via the public insertService
    // method) because the helper's database getter would open a second
    // connection during onCreate. We already have a valid [db] reference.
    const seeds = [
      {
        'name': 'Banking Services',
        'description':
            'Account management, cash deposits, withdrawals, and counter services.',
        'icon': 'bank',
        'is_active': 1,
      },
      {
        'name': 'Document Services',
        'description':
            'Apply for, renew, or collect official documents and certificates.',
        'icon': 'document',
        'is_active': 1,
      },
      {
        'name': 'General Consultation',
        'description':
            'Speak with a representative for general inquiries and assistance.',
        'icon': 'consultation',
        'is_active': 1,
      },
      {
        'name': 'Salon & Beauty',
        'description': 'Book a haircut, styling, or beauty treatment session.',
        'icon': 'salon',
        'is_active': 1,
      },
    ];

    for (final seed in seeds) {
      await db.insert(tableServices, seed);
    }
  }

  /// Called when the database version increases.
  ///
  /// Not used in Milestone 3 (version = 1). Structured here so that
  /// future milestones can add ALTER TABLE statements without refactoring.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE $tableQueueTokens ADD COLUMN people_ahead INTEGER');
      await db.execute('ALTER TABLE $tableQueueTokens ADD COLUMN current_token_number INTEGER');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CRUD — Services
  // ═══════════════════════════════════════════════════════════════════════════

  /// Inserts a new [Service] row. Returns the auto-generated row ID.
  ///
  /// [includeId: false] is passed to [toMap] so SQLite generates the primary
  /// key via AUTOINCREMENT (Lab 8 insert pattern).
  Future<int> insertService(Service service) async {
    final db = await database;
    return db.insert(tableServices, service.toMap(includeId: false));
  }

  /// Returns all [Service] rows ordered by name.
  Future<List<Service>> getServices() async {
    final db = await database;
    final maps = await db.query(tableServices, orderBy: 'name ASC');
    return maps.map(Service.fromMap).toList();
  }

  /// Returns a [Service] by its primary key, or null if not found.
  Future<Service?> getServiceById(int id) async {
    final db = await database;
    final maps = await db.query(
      tableServices,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return Service.fromMap(maps.first);
    }
    return null;
  }

  /// Updates an existing [Service] row using a parameterised WHERE clause.
  ///
  /// Returns the number of rows affected.
  ///
  /// The Lab 8 pattern `where: 'id = ?', whereArgs: [id]` is used to avoid
  /// SQL injection and match the taught convention.
  Future<int> updateService(Service service) async {
    final db = await database;
    return db.update(
      tableServices,
      service.toMap(),
      where: 'id = ?',
      whereArgs: [service.id],
    );
  }

  /// Inserts or updates a [Service] based on its ID.
  /// Used for synchronizing data from the API to SQLite without
  /// violating foreign key constraints.
  Future<void> upsertService(Service service) async {
    final db = await database;
    if (service.id == null) {
      await db.insert(tableServices, service.toMap(includeId: false));
      return;
    }

    final existing = await getServiceById(service.id!);
    if (existing != null) {
      await updateService(service);
    } else {
      await db.insert(tableServices, service.toMap(includeId: true));
    }
  }

  /// Deletes a [Service] row by its primary key.
  ///
  /// Returns the number of rows deleted.
  Future<int> deleteService(int id) async {
    final db = await database;
    return db.delete(tableServices, where: 'id = ?', whereArgs: [id]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CRUD — Queue Tokens
  // ═══════════════════════════════════════════════════════════════════════════

  /// Inserts a new [QueueToken] row. Returns the auto-generated row ID.
  Future<int> insertQueueToken(QueueToken token) async {
    final db = await database;
    return db.insert(tableQueueTokens, token.toMap(includeId: false));
  }

  /// Inserts or updates a [QueueToken] based on its ID.
  ///
  /// Prefer [synchronizeQueueToken] for server data: it validates and caches
  /// the parent service in the same transaction before writing the child.
  Future<void> upsertQueueToken(QueueToken token) async {
    final db = await database;
    if (token.id == null) {
      await db.insert(tableQueueTokens, token.toMap(includeId: false));
      return;
    }
    await _upsertQueueToken(db, token);
  }

  /// Atomically caches one server-authoritative queue token and its service.
  Future<void> synchronizeQueueToken(QueueToken token) async {
    final db = await database;
    await db.transaction((txn) async {
      await _ensureServiceReference(txn, token.serviceId, token.service);
      await _upsertQueueToken(txn, token);
    });
  }

  /// Caches the authoritative active-token snapshot. Tokens that were active
  /// locally but are absent from a successful snapshot are retained as history
  /// but made inactive, so stale entries cannot reappear in offline reads.
  Future<void> synchronizeActiveQueueTokens(List<QueueToken> tokens) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final token in tokens) {
        await _ensureServiceReference(txn, token.serviceId, token.service);
        await _upsertQueueToken(txn, token);
      }

      final ids = tokens.map((token) => token.id).whereType<int>().toList();
      final where = ids.isEmpty
          ? 'is_active = ?'
          : 'is_active = ? AND id NOT IN (${List.filled(ids.length, '?').join(', ')})';
      await txn.update(
        tableQueueTokens,
        {'is_active': 0},
        where: where,
        whereArgs: [1, ...ids],
      );
    });
  }

  /// Returns all [QueueToken] rows ordered by creation time (most recent last).
  Future<List<QueueToken>> getQueueTokens() async {
    final db = await database;
    final maps = await db.query(tableQueueTokens, orderBy: 'created_at ASC');
    return maps.map(QueueToken.fromMap).toList();
  }

  /// Returns a [QueueToken] by its primary key, or null if not found.
  Future<QueueToken?> getQueueTokenById(int id) async {
    final db = await database;
    final maps = await db.query(
      tableQueueTokens,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return QueueToken.fromMap(maps.first);
    }
    return null;
  }

  /// Returns all active queue tokens (is_active = 1) ordered by creation time.
  Future<List<QueueToken>> getActiveQueueTokens() async {
    final db = await database;
    final maps = await db.query(
      tableQueueTokens,
      where: 'is_active = ?',
      whereArgs: [1],
      orderBy: 'created_at ASC',
    );
    return maps.map(QueueToken.fromMap).toList();
  }

  /// Checks if the user already has an active token for a specific service.
  Future<QueueToken?> getActiveQueueTokenForService(int serviceId) async {
    final db = await database;
    final maps = await db.query(
      tableQueueTokens,
      where: 'service_id = ? AND is_active = ?',
      whereArgs: [serviceId, 1],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return QueueToken.fromMap(maps.first);
    }
    return null;
  }

  /// Calculates the next token number for a specific service.
  /// Returns MAX(token_number) + 1, or 1 if no tokens exist.
  Future<int> getNextTokenNumber(int serviceId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT MAX(token_number) as max_token FROM $tableQueueTokens WHERE service_id = ?',
      [serviceId],
    );
    final maxToken = result.first['max_token'] as int?;
    return (maxToken ?? 0) + 1;
  }

  /// Updates an existing [QueueToken] row using a parameterised WHERE clause.
  Future<int> updateQueueToken(QueueToken token) async {
    final db = await database;
    return db.update(
      tableQueueTokens,
      token.toMap(),
      where: 'id = ?',
      whereArgs: [token.id],
    );
  }

  /// Deletes a [QueueToken] row by its primary key.
  Future<int> deleteQueueToken(int id) async {
    final db = await database;
    return db.delete(tableQueueTokens, where: 'id = ?', whereArgs: [id]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CRUD — Appointments
  // ═══════════════════════════════════════════════════════════════════════════

  /// Inserts a new [Appointment] row. Returns the auto-generated row ID.
  Future<int> insertAppointment(Appointment appointment) async {
    final db = await database;
    return db.insert(tableAppointments, appointment.toMap(includeId: false));
  }

  /// Inserts or updates an [Appointment] based on its ID.
  /// Prefer [synchronizeAppointment] for server data.
  Future<void> upsertAppointment(Appointment appointment) async {
    final db = await database;
    if (appointment.id == null) {
      await db.insert(tableAppointments, appointment.toMap(includeId: false));
      return;
    }
    await _upsertAppointment(db, appointment);
  }

  /// Atomically caches one server-authoritative appointment and its service.
  Future<void> synchronizeAppointment(Appointment appointment) async {
    final db = await database;
    await db.transaction((txn) async {
      await _ensureServiceReference(
        txn,
        appointment.serviceId,
        appointment.service,
      );
      await _upsertAppointment(txn, appointment);
    });
  }

  /// Reconciles SQLite with the server's complete appointment snapshot.
  /// A cached appointment absent from a successful response is removed rather
  /// than being presented as an authoritative offline record later.
  Future<void> synchronizeAppointments(List<Appointment> appointments) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final appointment in appointments) {
        await _ensureServiceReference(
          txn,
          appointment.serviceId,
          appointment.service,
        );
        await _upsertAppointment(txn, appointment);
      }

      final ids = appointments
          .map((appointment) => appointment.id)
          .whereType<int>()
          .toList();
      await txn.delete(
        tableAppointments,
        where: ids.isEmpty
            ? null
            : 'id NOT IN (${List.filled(ids.length, '?').join(', ')})',
        whereArgs: ids.isEmpty ? null : ids,
      );
    });
  }

  Future<void> _ensureServiceReference(
    DatabaseExecutor executor,
    int serviceId,
    Service? includedService,
  ) async {
    if (includedService != null) {
      if (includedService.id != serviceId) {
        throw StateError(
          'Server returned a service that does not match serviceId.',
        );
      }
      await _upsertService(executor, includedService);
      return;
    }

    final existing = await executor.query(
      tableServices,
      columns: const ['id'],
      where: 'id = ?',
      whereArgs: [serviceId],
      limit: 1,
    );
    if (existing.isEmpty) {
      throw StateError(
        'Cannot cache a server record without its service reference.',
      );
    }
  }

  Future<void> _upsertService(
    DatabaseExecutor executor,
    Service service,
  ) async {
    final id = service.id;
    if (id == null) {
      throw StateError('A server service must have an ID.');
    }
    final updated = await executor.update(
      tableServices,
      service.toMap(),
      where: 'id = ?',
      whereArgs: [id],
    );
    if (updated == 0) {
      await executor.insert(tableServices, service.toMap());
    }
  }

  Future<void> _upsertQueueToken(
    DatabaseExecutor executor,
    QueueToken token,
  ) async {
    final id = token.id;
    if (id == null) {
      await executor.insert(tableQueueTokens, token.toMap(includeId: false));
      return;
    }
    final updated = await executor.update(
      tableQueueTokens,
      token.toMap(),
      where: 'id = ?',
      whereArgs: [id],
    );
    if (updated == 0) {
      await executor.insert(tableQueueTokens, token.toMap());
    }
  }

  Future<void> _upsertAppointment(
    DatabaseExecutor executor,
    Appointment appointment,
  ) async {
    final id = appointment.id;
    if (id == null) {
      await executor.insert(
        tableAppointments,
        appointment.toMap(includeId: false),
      );
      return;
    }
    final updated = await executor.update(
      tableAppointments,
      appointment.toMap(),
      where: 'id = ?',
      whereArgs: [id],
    );
    if (updated == 0) {
      await executor.insert(tableAppointments, appointment.toMap());
    }
  }

  /// Returns all [Appointment] rows ordered by appointment date then time.
  Future<List<Appointment>> getAppointments() async {
    final db = await database;
    final maps = await db.query(
      tableAppointments,
      orderBy: 'appointment_date ASC, appointment_time ASC',
    );
    return maps.map(Appointment.fromMap).toList();
  }

  /// Returns an [Appointment] by its primary key, or null if not found.
  Future<Appointment?> getAppointmentById(int id) async {
    final db = await database;
    final maps = await db.query(
      tableAppointments,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return Appointment.fromMap(maps.first);
    }
    return null;
  }

  /// Updates an existing [Appointment] row using a parameterised WHERE clause.
  Future<int> updateAppointment(Appointment appointment) async {
    final db = await database;
    return db.update(
      tableAppointments,
      appointment.toMap(),
      where: 'id = ?',
      whereArgs: [appointment.id],
    );
  }

  /// Deletes an [Appointment] row by its primary key.
  Future<int> deleteAppointment(int id) async {
    final db = await database;
    return db.delete(tableAppointments, where: 'id = ?', whereArgs: [id]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Utility
  // ═══════════════════════════════════════════════════════════════════════════

  /// Closes the database connection and resets the cached instance.
  ///
  /// Used in tests to ensure a clean database state between test cases.
  /// Should not be called in production code.
  Future<void> closeDatabase() async {
    await _database?.close();
    _database = null;
    _testDatabasePath = null;
  }
}
