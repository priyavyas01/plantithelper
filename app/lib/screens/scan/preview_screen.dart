import 'dart:developer' as dev;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../services/scan_service.dart';
import '../../services/token_service.dart';
import 'result_screen.dart';

class PreviewScreen extends StatefulWidget {
  // We receive the compressed image as raw bytes (Uint8List).
  // This is more efficient than passing a file path because:
  // - We already have the bytes in memory from compression
  // - No extra disk read needed
  // - multipart/form-data body expects bytes directly
  final Uint8List imageBytes;

  const PreviewScreen({super.key, required this.imageBytes});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  bool _isScanning = false;
  String? _errorMessage;

  Future<void> _scan() async {
    setState(() {
      _isScanning = true;
      _errorMessage = null;
    });

    dev.log(
      'scan button tapped | size_bytes=${widget.imageBytes.length}',
      name: 'PreviewScreen',
    );

    final token = await TokenService.getAccessToken();
    if (token == null) {
      dev.log('scan aborted | no access token in storage', name: 'PreviewScreen');
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _errorMessage = 'Session expired. Please log in again.';
      });
      return;
    }

    try {
      final result = await ScanService.scanPlant(
        imageBytes: widget.imageBytes,
        accessToken: token,
      );
      if (!mounted) return;
      dev.log(
        'navigating to ResultScreen | name="${result.commonName}"',
        name: 'PreviewScreen',
      );
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ResultScreen(result: result)),
      );
    } on ScanException catch (e) {
      dev.log(
        'scan error | status=${e.statusCode} message=${e.message}',
        name: 'PreviewScreen',
        error: e,
      );
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } finally {
      // In the success path _isScanning is still true here — reset it so
      // the button is re-enabled if the user pops back from ResultScreen.
      if (mounted && _isScanning) {
        setState(() => _isScanning = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // extendBodyBehindAppBar: true lets the image go behind the app bar
      // for a more immersive preview feel
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Image takes up most of the screen
          Expanded(
            child: Container(
              width: double.infinity,
              color: Colors.black,
              child: Image.memory(
                // Image.memory decodes raw JPEG/PNG bytes and renders them.
                // We use memory (not Image.file) because we already have the
                // bytes from compression — no extra disk read needed.
                widget.imageBytes,
                fit: BoxFit.contain,
              ),
            ),
          ),

          // Bottom action bar
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Error banner — only shown when scan fails
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  'Does this look good?',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Make sure the plant is clearly visible and in focus.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    // Retake — disabled while scanning to prevent navigation race
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isScanning ? null : () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retake'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Color(0xFF4CAF50)),
                          foregroundColor: const Color(0xFF4CAF50),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Scan — primary action, takes twice as much space as Retake
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _isScanning ? null : _scan,
                        icon: _isScanning
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.search),
                        // Label changes to 'Try Again' after an error
                        label: Text(_errorMessage != null ? 'Try Again' : 'Scan This Plant'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
