import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../models/hazard.dart';
import '../services/hazard_service.dart';
import '../services/location_service.dart';
import '../widgets/hazard_marker.dart';

class ReportHazardScreen extends StatefulWidget {
  const ReportHazardScreen({super.key, required this.service});
  final HazardService service;

  @override
  State<ReportHazardScreen> createState() => _ReportHazardScreenState();
}

class _ReportHazardScreenState extends State<ReportHazardScreen> {
  final _description = TextEditingController();
  MapLibreMapController? _controller;
  HazardType _type = HazardType.pothole;
  Severity _severity = Severity.moderate;
  LatLng? _chosenLocation;
  bool _saving = false;
  String? _message;
  bool _styleLoaded = false;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _useGps() async {
    try {
      final point = await LocationService().currentPosition();
      if (!mounted) return;
      setState(() {
        _chosenLocation = point;
        _message = null;
      });
      await _controller?.animateCamera(CameraUpdate.newLatLngZoom(point, 16));
      await _updatePin();
    } catch (error) {
      if (mounted) setState(() => _message = '$error');
    }
  }

  Future<void> _updatePin() async {
    if (!_styleLoaded || _controller == null) return;
    await _controller!.clearCircles();
    if (_chosenLocation != null) {
      await _controller!.addCircle(CircleOptions(
        geometry: _chosenLocation,
        circleColor: '#217C5D',
        circleRadius: 13,
        circleStrokeColor: '#FFFFFF',
        circleStrokeWidth: 3,
      ));
    }
  }

  Future<void> _submit() async {
    if (_chosenLocation == null) {
      setState(() => _message = 'Tap the map or use GPS to select a location.');
      return;
    }
    if (_saving) return;
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      await widget.service.report(
        type: _type,
        severity: _severity,
        position: _chosenLocation!,
        description: _description.text,
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _message = 'Could not save report: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Report a hazard'),
              Text('A small action for safer rides',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
            ],
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            if (widget.service.isDemoMode) const DemoNotice(),
            const SizedBox(height: 12),
            const Text('What hazard did you encounter?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in HazardType.values)
                  ChoiceChip(
                    avatar: Icon(hazardIcon(type), size: 18),
                    label: Text(type.label),
                    selected: type == _type,
                    onSelected: (_) => setState(() => _type = type),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            const Text('Severity',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SegmentedButton<Severity>(
              selected: {_severity},
              onSelectionChanged: (selection) =>
                  setState(() => _severity = selection.first),
              segments: [
                for (final severity in Severity.values)
                  ButtonSegment(value: severity, label: Text(severity.label)),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Location',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: _useGps,
                  icon: const Icon(Icons.my_location),
                  label: const Text('Use GPS'),
                ),
              ],
            ),
            const Text('Tap the map to place or move the pin.'),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                height: 260,
                child: MapLibreMap(
                  styleString: 'https://tiles.openfreemap.org/styles/liberty',
                  initialCameraPosition: const CameraPosition(
                    target: LocationService.demoCenter,
                    zoom: 14,
                  ),
                  onMapCreated: (controller) => _controller = controller,
                  onStyleLoadedCallback: () {
                    _styleLoaded = true;
                    _updatePin();
                  },
                  onMapClick: (point, location) {
                    setState(() {
                      _chosenLocation = location;
                      _message = null;
                    });
                    _updatePin();
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _chosenLocation == null
                  ? 'No position selected yet'
                  : 'Pin: ${_chosenLocation!.latitude.toStringAsFixed(5)}, '
                    '${_chosenLocation!.longitude.toStringAsFixed(5)}',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _description,
              maxLength: 300,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Any useful details? (optional)',
                hintText: 'E.g. just before the crosswalk',
              ),
            ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_message!, style: const TextStyle(color: Colors.red)),
              ),
            FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon: const Icon(Icons.send),
              label: Text(_saving ? 'Submitting…' : 'Submit report'),
            ),
            const SizedBox(height: 10),
            const Text('Stop somewhere safe before reporting.',
                style: TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
      );
}
