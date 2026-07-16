import 'package:flutter/material.dart';
import '../plants/my_plants_screen.dart';
import '../scan/capture_screen.dart';
import '../../theme/app_theme.dart';

/// HomeScreen is the persistent navigation shell for the '/home' route.
///
/// It owns a [NavigationBar] with two destinations:
///   0 — My Plants  (MyPlantsScreen)
///   1 — Scan       (navigates to CaptureScreen, does not swap the body)
///
/// The Scan tab works differently from My Plants: tapping it pushes
/// CaptureScreen onto the navigator stack rather than swapping the body.
/// This keeps the scan flow's own back-stack intact and lets "Back to My Plants"
/// on ResultScreen pop back to this shell cleanly.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  int _reloadTrigger = 0;

  void _onDestinationTapped(int index) {
    if (index == 1) {
      // Scan tab — push CaptureScreen rather than swapping the body.
      // On return, snap back to My Plants and signal it to reload so
      // any newly saved plant appears without requiring pull-to-refresh.
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const CaptureScreen()))
          .then((_) => setState(() {
                _selectedIndex = 0;
                _reloadTrigger++;
              }));
      return;
    }
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // My Plants is the only persistent body — scan is a pushed route.
      body: MyPlantsScreen(reloadTrigger: _reloadTrigger),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onDestinationTapped,
        indicatorColor: AppTheme.green.withValues(alpha: 0.15),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.eco_outlined),
            selectedIcon: Icon(Icons.eco, color: AppTheme.green),
            label: 'My Plants',
          ),
          NavigationDestination(
            icon: Icon(Icons.camera_alt_outlined),
            selectedIcon: Icon(Icons.camera_alt, color: AppTheme.green),
            label: 'Scan',
          ),
        ],
      ),
    );
  }
}
