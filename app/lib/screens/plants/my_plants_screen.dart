import 'package:flutter/material.dart';
import '../../models/scan_models.dart';
import '../../services/plant_service.dart';
import '../../services/token_service.dart';
import '../scan/capture_screen.dart';
import 'plant_detail_screen.dart';
import '../../theme/app_theme.dart';

class MyPlantsScreen extends StatefulWidget {
  // Injectable for tests — mirrors the onSave pattern in ResultScreen.
  // In production this is null and _loadPlants falls back to PlantService.getPlants.
  final Future<List<PlantListItem>> Function()? getPlants;

  const MyPlantsScreen({super.key, this.getPlants});

  @override
  State<MyPlantsScreen> createState() => _MyPlantsScreenState();
}

class _MyPlantsScreenState extends State<MyPlantsScreen> {
  List<PlantListItem> _plants = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPlants();
  }

  Future<void> _loadPlants() async {
    debugPrint('[MyPlantsScreen] loading plants');
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final fetch = widget.getPlants ?? PlantService.getPlants;
      final plants = await fetch();
      if (!mounted) return;
      debugPrint('[MyPlantsScreen] loaded ${plants.length} plants');
      setState(() {
        _plants = plants;
        _isLoading = false;
      });
    } on PlantFetchException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        debugPrint('[MyPlantsScreen] session expired, redirecting to login');
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

  // Navigates to CaptureScreen and reloads list when user returns.
  // `await` means this method waits until the pushed route is popped.
  Future<void> _navigateToScan() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CaptureScreen()),
    );
    if (mounted) _loadPlants();
  }

  Future<void> _logout() async {
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
      // RefreshIndicator wraps the scrollable content.
      // When the user pulls down, it calls _loadPlants() again.
      body: RefreshIndicator(
        onRefresh: _loadPlants,
        color: AppTheme.green,
        child: _buildBody(),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.green,
        foregroundColor: Colors.white,
        tooltip: 'Scan a plant',
        onPressed: _navigateToScan,
        child: const Icon(Icons.camera_alt_outlined),
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
    return _PlantList(plants: _plants, onRefresh: _loadPlants);
  }
}

// ---------------------------------------------------------------------------
// Loading skeleton — three placeholder cards while the API is in-flight.
// ---------------------------------------------------------------------------

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
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
// Empty state — shown when the user has not saved any plants yet.
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  final VoidCallback onScanPressed;
  const _EmptyState({required this.onScanPressed});

  @override
  Widget build(BuildContext context) {
    // ListView (not Column) so RefreshIndicator works — it needs a scrollable child.
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
// Error state — shown when the network call fails.
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
// Plant list — shown when plants have loaded.
// ListView.builder is lazy: it only builds cards currently visible on screen.
// If you have 100 plants, only ~8 are built at once, saving memory.
// ---------------------------------------------------------------------------

class _PlantList extends StatelessWidget {
  final List<PlantListItem> plants;
  final VoidCallback? onRefresh;
  const _PlantList({required this.plants, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: plants.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) =>
          PlantCard(plant: plants[index], onRefresh: onRefresh),
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
        // Only flag uncertain IDs. Health badge replaces this in E8-S1.
        if (plant.confidence == 'low') ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.orange),
            ),
            child: const Text(
              'Uncertain ID',
              style: TextStyle(
                fontSize: 11,
                color: Colors.orange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
