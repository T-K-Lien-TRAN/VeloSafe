import 'package:maplibre_gl/maplibre_gl.dart';

enum HazardType { pothole, roadworks, blockedLane, intersection }

enum Severity { low, moderate, high }

extension HazardTypeLabel on HazardType {
  String get label => switch (this) {
        HazardType.pothole => 'Pothole',
        HazardType.roadworks => 'Roadworks',
        HazardType.blockedLane => 'Blocked bike lane',
        HazardType.intersection => 'Dangerous intersection',
      };
}

extension SeverityLabel on Severity {
  String get label => switch (this) {
        Severity.low => 'Low',
        Severity.moderate => 'Moderate',
        Severity.high => 'High',
      };

  int get penalty => switch (this) {
        Severity.low => 2,
        Severity.moderate => 5,
        Severity.high => 10,
      };
}

class Hazard {
  const Hazard({
    required this.id,
    required this.type,
    required this.severity,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    this.description = '',
    this.status = 'active',
    this.confirmations = 0,
    this.reporterId,
    this.isDemo = false,
  });

  final String id;
  final HazardType type;
  final Severity severity;
  final double latitude;
  final double longitude;
  final DateTime createdAt;
  final String description;
  final String status;
  final int confirmations;
  final String? reporterId;
  final bool isDemo;

  LatLng get position => LatLng(latitude, longitude);
  bool get isActive => status == 'active';

  Map<String, dynamic> toInsertJson() => {
        'category': type.name,
        'severity': severity.name,
        'latitude': latitude,
        'longitude': longitude,
        'description': description,
      };

  factory Hazard.fromJson(Map<String, dynamic> json) {
    return Hazard(
      id: json['id'].toString(),
      type: HazardType.values.byName(json['category'] as String),
      severity: Severity.values.byName(json['severity'] as String),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      description: (json['description'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'active',
      confirmations: (json['confirmations_count'] as num?)?.toInt() ?? 0,
      reporterId: json['reporter_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }

  Hazard copyWith({String? status, int? confirmations}) => Hazard(
        id: id,
        type: type,
        severity: severity,
        latitude: latitude,
        longitude: longitude,
        createdAt: createdAt,
        description: description,
        status: status ?? this.status,
        confirmations: confirmations ?? this.confirmations,
        reporterId: reporterId,
        isDemo: isDemo,
      );
}
