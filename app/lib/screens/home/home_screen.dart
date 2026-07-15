import 'package:flutter/material.dart';
import '../plants/my_plants_screen.dart';

/// HomeScreen is the shell that the '/home' route lands on.
/// All content is delegated to MyPlantsScreen which handles its own
/// lifecycle, data loading, and logout.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const MyPlantsScreen();
  }
}
