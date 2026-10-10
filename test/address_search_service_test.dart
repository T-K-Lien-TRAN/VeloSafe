import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:velosafe/services/address_search_service.dart';

void main() {
  test('Photon result converts GeoJSON [lon, lat] correctly', () async {
    final client = MockClient((request) async {
      expect(request.uri.path, '/api/');
      expect(request.uri.queryParameters['q'], 'Place Massena Nice');
      expect(request.uri.queryParameters['limit'], '5');
      return http.Response('''{
        "features": [
          {"type":"Feature","geometry":{"type":"Point",
           "coordinates":[7.2700,43.6979]},
           "properties":{"name":"Place Massena","city":"Nice",
           "country":"France"}}
        ]
      }''', 200);
    });
    final service = AddressSearchService(client: client);
    final results = await service.search('Place Massena Nice');
    expect(results.length, 1);
    expect(results.first.position.latitude, closeTo(43.6979, 0.000001));
    expect(results.first.position.longitude, closeTo(7.2700, 0.000001));
    expect(results.first.label, contains('Nice'));
    client.close();
  });

  test('Empty Photon features return an empty list', () async {
    final client = MockClient((_) async => http.Response('{"features":[]}', 200));
    final service = AddressSearchService(client: client);
    expect(await service.search('Unknown address'), isEmpty);
    client.close();
  });

  test('Search query must have at least 3 characters', () async {
    final service = AddressSearchService();
    await expectLater(service.search('a'), throwsArgumentError);
    service.dispose();
  });
}
