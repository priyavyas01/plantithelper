import 'package:flutter/material.dart';
import '../../models/scan_models.dart';

class ResultScreen extends StatelessWidget {
  final ScanResult result;

  const ResultScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Result'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PlantHeader(result: result),
            const SizedBox(height: 24),
            _CareGrid(care: result.care),
            const SizedBox(height: 32),
            _ActionButtons(),
          ],
        ),
      ),
    );
  }
}

class _PlantHeader extends StatelessWidget {
  final ScanResult result;

  const _PlantHeader({required this.result});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          result.commonName,
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          result.scientificName,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: Colors.grey[600],
              ),
        ),
        const SizedBox(height: 12),
        _ConfidenceBadge(confidence: result.confidence),
      ],
    );
  }
}

class _ConfidenceBadge extends StatelessWidget {
  final String confidence;

  const _ConfidenceBadge({required this.confidence});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (confidence) {
      'high' => ('High confidence', const Color(0xFF4CAF50)),
      'medium' => ('Medium confidence', Colors.orange),
      _ => ('Low confidence', Colors.red),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
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

class _CareGrid extends StatelessWidget {
  final CareInfo care;

  const _CareGrid({required this.care});

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
            _CareCard(icon: Icons.wb_sunny_outlined, label: 'Light', value: care.light),
            _CareCard(icon: Icons.water_drop_outlined, label: 'Water', value: care.water),
            _CareCard(icon: Icons.cloud_outlined, label: 'Humidity', value: care.humidity),
            _CareCard(icon: Icons.thermostat, label: 'Temperature', value: care.temperature),
          ],
        ),
      ],
    );
  }
}

class _CareCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _CareCard({required this.icon, required this.label, required this.value});

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
              Icon(icon, size: 16, color: const Color(0xFF4CAF50)),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4CAF50),
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

class _ActionButtons extends StatelessWidget {
  const _ActionButtons();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          // E2-S4 will implement saving — stub for now
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Save feature coming in the next story!'),
              backgroundColor: Color(0xFF4CAF50),
            ),
          ),
          icon: const Icon(Icons.bookmark_add_outlined),
          label: const Text('Save This Plant'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          // Pop ResultScreen AND PreviewScreen — lands user back on CaptureScreen
          onPressed: () => Navigator.of(context)
            ..pop()
            ..pop(),
          icon: const Icon(Icons.camera_alt_outlined),
          label: const Text('Scan Another Plant'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: const BorderSide(color: Color(0xFF4CAF50)),
            foregroundColor: const Color(0xFF4CAF50),
          ),
        ),
      ],
    );
  }
}
