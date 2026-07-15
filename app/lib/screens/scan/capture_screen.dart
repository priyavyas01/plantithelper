import 'package:flutter/material.dart';
import 'package:flutter/services.dart';             // PlatformException — thrown by image_picker on permission denial
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'preview_screen.dart';
import '../../theme/app_theme.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  // ImagePicker is the package that talks to the OS camera/gallery APIs.
  // We create one instance and reuse it — it's stateless so this is fine.
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;
  String? _permissionMessage; // shown when user denies permission

  // Called when user taps Camera or Gallery.
  // ImageSource.camera opens the camera.
  // ImageSource.gallery opens the photo picker.
  Future<void> _pickImage(ImageSource source) async {
    setState(() {
      _isLoading = true;
      _permissionMessage = null;
    });

    try {
      // pickImage returns an XFile (cross-platform file) or null if user cancelled.
      // maxWidth/maxHeight is a first-pass resize done by the OS before we even
      // get the bytes — saves memory on huge raw camera photos.
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 90, // 0-100, OS-level JPEG quality before we compress further
      );

      // User cancelled (tapped back/cancel in camera or gallery) — just return
      if (picked == null) return;

      // Read the file as bytes so we can compress it
      final bytes = await picked.readAsBytes();

      // flutter_image_compress reduces the file size without visible quality loss.
      // minWidth/minHeight: minimum output size (won't upscale small images).
      // quality: JPEG compression quality (85 is a good balance).
      // Result is Uint8List (raw bytes) or null if compression fails.
      final compressed = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 512,
        minHeight: 512,
        quality: 85,
        format: CompressFormat.jpeg,
      );

      // Compressed result — always non-null with flutter_image_compress >= 1.0.
      final imageBytes = compressed;

      if (mounted) {
        // Navigate to preview screen, passing the compressed bytes.
        // We don't use named routes here because we need to pass data (the image).
        // MaterialPageRoute with builder is the standard way to pass data between screens.
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PreviewScreen(imageBytes: imageBytes),
          ),
        );
      }
    } on PlatformException catch (e) {
      // image_picker throws PlatformException with specific error codes:
      // "camera_access_denied" on iOS, "camera_access_denied_without_prompt" etc.
      // Checking the code is more reliable than string-matching the message.
      final isDenied = e.code.contains('denied') || e.code.contains('permission');
      if (isDenied) {
        setState(() => _permissionMessage =
            'Access was denied. Go to Settings → PlantIt Helper to enable it.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan a Plant'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.eco, size: 64, color: AppTheme.green),
              const SizedBox(height: 12),
              Text(
                'Take or choose a photo',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Get a clear, well-lit photo of the plant\nfor the best identification results.',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 40),

              // Permission denied message (AC-4)
              if (_permissionMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    border: Border.all(color: Colors.orange[200]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _permissionMessage!,
                        style: TextStyle(color: Colors.orange[800]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Camera button
              _PickerButton(
                icon: Icons.camera_alt_outlined,
                label: 'Take a Photo',
                sublabel: 'Use your camera',
                onTap: _isLoading ? null : () => _pickImage(ImageSource.camera),
              ),
              const SizedBox(height: 16),

              // Gallery button
              _PickerButton(
                icon: Icons.photo_library_outlined,
                label: 'Choose from Gallery',
                sublabel: 'Pick an existing photo',
                onTap: _isLoading ? null : () => _pickImage(ImageSource.gallery),
              ),

              if (_isLoading) ...[
                const SizedBox(height: 32),
                const Center(
                  child: CircularProgressIndicator(color: AppTheme.green),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Extracted into its own widget to keep the build method readable.
// This is a common Flutter pattern — if a widget is reused or complex, extract it.
class _PickerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final VoidCallback? onTap; // null = disabled

  const _PickerButton({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(
            color: onTap == null ? Colors.grey[300]! : AppTheme.green,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 32,
                color: onTap == null ? Colors.grey : AppTheme.green),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: onTap == null ? Colors.grey : null,
                    )),
                Text(sublabel,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              ],
            ),
            const Spacer(),
            Icon(Icons.chevron_right,
                color: onTap == null ? Colors.grey[300] : Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}
