import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../models/bike_route.dart';
import '../models/hazard.dart';
import '../services/address_search_service.dart';
import '../services/hazard_service.dart';
import '../services/location_service.dart';
import '../services/routing_service.dart';
import '../widgets/hazard_marker.dart';
import '../widgets/safety_score_card.dart';

class RouteScreen extends StatefulWidget {
  const RouteScreen({super.key, required this.service});

  final HazardService service;

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> {
  static const _routing = RoutingService();
  final _addressSearch = AddressSearchService();
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();

  MapLibreMapController? _controller;
  LatLng _origin = LocationService.demoCenter;
  LatLng? _lastGpsOrigin;
  LatLng? _destination;
  AddressSuggestion? _selectedOrigin;
  AddressSuggestion? _selectedDestination;
  bool _destinationFromMap = false;
  bool _originIsDemo = true;
  String _originDescription = 'Sample point in Nice (GPS unavailable)';
  bool _styleLoaded = false;
  bool _loading = false;
  bool _searchingAddress = false;
  String? _error;
  List<BikeRoute> _routes = [];
  int _selectedRoute = 0;
  int _originRevision = 0;

  BikeRoute? get _route => _routes.isEmpty ? null : _routes[_selectedRoute];

  @override
  void initState() {
    super.initState();
    widget.service.addListener(_onHazardsUpdated);
    _locate();
  }

  @override
  void dispose() {
    widget.service.removeListener(_onHazardsUpdated);
    _addressSearch.dispose();
    _originController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  void _onHazardsUpdated() {
    if (!mounted) return;
    setState(() => _routes = []);
    _draw();
  }

  void _onAddressEdited({required bool origin}) {
    setState(() {
      _routes = [];
      _error = null;
      if (origin) {
        _originRevision++;
        _selectedOrigin = null;
        if (_originController.text.trim().isEmpty) {
          _origin = _lastGpsOrigin ?? LocationService.demoCenter;
          _originIsDemo = _lastGpsOrigin == null;
          _originDescription = _lastGpsOrigin == null
              ? 'Sample point in Nice (GPS unavailable)'
              : 'Your current GPS position';
        }
      } else {
        _selectedDestination = null;
        _destination = null;
        _destinationFromMap = false;
      }
    });
    _draw();
  }

  Future<void> _locate() async {
    // Do not overwrite a typed address if GPS finishes loading afterward.
    final requestRevision = ++_originRevision;
    try {
      final position = await LocationService().currentPosition();
      if (!mounted || requestRevision != _originRevision) return;
      setState(() {
        _originController.clear();
        _selectedOrigin = null;
        _origin = position;
        _lastGpsOrigin = position;
        _originIsDemo = false;
        _originDescription = 'Your current GPS position';
        _routes = [];
        _error = null;
      });
      await _controller?.animateCamera(
        CameraUpdate.newLatLngZoom(position, 13),
      );
      await _draw();
    } catch (error) {
      if (mounted && requestRevision == _originRevision) {
        setState(() {
          _originDescription = 'Sample point in Nice (GPS unavailable)';
          _originIsDemo = true;
          _error = 'GPS unavailable. Type your origin address instead.';
        });
      }
    }
  }

  /// Search only after a button press, not on every keystroke. This avoids
  /// excessive requests to the shared public Photon demo server.
  Future<AddressSuggestion?> _chooseAddress(String query) async {
    if (query.trim().length < 3) {
      setState(() => _error = 'Enter at least 3 characters of the address.');
      return null;
    }

    setState(() {
      _searchingAddress = true;
      _error = null;
    });
    try {
      final results = await _addressSearch.search(query);
      if (!mounted) return null;
      if (results.isEmpty) {
        setState(() => _error = 'Address not found. Add a city or postcode.');
        return null;
      }
      // Explicit selection avoids silently routing to the wrong match.
      return await showDialog<AddressSuggestion>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Select the correct address'),
          content: SizedBox(
            width: 440,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: results.length,
              itemBuilder: (_, index) {
                final suggestion = results[index];
                return ListTile(
                  leading: const Icon(Icons.place_outlined),
                  title: Text(suggestion.label),
                  onTap: () => Navigator.pop(dialogContext, suggestion),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = 'Address search error: $error');
      return null;
    } finally {
      if (mounted) setState(() => _searchingAddress = false);
    }
  }

  Future<bool> _resolveField({required bool origin}) async {
    final controller = origin ? _originController : _destinationController;
    final query = controller.text.trim();

    if (origin && query.isEmpty) return true; // Use GPS or labeled demo point.
    if (!origin && _destinationFromMap && _destination != null) return true;
    if (query.isEmpty) {
      setState(() => _error = 'Enter a destination address or pin it on the map.');
      return false;
    }

    final cached = origin ? _selectedOrigin : _selectedDestination;
    if (cached != null && cached.label == query) return true;
    final suggestion = await _chooseAddress(query);
    if (!mounted || suggestion == null) return false;

    setState(() {
      if (origin) {
        _origin = suggestion.position;
        _selectedOrigin = suggestion;
        _originIsDemo = false;
        _originDescription = 'Typed address';
        _originController.text = suggestion.label;
      } else {
        _destination = suggestion.position;
        _destinationFromMap = false;
        _selectedDestination = suggestion;
        _destinationController.text = suggestion.label;
      }
      _routes = [];
    });
    await _draw();
    return true;
  }

  Future<void> _getRoute() async {
    if (_loading || _searchingAddress) return;
    setState(() {
      _loading = true;
      _routes = [];
      _error = null;
    });
    try {
      if (!await _resolveField(origin: true)) return;
      if (!await _resolveField(origin: false)) return;
      if (!mounted) return;
      final destination = _destination;
      if (destination == null) {
        setState(() => _error = 'Select a destination first.');
        return;
      }
      final candidates = await _routing.routeCandidates(
        origin: _origin,
        destination: destination,
        hazards: widget.service.hazards,
      );
      if (!mounted) return;
      setState(() {
        _routes = candidates;
        _selectedRoute = 0;
      });
      await _draw();
      await _centerBetweenPoints();
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not calculate route: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _centerBetweenPoints() async {
    final destination = _destination;
    if (_controller == null || destination == null) return;
    final center = LatLng(
      (_origin.latitude + destination.latitude) / 2,
      (_origin.longitude + destination.longitude) / 2,
    );
    final meters = LocationService.distanceMeters(_origin, destination);
    final zoom = meters > 200000
        ? 6.0
        : meters > 40000
            ? 9.0
            : meters > 10000
                ? 11.0
                : meters > 3000
                    ? 12.0
                    : 14.0;
    await _controller!.animateCamera(CameraUpdate.newLatLngZoom(center, zoom));
  }

  Future<void> _draw() async {
    if (!_styleLoaded || _controller == null) return;
    try {
      await _controller!.clearLines();
      await _controller!.clearCircles();
      if (_route != null) {
        await _controller!.addLine(LineOptions(
          geometry: _route!.points,
          lineColor: _route!.isPreview ? '#999999' : '#217C5D',
          lineWidth: 6,
        ));
        for (final hazard in _route!.nearbyHazards) {
          if (!mounted) return;
          await _controller!.addCircle(CircleOptions(
            geometry: hazard.position,
            circleRadius: 10,
            circleColor: hazard.severity == Severity.high
                ? '#C44C43'
                : '#D69A24',
            circleStrokeColor: '#FFFFFF',
            circleStrokeWidth: 2,
          ));
        }
      }
      await _controller!.addCircle(CircleOptions(
        geometry: _origin,
        circleColor: '#2977BB',
        circleRadius: 9,
        circleStrokeColor: '#FFFFFF',
        circleStrokeWidth: 3,
      ));
      if (_destination != null) {
        await _controller!.addCircle(CircleOptions(
          geometry: _destination!,
          circleColor: '#217C5D',
          circleRadius: 10,
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 3,
        ));
      }
    } catch (error) {
      if (mounted) setState(() => _error = 'Map error: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final route = _route;
    final busy = _loading || _searchingAddress;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const ListTile(
          title: Text('Your route',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          subtitle: Text('By bike • Compare routes by recent reports'),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _originController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: 'Origin address',
                  hintText: 'e.g. 10 Avenue Jean Médecin, Nice',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.radio_button_checked,
                      color: Colors.blue),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Find origin address',
                        onPressed: busy
                            ? null
                            : () => _resolveField(origin: true),
                        icon: const Icon(Icons.search),
                      ),
                      IconButton(
                        tooltip: 'Use current GPS location',
                        onPressed: busy ? null : _locate,
                        icon: const Icon(Icons.my_location),
                      ),
                    ],
                  ),
                ),
                onChanged: (_) => _onAddressEdited(origin: true),
                onSubmitted: (_) {
                  if (!busy) _resolveField(origin: true);
                },
              ),
              const SizedBox(height: 4),
              Text(
                _originController.text.trim().isEmpty
                    ? 'If empty: $_originDescription'
                    : _selectedOrigin == null
                        ? 'Tap search to select the origin address.'
                        : 'Selected: ${_selectedOrigin!.label}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _destinationController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: 'Destination address',
                  hintText: 'e.g. Place Masséna, Nice, France',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.place_outlined,
                      color: Colors.green),
                  suffixIcon: IconButton(
                    tooltip: 'Find destination address',
                    onPressed: busy
                        ? null
                        : () => _resolveField(origin: false),
                    icon: const Icon(Icons.search),
                  ),
                ),
                onChanged: (_) => _onAddressEdited(origin: false),
                onSubmitted: (_) {
                  if (!busy) _resolveField(origin: false);
                },
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: busy ? null : _getRoute,
                  icon: const Icon(Icons.alt_route),
                  label: Text(busy ? 'Searching…' : 'Find bicycle route'),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 310,
          child: Stack(children: [
            MapLibreMap(
              styleString: 'https://tiles.openfreemap.org/styles/liberty',
              initialCameraPosition: const CameraPosition(
                target: LocationService.demoCenter,
                zoom: 13,
              ),
              onMapCreated: (controller) => _controller = controller,
              onStyleLoadedCallback: () {
                _styleLoaded = true;
                _draw();
              },
              onMapLongClick: (_, location) {
                setState(() {
                  _destination = location;
                  _destinationFromMap = true;
                  _selectedDestination = null;
                  _destinationController.text =
                      'Map pin (${location.latitude.toStringAsFixed(5)}, '
                      '${location.longitude.toStringAsFixed(5)})';
                  _routes = [];
                });
                _draw();
              },
            ),
            const Positioned(
              left: 12,
              top: 10,
              child: Chip(label: Text('Or long-press map for destination')),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
              if (widget.service.error != null)
                Text(widget.service.error!,
                    style: const TextStyle(color: Colors.red)),
              if (widget.service.isDemoMode) const DemoNotice(),
              const SizedBox(height: 12),
              if (route == null)
                const Text('Type an origin and destination, or use GPS and '
                    'a map pin. Then tap Find bicycle route.')
              else if (route.isPreview) ...[
                const Text('Illustrative straight-line preview',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('No OpenRouteService key is configured. '
                    'This grey line is NOT a cycling route and must not be '
                    'used for navigation.'),
              ] else ...[
                const Text('Recommended route',
                    style:
                        TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
                if (_originIsDemo)
                  const Text('Origin is a sample point, not your GPS position.'),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: Text(
                      '${(route.durationSeconds / 60).ceil()} min  •  '
                      '${(route.distanceMeters / 1000).toStringAsFixed(2)} km',
                      style: const TextStyle(fontSize: 17),
                    ),
                  ),
                  SafetyScoreCard(
                    score: route.safetyScore,
                    reportCount: route.nearbyHazards.length,
                    compact: true,
                  ),
                ]),
                const SizedBox(height: 14),
                Text('${route.nearbyHazards.length} active recent hazard(s) '
                    'within 30 m of this route'),
                if (_routes.length > 1) ...[
                  const SizedBox(height: 10),
                  Wrap(spacing: 6, children: [
                    for (var i = 0; i < _routes.length; i++)
                      ChoiceChip(
                        label: Text('Option ${i + 1} '
                            '(${_routes[i].safetyScore}/100)'),
                        selected: i == _selectedRoute,
                        onSelected: (_) {
                          setState(() => _selectedRoute = i);
                          _draw();
                        },
                      ),
                  ]),
                ],
                const SizedBox(height: 12),
                const Text('Score = 100 − penalties from active reports '
                    'in the last 7 days (low 2, moderate 5, high 10).'),
                const SizedBox(height: 10),
                const Text('The score is experimental and cannot guarantee '
                    'a safe or hazard-free ride. Turn-by-turn navigation '
                    'is not implemented in this MVP.',
                    style: TextStyle(color: Colors.black54)),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.navigation_outlined),
                  label: const Text('Start ride (coming later)'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
