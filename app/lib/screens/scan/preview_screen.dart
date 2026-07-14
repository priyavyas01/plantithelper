import 'package:flutter/material.dart';
import 'dart:typed_data'; // Uint8List — a list of bytes, used for raw image data

class PreviewScreen extends StatelessWidget {
  // We receive the compressed image as raw bytes (Uint8List).
  // This is more efficient than passing a file path because:
  // - We already have the bytes in memory from compression
  // - No extra disk read needed
  // - Easier to pass to the API later (multipart body expects bytes)
  final Uint8List imageBytes;

  const PreviewScreen({super.key, required this.imageBytes});

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
                // This is different from Image.file (reads from disk) or
                // Image.network (downloads from URL). We use memory because
                // we already have the bytes from compression.
                imageBytes,
                fit: BoxFit.contain, // show the whole image, no cropping
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
                    // Retake — pops back to CaptureScreen (AC-3)
                    // OutlinedButton for secondary action
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
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
                    // Scan — FilledButton for primary action
                    Expanded(
                      flex: 2, // takes twice as much space as Retake
                      child: FilledButton.icon(
                        // Stubbed for now — E2-S3 will wire this to POST /scan
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Scan feature coming soon!'),
                              backgroundColor: Color(0xFF4CAF50),
                            ),
                          );
                        },
                        icon: const Icon(Icons.search),
                        label: const Text('Scan This Plant'),
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
