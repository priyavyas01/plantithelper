import 'package:flutter/material.dart';
import '../../models/scan_models.dart';
import '../../services/plant_service.dart';
import '../../widgets/health_badge.dart';
import '../../widgets/care_grid.dart';
import '../../theme/app_theme.dart';

// PlantDetailScreen fetches full plant data by ID and displays:
//   - plant name + scientific name + health badge + observation
//   - full care guide (2×2 grid)
//   - care tips list
//   - optional fun fact
//   - saved date
//   - delete option in the AppBar overflow menu
class PlantDetailScreen extends StatefulWidget {
  final String plantId;
  final Future<PlantDetail> Function(String)? getPlant;
  final Future<void> Function(String)? deletePlant;

  const PlantDetailScreen({
    super.key,
    required this.plantId,
    this.getPlant,
    this.deletePlant,
  });

  @override
  State<PlantDetailScreen> createState() => _PlantDetailScreenState();
}

class _PlantDetailScreenState extends State<PlantDetailScreen> {
  PlantDetail? _plant;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    debugPrint('[PlantDetailScreen] loading plant id=${widget.plantId}');
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final fetch = widget.getPlant ?? PlantService.getPlant;
      final plant = await fetch(widget.plantId);
      if (!mounted) return;
      setState(() {
        _plant = plant;
        _loading = false;
      });
      debugPrint('[PlantDetailScreen] loaded: ${plant.name}');
    } on PlantFetchException catch (e) {
      debugPrint('[PlantDetailScreen] fetch error: ${e.message}');
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[PlantDetailScreen] unexpected error: $e');
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong. Please try again.';
        _loading = false;
      });
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete plant'),
        content: Text(
          'Remove "${_plant?.name ?? 'this plant'}" from your collection? '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    debugPrint('[PlantDetailScreen] deleting plant id=${widget.plantId}');
    try {
      final del = widget.deletePlant ?? PlantService.deletePlant;
      await del(widget.plantId);
      if (!mounted) return;
      debugPrint('[PlantDetailScreen] deleted plant id=${widget.plantId}');
      Navigator.of(context).pop(true); // true signals caller to refresh list
    } on PlantFetchException catch (e) {
      debugPrint('[PlantDetailScreen] delete error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete: ${e.message}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_plant?.name ?? 'Plant Details'),
        actions: [
          if (_plant != null)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'delete') _confirmDelete();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _ErrorView(message: _error!, onRetry: _load);
    }

    final plant = _plant!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PlantHeader(plant: plant),
          const SizedBox(height: 24),
          CareGrid(care: plant.care),
          const SizedBox(height: 24),
          _TipsSection(tips: plant.care.tips),
          if (plant.funFact != null) ...[
            const SizedBox(height: 24),
            _FunFactSection(funFact: plant.funFact!),
          ],
          const SizedBox(height: 24),
          _SavedDateRow(savedAt: plant.createdAt),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header: name, scientific name, health badge + observation
// ---------------------------------------------------------------------------

class _PlantHeader extends StatelessWidget {
  final PlantDetail plant;
  const _PlantHeader({required this.plant});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          plant.name,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          plant.scientificName,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontStyle: FontStyle.italic, color: Colors.grey[600]),
        ),
        const SizedBox(height: 10),
        HealthBadge(health: plant.health),
        if (plant.healthObservation.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            plant.healthObservation,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[700],
                  fontStyle: FontStyle.italic,
                ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tips bulleted list
// ---------------------------------------------------------------------------

class _TipsSection extends StatelessWidget {
  final List<String> tips;
  const _TipsSection({required this.tips});

  @override
  Widget build(BuildContext context) {
    if (tips.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Care Tips',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...tips.map(
          (tip) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ',
                    style: TextStyle(
                        color: AppTheme.green, fontWeight: FontWeight.bold)),
                Expanded(child: Text(tip)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Fun fact card
// ---------------------------------------------------------------------------

class _FunFactSection extends StatelessWidget {
  final String funFact;
  const _FunFactSection({required this.funFact});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Fun Fact',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold, color: Colors.amber[800])),
          const SizedBox(height: 6),
          Text(funFact),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Saved date row
// ---------------------------------------------------------------------------

class _SavedDateRow extends StatelessWidget {
  final DateTime savedAt;
  const _SavedDateRow({required this.savedAt});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey),
        const SizedBox(width: 6),
        Text(
          AppTheme.timeAgo(savedAt),
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Error state
// ---------------------------------------------------------------------------

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
