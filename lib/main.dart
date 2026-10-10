import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/hazard_details_screen.dart';
import 'screens/map_screen.dart';
import 'screens/report_hazard_screen.dart';
import 'screens/route_screen.dart';
import 'screens/safety_score_screen.dart';
import 'services/hazard_service.dart';
import 'widgets/bottom_navigation.dart';
import 'widgets/hazard_marker.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  SupabaseClient? client;
  try {
    if (supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty) {
      await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);
      client = Supabase.instance.client;
      if (client.auth.currentUser == null) {
        // Turn on Anonymous Sign-ins in Supabase Authentication settings.
        await client.auth.signInAnonymously();
      }
    } else if (supabaseUrl.isNotEmpty || supabaseKey.isNotEmpty) {
      throw StateError('Provide BOTH SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY.');
    }
  } catch (error) {
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(child: Padding(
          padding: const EdgeInsets.all(24),
          child: SelectableText('Supabase setup failed:\n$error'),
        )),
      ),
    ));
    return;
  }

  runApp(VeloSafeApp(hazardService: HazardService(client: client)));
}

class VeloSafeApp extends StatefulWidget {
  const VeloSafeApp({super.key, required this.hazardService});
  final HazardService hazardService;

  @override
  State<VeloSafeApp> createState() => _VeloSafeAppState();
}

class _VeloSafeAppState extends State<VeloSafeApp> {
  int _tabIndex = 0;

  @override
  void dispose() {
    widget.hazardService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'VéloSafe',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: veloGreen),
          scaffoldBackgroundColor: Colors.white,
          appBarTheme: const AppBarTheme(
            foregroundColor: veloText,
            backgroundColor: Colors.white,
          ),
        ),
        home: Builder(
          builder: (appContext) => Scaffold(
            body: switch (_tabIndex) {
              0 => MapScreen(
                  service: widget.hazardService,
                  onReport: () => Navigator.of(appContext).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ReportHazardScreen(
                        service: widget.hazardService,
                      ),
                    ),
                  ),
                  onHazardSelected: (hazard) =>
                      Navigator.of(appContext).push(MaterialPageRoute<void>(
                    builder: (_) => HazardDetailsScreen(
                      service: widget.hazardService,
                      hazardId: hazard.id,
                    ),
                  )),
                  onShowZones: () => setState(() => _tabIndex = 1),
                  onShowRoutes: () => setState(() => _tabIndex = 2),
                ),
              1 => SafetyScoreScreen(service: widget.hazardService),
              _ => RouteScreen(service: widget.hazardService),
            },
            bottomNavigationBar: VeloBottomNavigation(
              index: _tabIndex,
              onSelected: (index) => setState(() => _tabIndex = index),
            ),
          ),
        ),
      );
}
