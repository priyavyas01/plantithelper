import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_it_helper/screens/scan/capture_screen.dart';
import 'package:plant_it_helper/screens/scan/preview_screen.dart';

Widget _wrap(Widget child) => MaterialApp(home: child);

// The smallest valid JPEG (a 1x1 white pixel).
// Hardcoded so tests don't need the filesystem or image_picker.
Uint8List _minimalJpegBytes() {
  return Uint8List.fromList([
    0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
    0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43,
    0x00, 0x08, 0x06, 0x06, 0x07, 0x06, 0x05, 0x08, 0x07, 0x07, 0x07, 0x09,
    0x09, 0x08, 0x0A, 0x0C, 0x14, 0x0D, 0x0C, 0x0B, 0x0B, 0x0C, 0x19, 0x12,
    0x13, 0x0F, 0x14, 0x1D, 0x1A, 0x1F, 0x1E, 0x1D, 0x1A, 0x1C, 0x1C, 0x20,
    0x24, 0x2E, 0x27, 0x20, 0x22, 0x2C, 0x23, 0x1C, 0x1C, 0x28, 0x37, 0x29,
    0x2C, 0x30, 0x31, 0x34, 0x34, 0x34, 0x1F, 0x27, 0x39, 0x3D, 0x38, 0x32,
    0x3C, 0x2E, 0x33, 0x34, 0x32, 0xFF, 0xC0, 0x00, 0x0B, 0x08, 0x00, 0x01,
    0x00, 0x01, 0x01, 0x01, 0x11, 0x00, 0xFF, 0xC4, 0x00, 0x1F, 0x00, 0x00,
    0x01, 0x05, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
    0x09, 0x0A, 0x0B, 0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3F,
    0x00, 0xFB, 0xD2, 0x8A, 0x00, 0xFF, 0xD9,
  ]);
}

void main() {
  group('CaptureScreen', () {
    testWidgets('shows Camera and Gallery buttons', (tester) async {
      await tester.pumpWidget(_wrap(const CaptureScreen()));
      expect(find.text('Take a Photo'), findsOneWidget);
      expect(find.text('Choose from Gallery'), findsOneWidget);
    });

    testWidgets('shows title and instructions', (tester) async {
      await tester.pumpWidget(_wrap(const CaptureScreen()));
      expect(find.text('Scan a Plant'), findsOneWidget);
      expect(find.text('Take or choose a photo'), findsOneWidget);
    });
  });

  group('PreviewScreen', () {
    testWidgets('shows image and action buttons', (tester) async {
      await tester.pumpWidget(_wrap(PreviewScreen(imageBytes: _minimalJpegBytes())));
      expect(find.text('Retake'), findsOneWidget);
      expect(find.text('Scan This Plant'), findsOneWidget);
      expect(find.text('Does this look good?'), findsOneWidget);
    });

    testWidgets('Retake pops navigation', (tester) async {
      final bytes = _minimalJpegBytes();
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (ctx) => TextButton(
            onPressed: () => Navigator.of(ctx).push(
              MaterialPageRoute(builder: (_) => PreviewScreen(imageBytes: bytes)),
            ),
            child: const Text('Go'),
          ),
        ),
      ));

      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();
      expect(find.text('Retake'), findsOneWidget);

      await tester.tap(find.text('Retake'));
      await tester.pumpAndSettle();
      expect(find.text('Retake'), findsNothing);
    });
  });
}
