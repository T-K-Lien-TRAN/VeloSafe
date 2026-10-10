import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart';

/// A human-readable search result and the coordinates used for routing.
class AddressSuggestion {
  const AddressSuggestion({
    required this.label,
    required this.position,
  });

  final String label;
  final LatLng position;

  /// Photon uses GeoJSON coordinates: [longitude, latitude].
  factory AddressSuggestion.fromPhotonFeature(Map<String, dynamic> feature) {
    final geometry = feature['geometry'] as Map<String, dynamic>;
    final coordinates = geometry['coordinates'] as List<dynamic>;
    if (coordinates.length < 2) {
      throw const FormatException('Geocoding result is missing coordinates.');
    }
    final properties = feature['properties'] as Map<String, dynamic>? ?? {};
    String value(String key) => (properties[key] ?? '').toString().trim();

    final name = value('name');
    final street = value('street');
    final houseNumber = value('housenumber');
    final postcode = value('postcode');
    final city = value('city');
    final state = value('state');
    final country = value('country');

    final parts = <String>[];
    if (name.isNotEmpty && name.toLowerCase() != street.toLowerCase()) {
      parts.add(name);
    }
    final streetAddress = '$houseNumber $street'.trim();
    if (streetAddress.isNotEmpty) parts.add(streetAddress);
    final municipality = '$postcode $city'.trim();
    if (municipality.isNotEmpty) {
      parts.add(municipality);
    } else if (state.isNotEmpty) {
      parts.add(state);
    }
    if (country.isNotEmpty) parts.add(country);

    final latitude = (coordinates[1] as num).toDouble();
    final longitude = (coordinates[0] as num).toDouble();
    if (latitude < -90 || latitude > 90 ||
        longitude < -180 || longitude > 180) {
      throw const FormatException('Invalid geocoding coordinates.');
    }

    return AddressSuggestion(
      label: parts.isEmpty ? '$latitude, $longitude' : parts.join(', '),
      position: LatLng(latitude, longitude),
    );
  }
}

/// Converts a typed address into possible map coordinates using Photon.
///
/// The default photon.komoot.io URL is a public DEMO endpoint: send requests
/// only on an explicit user action, keep volume reasonable and use your own
/// Photon server/proxy for a production application.
class AddressSearchService {
  AddressSearchService({http.Client? client})
      : _client = client ?? http.Client(),
        _ownsClient = client == null;

  static const String _defaultEndpoint = 'https://photon.komoot.io/api/';
  static const String _configuredEndpoint =
      String.fromEnvironment('GEOCODING_URL', defaultValue: _defaultEndpoint);

  final http.Client _client;
  final bool _ownsClient;

  Future<List<AddressSuggestion>> search(String address) async {
    final query = address.trim();
    if (query.length < 3) {
      throw ArgumentError('Enter at least 3 characters for an address.');
    }
    final endpoint = Uri.parse(_configuredEndpoint);
    final url = endpoint.replace(queryParameters: {
      ...endpoint.queryParameters,
      'q': query,
      'limit': '5',
      'lang': 'en',
    });

    final response = await _client.get(
      url,
      headers: {'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 429) {
      throw StateError('The address service is busy. Try again later.');
    }
    if (response.statusCode != 200) {
      throw StateError('Address search failed (HTTP ${response.statusCode}).');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final features = json['features'] as List<dynamic>? ?? [];
    // Skip malformed individual features rather than crashing the screen.
    final suggestions = <AddressSuggestion>[];
    for (final feature in features) {
      try {
        suggestions.add(AddressSuggestion.fromPhotonFeature(
          feature as Map<String, dynamic>,
        ));
      } on FormatException {
        continue;
      } on TypeError {
        continue;
      }
    }
    return suggestions;
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}
