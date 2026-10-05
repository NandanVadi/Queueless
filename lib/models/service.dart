/// Represents a service category in QueueLess (e.g. "Banking", "Healthcare").
///
/// SQLite mapping notes (Lab 8 concepts):
///   - [id] is nullable because SQLite generates it via AUTOINCREMENT.
///     A new Service object has id == null until it is inserted.
///   - [isActive] is a Dart bool but stored as INTEGER (1 = true, 0 = false)
///     because SQLite has no native BOOLEAN type.
///   - [icon] is stored as a String identifier (e.g. "bank") rather than
///     Flutter's IconData, which is a UI concern and has no SQLite equivalent.
class Service {
  final int? id;
  final String name;
  final String description;

  /// Icon identifier string (e.g. 'bank', 'hospital', 'government').
  /// Resolved to an actual IconData in the UI layer, not here in the model.
  final String icon;

  /// Stored in SQLite as INTEGER: 1 = active, 0 = inactive.
  final bool isActive;

  const Service({
    this.id,
    required this.name,
    required this.description,
    required this.icon,
    this.isActive = true,
  });

  // ── SQLite serialization ────────────────────────────────────────────────────

  /// Converts this [Service] to a [Map] suitable for sqflite insert/update.
  ///
  /// [includeId] controls whether the primary key is included.
  /// Pass `includeId: false` when inserting a new row so SQLite generates
  /// the ID via AUTOINCREMENT (Lab 8 pattern).
  Map<String, dynamic> toMap({bool includeId = true}) {
    return {
      if (includeId && id != null) 'id': id,
      'name': name,
      'description': description,
      'icon': icon,
      // Dart bool → SQLite INTEGER: true = 1, false = 0
      'is_active': isActive ? 1 : 0,
    };
  }

  /// Creates a [Service] from a raw SQLite row map (Lab 8 fromMap pattern).
  factory Service.fromMap(Map<String, dynamic> map) {
    return Service(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: map['description'] as String,
      icon: map['icon'] as String,
      // SQLite INTEGER → Dart bool: 1 = true, anything else = false
      isActive: (map['is_active'] as int) == 1,
    );
  }

  /// Creates a [Service] from a REST API JSON response.
  factory Service.fromJson(Map<String, dynamic> json) {
    return Service(
      id: json['id'] as int?,
      name: json['name'] as String,
      description: json['description'] as String,
      icon: json['icon'] as String,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  /// Converts this [Service] to a JSON map for the REST API.
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'description': description,
      'icon': icon,
      'isActive': isActive,
    };
  }

  // ── Utility ─────────────────────────────────────────────────────────────────

  /// Returns a copy of this [Service] with the given fields replaced.
  /// Useful when updating a single field without recreating the whole object.
  Service copyWith({
    int? id,
    String? name,
    String? description,
    String? icon,
    bool? isActive,
  }) {
    return Service(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  String toString() =>
      'Service(id: $id, name: $name, icon: $icon, isActive: $isActive)';
}
