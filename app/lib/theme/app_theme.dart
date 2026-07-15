import 'package:flutter/material.dart';

/// Single source of truth for brand colours and helpers.
/// Import this instead of hardcoding Color(0xFF4CAF50) everywhere.
abstract final class AppTheme {
  /// Primary brand green used throughout the app.
  static const Color green = Color(0xFF4CAF50);

  /// Human-readable relative time string for a past [DateTime].
  /// Used on plant cards and the detail screen.
  static String timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 30) return '${diff.inDays} days ago';
    return '${(diff.inDays / 30).floor()} months ago';
  }
}
