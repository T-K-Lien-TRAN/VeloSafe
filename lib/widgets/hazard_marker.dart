import 'package:flutter/material.dart';

import '../models/hazard.dart';

const Color veloGreen = Color(0xFF217C5D);
const Color veloPale = Color(0xFFE8F5EF);
const Color veloText = Color(0xFF173F34);

Color severityColor(Severity severity) => switch (severity) {
      Severity.low => const Color(0xFFDC9B22),
      Severity.moderate => const Color(0xFFE0931B),
      Severity.high => const Color(0xFFC44C43),
    };

IconData hazardIcon(HazardType type) => switch (type) {
      HazardType.pothole => Icons.error_outline,
      HazardType.roadworks => Icons.construction,
      HazardType.blockedLane => Icons.no_crash_outlined,
      HazardType.intersection => Icons.warning_amber_rounded,
    };

class HazardMarker extends StatelessWidget {
  const HazardMarker({super.key, required this.hazard, this.size = 42});

  final Hazard hazard;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: severityColor(hazard.severity),
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5)],
        ),
        child: Icon(hazardIcon(hazard.type), color: Colors.white),
      );
}

class DemoNotice extends StatelessWidget {
  const DemoNotice({super.key, this.text = 'Sample reports • not verified'});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: veloPale,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: const TextStyle(color: veloGreen, fontSize: 12),
        ),
      );
}
