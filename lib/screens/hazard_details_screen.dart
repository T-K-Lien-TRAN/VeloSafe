import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../models/hazard.dart';
import '../services/hazard_service.dart';
import '../widgets/hazard_marker.dart';

class HazardDetailsScreen extends StatefulWidget {
  const HazardDetailsScreen({
    super.key,
    required this.service,
    required this.hazardId,
  });
  final HazardService service;
  final String hazardId;

  @override
  State<HazardDetailsScreen> createState() => _HazardDetailsScreenState();
}

class _HazardDetailsScreenState extends State<HazardDetailsScreen> {
  MapLibreMapController? _mapController;
  bool _saving = false;

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
  }

  String _age(DateTime date) {
    final difference = DateTime.now().difference(date);
    if (difference.inMinutes < 1) return 'just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
    if (difference.inHours < 24) return '${difference.inHours} h ago';
    return '${difference.inDays} days ago';
  }

  Future<void> _change(Future<void> Function() action) async {
    setState(() => _saving = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report updated.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hazard = widget.service.byId(widget.hazardId);
    if (hazard == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Hazard details')),
        body: const Center(child: Text('This report is unavailable.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Hazard details')),
      body: ListView(
        children: [
          SizedBox(
            height: 275,
            child: MapLibreMap(
              key: ValueKey('detail_${hazard.id}'),
              styleString: 'https://tiles.openfreemap.org/styles/liberty',
              initialCameraPosition: CameraPosition(
                target: hazard.position,
                zoom: 16,
              ),
              onMapCreated: (controller) => _mapController = controller,
              onStyleLoadedCallback: () {
                _mapController?.addCircle(CircleOptions(
                  geometry: hazard.position,
                  circleRadius: 13,
                  circleColor: hazard.severity == Severity.high
                      ? '#C44C43' : '#D69A24',
                  circleStrokeColor: '#FFFFFF',
                  circleStrokeWidth: 3,
                ));
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hazard.isDemo) const DemoNotice(),
                const SizedBox(height: 14),
                Row(children: [
                  HazardMarker(hazard: hazard, size: 52),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(hazard.type.label,
                        style: const TextStyle(
                            fontSize: 25, fontWeight: FontWeight.bold)),
                  ),
                ]),
                const SizedBox(height: 12),
                Text('Location: ${hazard.latitude.toStringAsFixed(5)}, '
                    '${hazard.longitude.toStringAsFixed(5)}'),
                const SizedBox(height: 12),
                Wrap(spacing: 10, children: [
                  Chip(
                    label: Text('${hazard.severity.label} severity'),
                    backgroundColor:
                        severityColor(hazard.severity).withValues(alpha: 0.14),
                  ),
                  Chip(label: Text(hazard.status)),
                  Chip(label: Text('Reported ${_age(hazard.createdAt)}')),
                ]),
                const SizedBox(height: 14),
                Text(
                  hazard.description.isEmpty
                      ? 'No additional description.' : hazard.description,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20),
                ListTile(
                  tileColor: veloPale,
                  leading: const Icon(Icons.people_outline, color: veloGreen),
                  title: Text('Confirmed by ${hazard.confirmations} cyclist(s)'),
                  subtitle: const Text('Community reports are not verified.'),
                ),
                const SizedBox(height: 24),
                if (hazard.isActive)
                  Row(children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _saving
                            ? null
                            : () => _change(() =>
                                widget.service.confirm(hazard.id)),
                        icon: const Icon(Icons.check),
                        label: const Text('Still there'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _saving || !widget.service.canResolve(hazard)
                            ? null
                            : () => _change(() =>
                                widget.service.resolve(hazard.id)),
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Resolved'),
                      ),
                    ),
                  ]),
                if (!widget.service.canResolve(hazard))
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text('Only the reporter can mark this as resolved.'),
                  ),
                const SizedBox(height: 14),
                const Text('Stay alert to traffic. Never use the phone '
                    'while cycling.',
                    style: TextStyle(color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
