import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart';

import '../models/bike_route.dart';
import '../models/hazard.dart';
import 'location_service.dart';
import 'safety_score_service.dart';

class RoutingService {
  const RoutingService();

  // For production, provide a backend URL and keep ORS_API_KEY on the server.
  static const String _routingApiUrl =
      String.fromEnvironment('ROUTING_API_URL');

  // Development only! dart-define values can be recovered from compiled apps.
  static const String _developmentOrsKey =
      String.fromEnvironment('ORS_API_KEY');

  bool get isConfigured =>
      _routingApiUrl.isNotEmpty || _developmentOrsKey.isNotEmpty;

  Future<List<BikeRoute>> routeCandidates({
    required LatLng origin,
    required LatLng destination,
    required Iterable<Hazard> hazards,
  }) async {
    if (!isConfigured) {
      // An illustrative line only, NOT a route on actual streets.
      return [_preview(origin, destination)];
    }

    final endpoint = _routingApiUrl.isNotEmpty
        ? Uri.parse(_routingApiUrl)
        : Uri.parse(
            'https://api.openrouteservice.org/v2/directions/'
            'cycling-regular/geojson',
          );
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (_routingApiUrl.isEmpty) {
      headers['Authorization'] = _developmentOrsKey;
    }

    final coordinates = [
      [origin.longitude, origin.latitude],
      [destination.longitude, destination.latitude],
    ];

    // Alternative routes may not be available for every pair of locations.
    var response = await _post(
      endpoint,
      headers,
      {
        'coordinates': coordinates,
        'alternative_routes': {
          'target_count': 2,
          'share_factor': 0.6,
          'weight_factor': 1.5,
        },
      },
    );
    if (response.statusCode == 400 || response.statusCode == 422) {
      response = await _post(
        endpoint,
        headers,
        {'coordinates': coordinates},
      );
    }
    if (response.statusCode != 200) {
      throw StateError(
        'Routing failed (${response.statusCode}): '
        '${response.body.length > 200 ? response.body.substring(0, 200) : response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final features = json['features'] as List<dynamic>?;
    if (features == null || features.isEmpty) {
      throw const FormatException('Routing API returned no GeoJSON features.');
    }

    const scoreService = SafetyScoreService();
    final routes = <BikeRoute>[];
    for (var index = 0; index < features.length; index++) {
      final feature = features[index] as Map<String, dynamic>;
      final route = BikeRoute.fromGeoJsonFeature(feature, index);
      final nearby = scoreService.hazardsNearRoute(hazards, route.points);
      routes.add(route.withSafety(nearby, scoreService.score(nearby)));
    }
    // Highest Safety Score wins; travel duration is the tie-breaker.
    routes.sort((a, b) {
      final byScore = b.safetyScore.compareTo(a.safetyScore);
      return byScore != 0
          ? byScore
          : a.durationSeconds.compareTo(b.durationSeconds);
    });
    return routes;
  }

  Future<http.Response> _post(
    Uri endpoint,
    Map<String, String> headers,
    Map<String, dynamic> body,
  ) =>
      http
          .post(endpoint, headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 25));

  BikeRoute _preview(LatLng origin, LatLng destination) {
    final straightDistance = LocationService.distanceMeters(origin, destination);
    // Only a mockup. No legitimate cycling distance/time is inferred.
    final midpoint = LatLng(
      (origin.latitude + destination.latitude) / 2,
      (origin.longitude + destination.longitude) / 2,
    );
    return BikeRoute(
      id: 'preview',
      points: [origin, midpoint, destination],
      distanceMeters: straightDistance,
      durationSeconds: 0,
      isPreview: true,
      safetyScore: 0,
    );
  }
}
