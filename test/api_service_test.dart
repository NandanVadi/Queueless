import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:queueless/services/api_service.dart';
import 'package:queueless/models/service.dart';

void main() {
  group('ApiService Tests', () {
    test('getServices returns list of Services on 200 OK', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/services')) {
          return http.Response(
            jsonEncode({
              'services': [
                {
                  'id': 1,
                  'name': 'Test Service',
                  'description': 'Description here',
                  'icon': 'test_icon',
                  'isActive': true
                }
              ]
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final apiService = ApiService(client: mockClient);
      final services = await apiService.getServices();

      expect(services, isA<List<Service>>());
      expect(services.length, 1);
      expect(services[0].id, 1);
      expect(services[0].name, 'Test Service');
      expect(services[0].icon, 'test_icon');
      expect(services[0].isActive, true);
    });

    test('getServices throws HttpException on 404/500 errors', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Not Found', 404);
      });

      final apiService = ApiService(client: mockClient);

      expect(
        () async => await apiService.getServices(),
        throwsA(isA<HttpException>()),
      );
    });

    test('getServices throws ApiException on malformed JSON', () async {
      final mockClient = MockClient((request) async {
        return http.Response('invalid json', 200);
      });

      final apiService = ApiService(client: mockClient);

      expect(
        () async => await apiService.getServices(),
        throwsA(isA<ApiException>()),
      );
    });

    test('getServices throws ApiException on missing required fields', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'services': [
              {
                'id': 1,
                // 'name' missing
                'description': 'Description here',
                'icon': 'test_icon',
              }
            ]
          }),
          200,
        );
      });

      final apiService = ApiService(client: mockClient);

      expect(
        () async => await apiService.getServices(),
        throwsA(isA<ApiException>()),
      );
    });

    test('getServices throws NetworkException on network connection failure', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Connection failed');
      });

      final apiService = ApiService(client: mockClient);

      expect(
        () async => await apiService.getServices(),
        throwsA(isA<NetworkException>()),
      );
    });
  });
}
