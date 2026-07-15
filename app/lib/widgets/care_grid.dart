import 'package:flutter/material.dart';
import '../models/scan_models.dart';
import '../theme/app_theme.dart';

/// Shared 2×2 care guide grid.
/// Used on both ResultScreen and PlantDetailScreen.
class CareGrid extends StatelessWidget {
  final CareInfo care;
  const CareGrid({super.key, required this.care});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Care Guide',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.3,
          children: [
            CareCard(icon: Icons.wb_sunny_outlined, label: 'Light', value: care.light),
            CareCard(icon: Icons.water_drop_outlined, label: 'Water', value: care.water),
            CareCard(icon: Icons.cloud_outlined, label: 'Humidity', value: care.humidity),
            CareCard(icon: Icons.thermostat, label: 'Temperature', value: care.temperature),
          ],
        ),
      ],
    );
  }
}

/// Single care attribute card used inside [CareGrid].
class CareCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const CareCard({super.key, required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppTheme.green),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
