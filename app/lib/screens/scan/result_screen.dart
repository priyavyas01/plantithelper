import 'package:flutter/material.dart';
import '../../models/scan_models.dart';
import '../../services/plant_service.dart';
import '../../widgets/health_badge.dart';
import '../../widgets/care_grid.dart';
import '../../theme/app_theme.dart';

class ResultScreen extends StatelessWidget {
  final ScanResult result;

  // onSave is injectable for widget tests. Defaults to PlantService.savePlant in production.
  final Future<SavedPlant> Function(SavePlantRequest)? onSave;

  const ResultScreen({super.key, required this.result, this.onSave});

  @override
  Widget build(BuildContext context) {
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
            _PlantHeader(result: result),
            const SizedBox(height: 24),
            CareGrid(care: result.care),
            const SizedBox(height: 32),
            _ResultActions(
              result: result,
              onSave: onSave ?? PlantService.savePlant,
            ),
          ],
        ),
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
// Action buttons — stateful to track saved state
// ---------------------------------------------------------------------------

class _ResultActions extends StatefulWidget {
  final ScanResult result;
  final Future<SavedPlant> Function(SavePlantRequest) onSave;

  const _ResultActions({required this.result, required this.onSave});

  @override
  State<_ResultActions> createState() => _ResultActionsState();
}

class _ResultActionsState extends State<_ResultActions> {
  bool _saved = false;

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
        onSaved: _onSaveSuccess,
      ),
    );
  }

  // Called by the sheet after a successful save.
  // Runs in this widget's context — safe to update state and show a snackbar.
  void _onSaveSuccess() {
    if (!mounted) return;
    setState(() => _saved = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Plant saved!'),
        backgroundColor: AppTheme.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: _saved ? null : _openSaveSheet,
          icon: Icon(_saved ? Icons.bookmark : Icons.bookmark_add_outlined),
          label: Text(_saved ? 'Saved' : 'Save This Plant'),
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.green,
            disabledBackgroundColor: Colors.grey[300],
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
            side: const BorderSide(color: AppTheme.green),
            foregroundColor: AppTheme.green,
          ),
        ),
        const SizedBox(height: 12),
        // BUG-001 fix: clears the entire scan stack in one tap.
        // popUntil walks back through the route stack until it finds /home,
        // so the user always lands on MyPlantsScreen regardless of how deep
        // the scan flow pushed them.
        TextButton(
          onPressed: () => Navigator.of(context)
              .popUntil(ModalRoute.withName('/home')),
          child: const Text(
            'Done',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Save bottom sheet — name field + save/cancel buttons
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
    // Pre-fill with common name — user can rename it
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
      Navigator.of(context).pop(); // close the sheet
      widget.onSaved();            // parent: update button + show snackbar
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
    // Padding adjusts for the keyboard so the sheet scrolls up
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
              // Disabled while saving prevents double-tap duplicate rows
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
