import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Displays a coloured dot + label showing a plant's health status.
///
/// Four states match what Claude returns:
///   healthy          → green  — "Healthy"
///   needs_attention  → amber  — "Needs Attention"
///   concerning       → red    — "Concerning"
///   unknown          → grey   — "Unknown"
///
/// Unlike ConfidenceBadge (which was an AI metric), HealthBadge shows
/// something meaningful to the user: how this plant looks right now.
class HealthBadge extends StatelessWidget {
  final String health;

  const HealthBadge({super.key, required this.health});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (health) {
      'healthy' => ('Healthy', AppTheme.green),
      'needs_attention' => ('Needs Attention', Colors.amber.shade700),
      'concerning' => ('Concerning', Colors.red.shade600),
      _ => ('Unknown', Colors.grey.shade500),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}
