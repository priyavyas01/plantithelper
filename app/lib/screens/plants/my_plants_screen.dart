import 'package:flutter/material.dart';
import '../../models/scan_models.dart';
import '../../services/plant_service.dart';
import '../../services/token_service.dart';
import '../scan/capture_screen.dart';
import 'plant_detail_screen.dart';
import '../../theme/app_theme.dart';
import '../../widgets/health_badge.dart';

class MyPlantsScreen extends StatefulWidget {
  // Injectable for tests. In production this is null and _loadPlants falls
  // back to PlantService.getPlants.
  final Future<PlantListResult> Function()? getPlants;

  // Increment this from a parent widget to trigger a data reload.
  // Used by HomeScreen after returning from the Scan tab so the list
  // reflects any newly saved plant without requiring a pull-to-refresh.
  final int reloadTrigger;

  const MyPlantsScreen({super.key, this.getPlants, this.reloadTrigger = 0});

  @override
  State<MyPlantsScreen> createState() => _MyPlantsScreenState();
}

class _MyPlantsScreenState extends State<MyPlantsScreen> {
  List<PlantListItem> _plants = [];
  bool _isLoading = true;
  bool _fromCache = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPlants();
  }

  @override
  void didUpdateWidget(MyPlantsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reloadTrigger != oldWidget.reloadTrigger) {
      debugPrint('[MyPlantsScreen] reloadTrigger changed — reloading plants');
      _loadPlants();
    }
  }

  Future<void> _loadPlants() async {
    debugPrint('[MyPlantsScreen] loading plants');
    setState(() {
      _isLoading = true;
      _error = null;
      _fromCache = false;
    });
    try {
      final fetch = widget.getPlants ?? PlantService.getPlants;
      final result = await fetch();
      if (!mounted) return;
      debugPrint(
        '[MyPlantsScreen] loaded ${result.plants.length} plants '
        '(fromCache=${result.fromCache})',
      );
      setState(() {
        _plants = result.plants;
        _fromCache = result.fromCache;
        _isLoading = false;
      });
    } on PlantFetchException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        debugPrint('[MyPlantsScreen] session expired — redirecting to login');
        await TokenService.clearTokens();
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/login');
        return;
      }
      debugPrint('[MyPlantsScreen] fetch error: ${e.message}');
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('[MyPlantsScreen] unexpected error: $e');
      setState(() {
        _error = 'Could not load plants. Pull to refresh.';
        _isLoading = false;
      });
    }
  }

  Future<void> _navigateToScan() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CaptureScreen()),
    );
    if (mounted) _loadPlants();
  }

  Future<void> _logout() async {
    PlantService.clearCache();
    await TokenService.clearTokens();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Plants'),
        backgroundColor: AppTheme.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: _logout,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadPlants,
        color: AppTheme.green,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const _LoadingSkeleton();
    if (_error != null) {
      return _ErrorState(message: _error!, onRetry: _loadPlants);
    }
    if (_plants.isEmpty) {
      return _EmptyState(onScanPressed: _navigateToScan);
    }
    return _PlantList(
      plants: _plants,
      fromCache: _fromCache,
      onRefresh: _loadPlants,
    );
  }
}

// ---------------------------------------------------------------------------
// Loading skeleton
// ---------------------------------------------------------------------------

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      key: const Key('loading_skeleton'),
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, _) => Container(
        height: 88,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  final VoidCallback onScanPressed;
  const _EmptyState({required this.onScanPressed});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(40),
      children: [
        const SizedBox(height: 60),
        const Icon(Icons.eco_outlined, size: 72, color: AppTheme.green),
        const SizedBox(height: 24),
        Text(
          'You have no plants yet.',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Scan your first one!',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Colors.grey[600]),
        ),
        const SizedBox(height: 32),
        FilledButton.icon(
          onPressed: onScanPressed,
          icon: const Icon(Icons.camera_alt_outlined),
          label: const Text('Scan a Plant'),
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.green,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Error state
// ---------------------------------------------------------------------------

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(40),
      children: [
        const SizedBox(height: 60),
        const Icon(Icons.wifi_off_outlined, size: 64, color: Colors.grey),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(color: Colors.grey[700]),
        ),
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: onRetry,
          child: const Text('Try Again'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Plant list
// ---------------------------------------------------------------------------

class _PlantList extends StatelessWidget {
  final List<PlantListItem> plants;
  final bool fromCache;
  final VoidCallback? onRefresh;
  const _PlantList({
    required this.plants,
    required this.fromCache,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    // When showing cached data, prepend a banner as the first list item so
    // it scrolls away naturally and does not block the FAB.
    final itemCount = plants.length + (fromCache ? 1 : 0);

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (fromCache && index == 0) return const _CacheBanner();
        final plant = plants[fromCache ? index - 1 : index];
        return PlantCard(plant: plant, onRefresh: onRefresh);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Cache banner — shown at the top of the list when offline data is displayed.
// ---------------------------------------------------------------------------

class _CacheBanner extends StatelessWidget {
  const _CacheBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off_rounded, size: 18, color: Colors.amber[800]),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Could not refresh. Showing last saved data.',
              style: TextStyle(fontSize: 13, color: Colors.amber[900]),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PlantCard — public so tests can find it directly.
// ---------------------------------------------------------------------------

class PlantCard extends StatelessWidget {
  final PlantListItem plant;
  final VoidCallback? onRefresh;
  const PlantCard({super.key, required this.plant, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final deleted = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => PlantDetailScreen(plantId: plant.id),
            ),
          );
          if (deleted == true) onRefresh?.call();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.eco, color: AppTheme.green),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plant.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      plant.scientificName,
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    _BottomRow(plant: plant),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomRow extends StatelessWidget {
  final PlantListItem plant;
  const _BottomRow({required this.plant});

  @override
  Widget build(BuildContext context) {
    final savedAgo = AppTheme.timeAgo(plant.createdAt);
    return Row(
      children: [
        Text(
          'Saved $savedAgo',
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
        const Spacer(),
        HealthBadge(health: plant.health),
      ],
    );
  }
}
