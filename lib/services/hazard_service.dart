import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/hazard.dart';

class HazardService extends ChangeNotifier {
  HazardService({SupabaseClient? client}) : _client = client {
    if (client == null) {
      _hazards = _sampleHazards();
    } else {
      _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        unawaited(refresh());
      });
      _subscription = client.from('hazards').stream(primaryKey: ['id']).listen(
        (rows) {
          if (!_disposed) _acceptRows(rows);
        },
        onError: (Object exception) {
          if (_disposed) return;
          error = 'Cannot load hazard reports: $exception';
          notifyListeners();
        },
      );
    }
  }

  final SupabaseClient? _client;
  StreamSubscription<List<Map<String, dynamic>>>? _subscription;
  Timer? _pollTimer;
  bool _disposed = false;
  bool _refreshing = false;
  List<Hazard> _hazards = [];
  String? error;

  bool get isDemoMode => _client == null;
  List<Hazard> get hazards => List.unmodifiable(_hazards);
  Hazard? byId(String id) {
    for (final hazard in _hazards) {
      if (hazard.id == id) return hazard;
    }
    return null;
  }

  void _acceptRows(List<Map<String, dynamic>> rows) {
    _hazards = rows.map(Hazard.fromJson).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    error = null;
    notifyListeners();
  }

  // Polling also recovers after a missed event or disabled Realtime replication.
  Future<void> refresh() async {
    if (_client == null || _disposed || _refreshing) return;
    _refreshing = true;
    try {
      final rows = await _client.from('hazards').select()
          .order('created_at', ascending: false);
      if (!_disposed) _acceptRows(rows);
    } catch (exception) {
      if (!_disposed) {
        error = 'Cannot refresh reports. Check your connection and database setup.';
        notifyListeners();
      }
    } finally {
      _refreshing = false;
    }
  }

  bool canResolve(Hazard hazard) => isDemoMode ||
      (_client?.auth.currentUser?.id != null &&
          _client!.auth.currentUser!.id == hazard.reporterId);

  Future<void> report({
    required HazardType type,
    required Severity severity,
    required LatLng position,
    required String description,
  }) async {
    final newHazard = Hazard(
      id: 'demo_${DateTime.now().microsecondsSinceEpoch}',
      type: type,
      severity: severity,
      latitude: position.latitude,
      longitude: position.longitude,
      description: description.trim(),
      createdAt: DateTime.now(),
      isDemo: isDemoMode,
    );
    if (isDemoMode) {
      _hazards = [newHazard, ..._hazards];
      notifyListeners();
      return;
    }
    final row = await _client!.from('hazards')
        .insert(newHazard.toInsertJson()).select().single();
    if (_disposed) return;
    final saved = Hazard.fromJson(row);
    _hazards = [saved, ..._hazards.where((hazard) => hazard.id != saved.id)];
    error = null;
    notifyListeners();
  }

  Future<void> confirm(String id) async {
    final hazard = byId(id);
    if (hazard == null || !hazard.isActive) return;
    if (isDemoMode) {
      _replace(hazard.copyWith(confirmations: hazard.confirmations + 1));
      return;
    }
    await _client!.rpc('confirm_hazard', params: {'p_hazard_id': id});
    await _reloadHazard(id);
  }

  Future<void> resolve(String id) async {
    final hazard = byId(id);
    if (hazard == null || !hazard.isActive) return;
    if (!canResolve(hazard)) {
      throw StateError('Only the reporter may resolve this hazard.');
    }
    if (isDemoMode) {
      _replace(hazard.copyWith(status: 'resolved'));
      return;
    }
    final row = await _client!
        .from('hazards')
        .update({'status': 'resolved'})
        .eq('id', id)
        .select()
        .single();
    if (!_disposed) _replace(Hazard.fromJson(row));
  }

  Future<void> _reloadHazard(String id) async {
    final row = await _client!.from('hazards').select().eq('id', id).single();
    if (!_disposed) _replace(Hazard.fromJson(row));
  }

  void _replace(Hazard changed) {
    _hazards = [
      for (final hazard in _hazards)
        if (hazard.id == changed.id) changed else hazard,
    ];
    notifyListeners();
  }

  static List<Hazard> _sampleHazards() {
    final now = DateTime.now();
    return [
      Hazard(
        id: 'demo_1',
        type: HazardType.pothole,
        severity: Severity.moderate,
        latitude: 43.7110,
        longitude: 7.2630,
        description: 'Sample pothole. Stop somewhere safe before reporting.',
        createdAt: now.subtract(const Duration(minutes: 25)),
        confirmations: 3,
        isDemo: true,
      ),
      Hazard(
        id: 'demo_2',
        type: HazardType.roadworks,
        severity: Severity.high,
        latitude: 43.7085,
        longitude: 7.2640,
        description: 'Sample roadworks warning.',
        createdAt: now.subtract(const Duration(hours: 4)),
        isDemo: true,
      ),
      Hazard(
        id: 'demo_3',
        type: HazardType.blockedLane,
        severity: Severity.low,
        latitude: 43.7097,
        longitude: 7.2601,
        description: 'Sample blocked lane warning.',
        createdAt: now.subtract(const Duration(days: 1)),
        isDemo: true,
      ),
      Hazard(
        id: 'demo_4',
        type: HazardType.intersection,
        severity: Severity.moderate,
        latitude: 43.7122,
        longitude: 7.2605,
        description: 'Sample dangerous intersection warning.',
        createdAt: now.subtract(const Duration(days: 2)),
        isDemo: true,
      ),
    ];
  }

  @override
  void dispose() {
    _disposed = true;
    _pollTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}
