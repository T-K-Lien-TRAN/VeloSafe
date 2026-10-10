import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:velosafe/models/hazard.dart';
import 'package:velosafe/services/safety_score_service.dart';

Hazard makeHazard({
  Severity severity = Severity.low,
  String status = 'active',
  DateTime? createdAt,
  double lat = 43.7102,
  double lon = 7.2620,
}) => Hazard(
      id: 'test',
      type: HazardType.pothole,
      severity: severity,
      latitude: lat,
      longitude: lon,
      createdAt: createdAt ?? DateTime.now().subtract(const Duration(hours: 1)),
      status: status,
    );

void main() {
  const service = SafetyScoreService();

  test('Design sample: one low, two moderate, one high gives 78', () {
    final reports = [
      makeHazard(),
      makeHazard(severity: Severity.moderate),
      makeHazard(severity: Severity.moderate),
      makeHazard(severity: Severity.high),
    ];
    expect(service.score(reports), 78);
  });

  test('Score is bounded below by zero', () {
    expect(
      service.score(List.generate(12, (_) =>
          makeHazard(severity: Severity.high))),
      0,
    );
  });

  test('Ignores resolved and older-than-seven-day reports', () {
    final reports = [
      makeHazard(status: 'resolved', severity: Severity.high),
      makeHazard(
        severity: Severity.high,
        createdAt: DateTime.now().subtract(const Duration(days: 8)),
      ),
      makeHazard(),
    ];
    expect(service.score(reports), 98);
  });

  test('Distance to straight route is approximately zero on segment', () {
    final route = [
      const LatLng(43.7100, 7.2600),
      const LatLng(43.7100, 7.2640),
    ];
    final distance = service.distanceToPolylineMeters(
      const LatLng(43.7100, 7.2620), route,
    );
    expect(distance, lessThan(0.1));
  });

  test('Nearby route reports ignore distant hazards', () {
    final route = [
      const LatLng(43.7100, 7.2600),
      const LatLng(43.7100, 7.2640),
    ];
    final near = makeHazard(lat: 43.7100, lon: 7.2620);
    final far = makeHazard(lat: 43.7200, lon: 7.2620);
    expect(service.hazardsNearRoute([near, far], route), [near]);
  });
}
