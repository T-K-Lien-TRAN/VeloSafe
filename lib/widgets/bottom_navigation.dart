import 'package:flutter/material.dart';

import 'hazard_marker.dart';

class VeloBottomNavigation extends StatelessWidget {
  const VeloBottomNavigation({
    super.key,
    required this.index,
    required this.onSelected,
  });

  final int index;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => NavigationBar(
        selectedIndex: index,
        onDestinationSelected: onSelected,
        backgroundColor: Colors.white,
        indicatorColor: veloPale,
        height: 74,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map, color: veloGreen),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            selectedIcon: Icon(Icons.shield, color: veloGreen),
            label: 'Zones',
          ),
          NavigationDestination(
            icon: Icon(Icons.alt_route_outlined),
            selectedIcon: Icon(Icons.alt_route, color: veloGreen),
            label: 'Routes',
          ),
        ],
      );
}
