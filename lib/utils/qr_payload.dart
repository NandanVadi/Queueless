import 'dart:convert';

/// A utility class for handling QR payload encoding and decoding.
/// 
/// The format strictly follows data-minimization principles:
/// {"type": "queue_token", "id": 12}
/// {"type": "appointment", "id": 5}
class QrPayloadService {
  static const String typeQueueToken = 'queue_token';
  static const String typeAppointment = 'appointment';

  /// Encodes a queue token ID into a JSON string.
  static String encodeQueueToken(int id) {
    return jsonEncode({
      'type': typeQueueToken,
      'id': id,
    });
  }

  /// Encodes an appointment ID into a JSON string.
  static String encodeAppointment(int id) {
    return jsonEncode({
      'type': typeAppointment,
      'id': id,
    });
  }

  /// Decodes and validates a JSON string from a QR code.
  /// 
  /// Returns a Map containing 'type' and 'id' if valid.
  /// Throws an exception with a user-friendly message if invalid.
  static Map<String, dynamic> decodeAndValidate(String? payload) {
    if (payload == null || payload.trim().isEmpty) {
      throw const FormatException('Empty QR code.');
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(payload);
    } catch (e) {
      throw const FormatException('Invalid QR code format (not JSON).');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid QR code format (not a JSON object).');
    }

    if (!decoded.containsKey('type')) {
      throw const FormatException('Missing type in QR payload.');
    }

    if (!decoded.containsKey('id')) {
      throw const FormatException('Missing ID in QR payload.');
    }

    final type = decoded['type'];
    final id = decoded['id'];

    if (type != typeQueueToken && type != typeAppointment) {
      throw FormatException('Unknown QR type: $type.');
    }

    if (id is! int) {
      // Sometimes JSON might parse id as a string depending on encoding, 
      // but we expect standard integer encoding.
      if (id is String && int.tryParse(id) != null) {
        decoded['id'] = int.parse(id);
      } else {
        throw const FormatException('Invalid ID format in QR payload.');
      }
    }

    return {
      'type': decoded['type'],
      'id': decoded['id'],
    };
  }
}
