import 'package:flutter/material.dart';

import 'hazard_marker.dart';

class SafetyScoreCard extends StatelessWidget {
  const SafetyScoreCard({
    super.key,
    required this.score,
    required this.reportCount,
    this.compact = false,
  });

  final int score;
  final int reportCount;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.all(compact ? 12 : 18),
        decoration: BoxDecoration(
          color: veloPale,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$score / 100',
              style: TextStyle(
                fontSize: compact ? 25 : 34,
                fontWeight: FontWeight.w800,
                color: veloGreen,
              ),
            ),
            const Text('Safety Score', style: TextStyle(color: veloGreen)),
            if (!compact) ...[
              const SizedBox(height: 8),
              Text('$reportCount recent reports'),
            ],
          ],
        ),
      );
}
