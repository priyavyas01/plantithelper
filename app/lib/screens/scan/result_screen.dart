import 'package:flutter/material.dart';
import '../../models/scan_models.dart';
import '../../services/plant_service.dart';
import '../../widgets/health_badge.dart';
import '../../widgets/care_grid.dart';
import '../../theme/app_theme.dart';

class ResultScreen extends StatelessWidget {
  final ScanResult result;

  /// When null → brand-new plant flow (shows Save sheet with name field).
  /// When set  → re-scan flow (shows "Update [plantName]" primary action).
  final String? plantId;
  final String? plantName;

  // Injected for tests. In production: addScan / savePlant.
  final Future<void> Function(String plantId, AddScanRequest)? onAddScan;
  final Future<SavedPlant> Function(SavePlantRequest)? onSave;

  const ResultScreen({
    super.key,
    required this.result,
    this.plantId,
    this.plantName,
    this.onAddScan,
    this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final isReScan = plantId != null && plantName != null;

    // Warn when the scanned plant's first word differs from the saved plant name.
    // E.g. saved "Monstera", scanned "Pothos" — might be a different plant.
    // First-word heuristic avoids false positives on "Monstera Deliciosa" vs "Monstera".
    final bool showDifferentPlantWarning = isReScan &&
        _firstWord(result.commonName).toLowerCase() !=
            _firstWord(plantName!).toLowerCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Result'),
        backgroundColor: AppTheme.green,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showDifferentPlantWarning) ...[
              _DifferentPlantBanner(
                scannedName: result.commonName,
                savedName: plantName!,
              ),
              const SizedBox(height: 16),
            ],
            _PlantHeader(result: result),
            const SizedBox(height: 24),
            CareGrid(care: result.care),
            const SizedBox(height: 32),
            _ResultActions(
              result: result,
              plantId: plantId,
              plantName: plantName,
              onAddScan: onAddScan ?? PlantService.addScan,
              onSave: onSave ?? PlantService.savePlant,
            ),
          ],
        ),
      ),
    );
  }

  static String _firstWord(String name) {
    final trimmed = name.trim();
    final space = trimmed.indexOf(' ');
    return space == -1 ? trimmed : trimmed.substring(0, space);
  }
}

// ---------------------------------------------------------------------------
// Warning banner — shown when the scanned plant name differs from the saved one
// ---------------------------------------------------------------------------

class _DifferentPlantBanner extends StatelessWidget {
  final String scannedName;
  final String savedName;

  const _DifferentPlantBanner({
    required this.scannedName,
    required this.savedName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        border: Border.all(color: Colors.orange[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange[700], size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'This looks like a $scannedName, not your $savedName. '
              'You can still add it or save it as a new plant.',
              style: TextStyle(color: Colors.orange[800], fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Plant header: name, scientific name, health badge + observation
// ---------------------------------------------------------------------------

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
        HealthBadge(health: result.health),
        if (result.healthObservation.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            result.healthObservation,
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
// Action buttons — stateful to track saved/updated state
// ---------------------------------------------------------------------------

class _ResultActions extends StatefulWidget {
  final ScanResult result;
  final String? plantId;
  final String? plantName;
  final Future<void> Function(String, AddScanRequest) onAddScan;
  final Future<SavedPlant> Function(SavePlantRequest) onSave;

  const _ResultActions({
    required this.result,
    required this.plantId,
    required this.plantName,
    required this.onAddScan,
    required this.onSave,
  });

  @override
  State<_ResultActions> createState() => _ResultActionsState();
}

class _ResultActionsState extends State<_ResultActions> {
  bool _done = false;      // true after either action completes successfully
  bool _busy = false;
  String? _errorMessage;

  // Re-scan flow: add scan to existing plant directly — no name needed.
  Future<void> _addScan() async {
    setState(() {
      _busy = true;
      _errorMessage = null;
    });

    final request = AddScanRequest(
      commonName: widget.result.commonName,
      scientificName: widget.result.scientificName,
      confidence: widget.result.confidence,
      health: widget.result.health,
      healthObservation: widget.result.healthObservation,
      care: widget.result.care,
      funFact: widget.result.funFact,
    );

    try {
      await widget.onAddScan(widget.plantId!, request);
      if (!mounted) return;
      setState(() => _done = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scan added to ${widget.plantName!}!'),
          backgroundColor: AppTheme.green,
        ),
      );
    } on PlantSaveException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _errorMessage = 'Something went wrong. Try again.';
      });
    }
  }

  // New plant flow: open name sheet, then POST /plants.
  void _openSaveSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SavePlantSheet(
        result: widget.result,
        onSave: widget.onSave,
        onSaved: () {
          if (!mounted) return;
          setState(() => _done = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Plant saved!'),
              backgroundColor: AppTheme.green,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isReScan = widget.plantId != null && widget.plantName != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.red[50],
              border: Border.all(color: Colors.red[200]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
        ],

        // Primary action — differs by flow
        if (isReScan) ...[
          // Update existing plant
          FilledButton.icon(
            onPressed: (_done || _busy) ? null : _addScan,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Icon(_done ? Icons.check : Icons.update),
            label: Text(_done
                ? 'Scan Added ✓'
                : 'Update ${widget.plantName!}'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.green,
              disabledBackgroundColor: Colors.grey[300],
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 12),
          // Secondary: save as new plant even in re-scan flow
          OutlinedButton.icon(
            onPressed: (_done || _busy) ? null : _openSaveSheet,
            icon: const Icon(Icons.bookmark_add_outlined),
            label: const Text('Save as New Plant'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: AppTheme.green),
              foregroundColor: AppTheme.green,
            ),
          ),
        ] else ...[
          // New plant flow — original save button
          FilledButton.icon(
            onPressed: _done ? null : _openSaveSheet,
            icon: Icon(_done ? Icons.bookmark : Icons.bookmark_add_outlined),
            label: Text(_done ? 'Saved' : 'Save This Plant'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.green,
              disabledBackgroundColor: Colors.grey[300],
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],

        const SizedBox(height: 12),
        OutlinedButton.icon(
          // Pop ResultScreen AND PreviewScreen — lands user on CaptureScreen
          onPressed: () => Navigator.of(context)
            ..pop()
            ..pop(),
          icon: const Icon(Icons.camera_alt_outlined),
          label: const Text('Scan Another Plant'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: const BorderSide(color: AppTheme.green),
            foregroundColor: AppTheme.green,
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () =>
              Navigator.of(context).popUntil(ModalRoute.withName('/home')),
          child: const Text('Done', style: TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Save bottom sheet — name field + save/cancel (new plant flow only)
// ---------------------------------------------------------------------------

class _SavePlantSheet extends StatefulWidget {
  final ScanResult result;
  final Future<SavedPlant> Function(SavePlantRequest) onSave;
  final VoidCallback onSaved;

  const _SavePlantSheet({
    required this.result,
    required this.onSave,
    required this.onSaved,
  });

  @override
  State<_SavePlantSheet> createState() => _SavePlantSheetState();
}

class _SavePlantSheetState extends State<_SavePlantSheet> {
  late final TextEditingController _nameController;
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.result.commonName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final request = SavePlantRequest(
      name: _nameController.text.trim(),
      commonName: widget.result.commonName,
      scientificName: widget.result.scientificName,
      confidence: widget.result.confidence,
      health: widget.result.health,
      healthObservation: widget.result.healthObservation,
      care: widget.result.care,
      funFact: widget.result.funFact,
    );

    try {
      await widget.onSave(request);
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSaved();
    } on PlantSaveException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = 'Something went wrong. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Save Plant',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Plant name',
                border: OutlineInputBorder(),
              ),
              maxLength: 100,
              textCapitalization: TextCapitalization.words,
              enabled: !_isSaving,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please give your plant a name';
                }
                return null;
              },
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _isSaving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.green,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
