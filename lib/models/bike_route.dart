import 'package:maplibre_gl/maplibre_gl.dart';

import 'hazard.dart';

class BikeRoute {
  const BikeRoute({
    required this.id,
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    this.nearbyHazards = const [],
    this.safetyScore = 100,
    this.isPreview = false,
  });

  final String id;
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;
  final List<Hazard> nearbyHazards;
  final int safetyScore;
  final bool isPreview;

  BikeRoute withSafety(List<Hazard> hazards, int score) => BikeRoute(
        id: id,
        points: points,
        distanceMeters: distanceMeters,
        durationSeconds: durationSeconds,
        nearbyHazards: hazards,
        safetyScore: score,
        isPreview: isPreview,
      );

  factory BikeRoute.fromGeoJsonFeature(
    Map<String, dynamic> feature,
    int index,
  ) {
    final geometry = feature['geometry'] as Map<String, dynamic>;
    if (geometry['type'] != 'LineString') {
      throw const FormatException('Expected a GeoJSON LineString.');
    }
    final coordinates = geometry['coordinates'] as List<dynamic>;
    final properties = feature['properties'] as Map<String, dynamic>;
    final summary = properties['summary'] as Map<String, dynamic>;

    return BikeRoute(
      id: 'route_$index',
      points: coordinates.map((entry) {
        final pair = entry as List<dynamic>;
        // GeoJSON orders coordinates as [longitude, latitude].
        return LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble());
      }).toList(),
      distanceMeters: (summary['distance'] as num).toDouble(),
      durationSeconds: (summary['duration'] as num).toDouble(),
    );
  }
}
