import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Coloured badge showing scan confidence level.
/// Used on both ResultScreen and PlantDetailScreen.
class ConfidenceBadge extends StatelessWidget {
  final String confidence;
  const ConfidenceBadge({super.key, required this.confidence});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (confidence) {
      'high' => ('High confidence', AppTheme.green),
      'medium' => ('Medium confidence', Colors.orange),
      _ => ('Low confidence', Colors.red),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
