import 'dart:math' as math;

import 'package:maplibre_gl/maplibre_gl.dart';

import '../models/hazard.dart';
import 'location_service.dart';

class SafetyScoreService {
  const SafetyScoreService();

  static const double defaultRadiusMeters = 500;
  static const double routeHazardThresholdMeters = 30;

  int score(Iterable<Hazard> hazards) {
    final recent = hazards.where(isRecentActive);
    final totalPenalty = recent.fold<int>(
      0,
      (penalty, hazard) => penalty + hazard.severity.penalty,
    );
    return math.max(0, 100 - totalPenalty);
  }

  bool isRecentActive(Hazard hazard) {
    final age = DateTime.now().difference(hazard.createdAt);
    return hazard.isActive && !age.isNegative && age <= const Duration(days: 7);
  }

  List<Hazard> hazardsInArea(
    Iterable<Hazard> hazards,
    LatLng center, {
    double radiusMeters = defaultRadiusMeters,
  }) =>
      hazards
          .where(isRecentActive)
          .where(
            (hazard) => LocationService.distanceMeters(
              hazard.position,
              center,
            ) <= radiusMeters,
          )
          .toList();

  List<Hazard> hazardsNearRoute(
    Iterable<Hazard> hazards,
    List<LatLng> route, {
    double thresholdMeters = routeHazardThresholdMeters,
  }) =>
      hazards
          .where(isRecentActive)
          .where(
            (hazard) => distanceToPolylineMeters(hazard.position, route) <=
                thresholdMeters,
          )
          .toList();

  // Local equirectangular projection is adequate for short city-scale segments.
  // This is an approximation, not a street-network/map-matching algorithm.
  double distanceToPolylineMeters(LatLng point, List<LatLng> line) {
    if (line.isEmpty) return double.infinity;
    if (line.length == 1) return LocationService.distanceMeters(point, line[0]);

    const earthRadius = 6371000.0;
    final latitudeRadians = point.latitude * math.pi / 180;
    final scaleX = earthRadius * math.cos(latitudeRadians) * math.pi / 180;
    final scaleY = earthRadius * math.pi / 180;
    var bestDistance = double.infinity;

    for (var index = 1; index < line.length; index++) {
      final a = line[index - 1];
      final b = line[index];
      final ax = (a.longitude - point.longitude) * scaleX;
      final ay = (a.latitude - point.latitude) * scaleY;
      final bx = (b.longitude - point.longitude) * scaleX;
      final by = (b.latitude - point.latitude) * scaleY;
      final dx = bx - ax;
      final dy = by - ay;
      final lengthSquared = dx * dx + dy * dy;
      final t = lengthSquared == 0
          ? 0.0
          : ((-ax * dx - ay * dy) / lengthSquared).clamp(0.0, 1.0);
      final x = ax + t * dx;
      final y = ay + t * dy;
      bestDistance = math.min(bestDistance, math.sqrt(x * x + y * y));
    }
    return bestDistance;
  }
}
