import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../models/hazard.dart';
import '../services/hazard_service.dart';
import '../services/location_service.dart';
import '../services/safety_score_service.dart';
import '../widgets/hazard_marker.dart';

class SafetyScoreScreen extends StatefulWidget {
  const SafetyScoreScreen({super.key, required this.service});
  final HazardService service;

  @override
  State<SafetyScoreScreen> createState() => _SafetyScoreScreenState();
}

class _SafetyScoreScreenState extends State<SafetyScoreScreen> {
  static const _scoreService = SafetyScoreService();
  MapLibreMapController? _controller;
  LatLng _center = LocationService.demoCenter;
  bool _usingGps = false;
  bool _styleLoaded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.service.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.service.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
    _draw();
  }

  Future<void> _findMyArea() async {
    try {
      final point = await LocationService().currentPosition();
      if (!mounted) return;
      setState(() {
        _center = point;
        _usingGps = true;
        _error = null;
      });
      await _controller?.animateCamera(CameraUpdate.newLatLngZoom(point, 14));
      await _draw();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  List<LatLng> _circlePoints(LatLng center, double meters) {
    final latitudeRadians = center.latitude * math.pi / 180;
    final latitudeStep = meters / 111320;
    final longitudeStep = meters / (111320 * math.cos(latitudeRadians));
    return [
      for (var i = 0; i <= 64; i++)
        LatLng(
          center.latitude + latitudeStep * math.sin(i * math.pi / 32),
          center.longitude + longitudeStep * math.cos(i * math.pi / 32),
        ),
    ];
  }

  Future<void> _draw() async {
    if (!_styleLoaded || _controller == null) return;
    try {
      await _controller!.clearLines();
      await _controller!.clearCircles();
      await _controller!.addLine(LineOptions(
        geometry: _circlePoints(_center, 500),
        lineWidth: 3,
        lineColor: '#217C5D',
        lineOpacity: 0.8,
      ));
      final hazards = _scoreService.hazardsInArea(widget.service.hazards, _center);
      for (final hazard in hazards) {
        if (!mounted) return;
        await _controller!.addCircle(CircleOptions(
          geometry: hazard.position,
          circleRadius: 10,
          circleColor: hazard.severity == Severity.high ? '#C44C43' : '#D69A24',
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 2,
        ));
      }
    } catch (error) {
      if (mounted) setState(() => _error = 'Map drawing error: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final reports = _scoreService.hazardsInArea(widget.service.hazards, _center);
    final score = _scoreService.score(reports);
    final low = reports.where((h) => h.severity == Severity.low).length;
    final moderate =
        reports.where((h) => h.severity == Severity.moderate).length;
    final high = reports.where((h) => h.severity == Severity.high).length;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const ListTile(
          title: Text('Safety Score',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          subtitle: Text('Understand an area’s recent reported hazards'),
        ),
        SizedBox(
          height: 285,
          child: Stack(children: [
            MapLibreMap(
              styleString: 'https://tiles.openfreemap.org/styles/liberty',
              initialCameraPosition: const CameraPosition(
                target: LocationService.demoCenter,
                zoom: 13.5,
              ),
              onMapCreated: (controller) => _controller = controller,
              onStyleLoadedCallback: () {
                _styleLoaded = true;
                _draw();
              },
            ),
            Positioned(
              left: 10,
              top: 10,
              child: Chip(
                label: const Text('500 m radius'),
                avatar: const Icon(Icons.center_focus_strong, size: 18),
                backgroundColor: Colors.white,
              ),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: FloatingActionButton.small(
                onPressed: _findMyArea,
                backgroundColor: Colors.white,
                child: const Icon(Icons.my_location, color: veloGreen),
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(_usingGps ? 'Around you' : 'Nice sample area',
                      style: const TextStyle(
                          color: veloText,
                          fontSize: 24,
                          fontWeight: FontWeight.bold)),
                ),
                if (widget.service.isDemoMode) const DemoNotice(),
              ]),
              if (_error != null) Text(_error!,
                  style: const TextStyle(color: Colors.red)),
              if (widget.service.error != null) Text(widget.service.error!,
                  style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 18),
              Row(children: [
                Text('$score',
                    style: const TextStyle(
                        color: veloGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 68)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('out of 100'),
                      Text('$low low • $moderate moderate • $high high'),
                      const Text('Last 7 days'),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              LinearProgressIndicator(value: score / 100, minHeight: 8),
              const SizedBox(height: 12),
              Text('${reports.length} active reports in this area'),
              const SizedBox(height: 14),
              const Text(
                'Prototype formula: 100 − (2 × low + 5 × moderate + '
                '10 × high), minimum 0.',
              ),
              const SizedBox(height: 12),
              const Text(
                'This is a report-density indicator, not a validated '
                'measure of road safety. Areas without reports are not '
                'necessarily safe.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 15),
              for (final hazard in reports)
                ListTile(
                  leading: Icon(hazardIcon(hazard.type),
                      color: severityColor(hazard.severity)),
                  title: Text(hazard.type.label),
                  subtitle: Text(hazard.description.isEmpty
                      ? hazard.severity.label : hazard.description),
                  trailing: Text(hazard.severity.label),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
