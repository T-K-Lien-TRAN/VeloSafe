import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../models/hazard.dart';
import '../services/hazard_service.dart';
import '../services/location_service.dart';
import '../services/safety_score_service.dart';
import '../widgets/hazard_marker.dart';
import '../widgets/safety_score_card.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    required this.service,
    required this.onReport,
    required this.onHazardSelected,
    required this.onShowZones,
    required this.onShowRoutes,
  });

  final HazardService service;
  final VoidCallback onReport;
  final ValueChanged<Hazard> onHazardSelected;
  final VoidCallback onShowZones;
  final VoidCallback onShowRoutes;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _locationService = LocationService();
  static const _styleUrl = 'https://tiles.openfreemap.org/styles/liberty';

  MapLibreMapController? _controller;
  LatLng? _userLocation;
  bool _styleLoaded = false;
  bool _showHazards = true;
  bool _isDrawing = false;
  bool _redrawRequested = false;
  String? _locationMessage;
  final Map<String, String> _circleToHazard = {};

  @override
  void initState() {
    super.initState();
    widget.service.addListener(_onReportsChanged);
    _locate();
  }

  @override
  void dispose() {
    widget.service.removeListener(_onReportsChanged);
    super.dispose();
  }

  void _onReportsChanged() {
    if (!mounted) return;
    setState(() {});
    _renderMarkers();
  }

  Future<void> _locate() async {
    try {
      final position = await _locationService.currentPosition();
      if (!mounted) return;
      setState(() {
        _userLocation = position;
        _locationMessage = null;
      });
      await _controller?.animateCamera(
        CameraUpdate.newLatLngZoom(position, 15),
      );
      _renderMarkers();
    } catch (error) {
      if (!mounted) return;
      setState(() => _locationMessage = '$error');
    }
  }

  void _mapCreated(MapLibreMapController controller) {
    _controller = controller;
    controller.onCircleTapped.add(_onCircleTapped);
  }

  void _onCircleTapped(Circle circle) {
    final id = _circleToHazard[circle.id];
    if (id == null) return;
    final hazard = widget.service.byId(id);
    if (hazard != null) widget.onHazardSelected(hazard);
  }

  // Only draw annotations after MapLibre reports that its style is loaded.
  Future<void> _renderMarkers() async {
    final controller = _controller;
    if (!_styleLoaded || controller == null) return;
    if (_isDrawing) {
      _redrawRequested = true;
      return;
    }
    _isDrawing = true;
    try {
      do {
        _redrawRequested = false;
        await controller.clearCircles();
        _circleToHazard.clear();
        if (_showHazards) {
          for (final hazard in widget.service.hazards.where((h) => h.isActive)) {
            if (!mounted) return;
            final circle = await controller.addCircle(CircleOptions(
              geometry: hazard.position,
              circleRadius: 12,
              circleColor: _mapColor(hazard.severity),
              circleStrokeColor: '#FFFFFF',
              circleStrokeWidth: 3,
            ));
            _circleToHazard[circle.id] = hazard.id;
          }
        }
        if (_userLocation != null && mounted) {
          await controller.addCircle(CircleOptions(
            geometry: _userLocation,
            circleColor: '#2176BC',
            circleRadius: 9,
            circleStrokeColor: '#FFFFFF',
            circleStrokeWidth: 3,
          ));
        }
      } while (_redrawRequested && mounted);
    } catch (error) {
      if (mounted) setState(() => _locationMessage = 'Map markers: $error');
    } finally {
      _isDrawing = false;
    }
  }

  String _mapColor(Severity severity) => switch (severity) {
        Severity.low => '#D5A02F',
        Severity.moderate => '#D88B17',
        Severity.high => '#BF4A41',
      };

  @override
  Widget build(BuildContext context) {
    const scores = SafetyScoreService();
    final center = _userLocation ?? LocationService.demoCenter;
    final areaHazards = scores.hazardsInArea(widget.service.hazards, center);
    final areaScore = scores.score(areaHazards);

    return Stack(
      children: [
        MapLibreMap(
          styleString: _styleUrl,
          initialCameraPosition: const CameraPosition(
            target: LocationService.demoCenter,
            zoom: 14.5,
          ),
          onMapCreated: _mapCreated,
          onStyleLoadedCallback: () {
            _styleLoaded = true;
            _renderMarkers();
          },
          compassEnabled: false,
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Material(
                  elevation: 3,
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  child: ListTile(
                    title: const Text('VéloSafe',
                        style: TextStyle(
                          fontSize: 23,
                          color: veloText,
                          fontWeight: FontWeight.bold,
                        )),
                    subtitle: const Text('Your companion for safer cycling'),
                    leading: const CircleAvatar(
                      backgroundColor: veloGreen,
                      child: Icon(Icons.directions_bike, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Card(
                  color: Colors.white,
                  child: ListTile(
                    leading: const Icon(Icons.search),
                    title: const Text('Where would you like to go?'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: widget.onShowRoutes,
                  ),
                ),
                Row(
                  children: [
                    FilterChip(
                      label: const Text('Hazards'),
                      avatar: const Icon(Icons.warning_amber, size: 18),
                      selected: _showHazards,
                      onSelected: (value) {
                        setState(() => _showHazards = value);
                        _renderMarkers();
                      },
                    ),
                    const SizedBox(width: 8),
                    if (widget.service.isDemoMode)
                      const DemoNotice(text: 'DEMO data'),
                  ],
                ),
                if (_locationMessage != null)
                  Material(
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text('GPS: $_locationMessage',
                          style: const TextStyle(fontSize: 11)),
                    ),
                  ),
                if (widget.service.error != null)
                  Material(
                    color: Colors.white,
                    child: Text(widget.service.error!,
                        style: const TextStyle(color: Colors.red)),
                  ),
              ],
            ),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 230,
          child: FloatingActionButton.small(
            backgroundColor: Colors.white,
            onPressed: _locate,
            tooltip: 'Center on GPS',
            child: const Icon(Icons.my_location, color: veloGreen),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: Card(
            elevation: 5,
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SafetyScoreCard(
                        score: areaScore,
                        reportCount: areaHazards.length,
                        compact: true,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: widget.onShowZones,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_userLocation == null
                                  ? 'Around Nice (sample)' : 'Around you'),
                              Text('${areaHazards.length} recent hazards • '
                                  'View area →'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: widget.onReport,
                      icon: const Icon(Icons.add),
                      label: const Text('Report a hazard'),
                    ),
                  ),
                  const Text('Stop somewhere safe before reporting.',
                      style: TextStyle(fontSize: 11, color: Colors.black54)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
