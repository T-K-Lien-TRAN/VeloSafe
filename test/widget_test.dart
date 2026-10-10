import 'package:flutter_test/flutter_test.dart';
import 'package:velosafe/models/hazard.dart';

// Keeps `flutter create` from adding its default counter-app widget test.
// A full map widget test needs MapLibre platform mocks or integration testing.
void main() {
  test('Hazard categories and penalties are available', () {
    expect(HazardType.pothole.label, 'Pothole');
    expect(HazardType.roadworks.label, 'Roadworks');
    expect(Severity.low.penalty, 2);
    expect(Severity.moderate.penalty, 5);
    expect(Severity.high.penalty, 10);
  });
}
