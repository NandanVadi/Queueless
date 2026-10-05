import 'package:flutter_test/flutter_test.dart';
import 'package:queueless/utils/qr_payload.dart';

void main() {
  group('QrPayloadService', () {
    test('encodeQueueToken formats JSON correctly', () {
      final jsonStr = QrPayloadService.encodeQueueToken(12);
      expect(jsonStr, '{"type":"queue_token","id":12}');
    });

    test('encodeAppointment formats JSON correctly', () {
      final jsonStr = QrPayloadService.encodeAppointment(5);
      expect(jsonStr, '{"type":"appointment","id":5}');
    });

    test('decodeAndValidate correctly decodes valid queue_token', () {
      final payload = '{"type":"queue_token","id":12}';
      final result = QrPayloadService.decodeAndValidate(payload);
      expect(result['type'], 'queue_token');
      expect(result['id'], 12);
    });

    test('decodeAndValidate correctly decodes valid appointment', () {
      final payload = '{"type":"appointment","id":5}';
      final result = QrPayloadService.decodeAndValidate(payload);
      expect(result['type'], 'appointment');
      expect(result['id'], 5);
    });

    test('decodeAndValidate throws on null or empty payload', () {
      expect(() => QrPayloadService.decodeAndValidate(null), throwsFormatException);
      expect(() => QrPayloadService.decodeAndValidate(''), throwsFormatException);
      expect(() => QrPayloadService.decodeAndValidate('   '), throwsFormatException);
    });

    test('decodeAndValidate throws on invalid JSON', () {
      expect(() => QrPayloadService.decodeAndValidate('not json'), throwsFormatException);
      expect(() => QrPayloadService.decodeAndValidate('{type: "missing quotes"}'), throwsFormatException);
    });

    test('decodeAndValidate throws if payload is not a JSON object', () {
      expect(() => QrPayloadService.decodeAndValidate('["array"]'), throwsFormatException);
      expect(() => QrPayloadService.decodeAndValidate('123'), throwsFormatException);
    });

    test('decodeAndValidate throws if missing type or id', () {
      expect(() => QrPayloadService.decodeAndValidate('{"id": 1}'), throwsFormatException);
      expect(() => QrPayloadService.decodeAndValidate('{"type": "queue_token"}'), throwsFormatException);
    });

    test('decodeAndValidate throws on unknown type', () {
      expect(() => QrPayloadService.decodeAndValidate('{"type": "unknown", "id": 1}'), throwsFormatException);
    });

    test('decodeAndValidate throws if ID is not an int', () {
      expect(() => QrPayloadService.decodeAndValidate('{"type": "queue_token", "id": "abc"}'), throwsFormatException);
    });

    test('decodeAndValidate handles stringified ints gracefully', () {
      final payload = '{"type":"queue_token","id":"12"}';
      final result = QrPayloadService.decodeAndValidate(payload);
      expect(result['id'], 12);
    });
  });
}
