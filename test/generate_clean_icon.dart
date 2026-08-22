import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final file = File('c:/Users/Admin/Desktop/music/app icon.png');
  final bytes = file.readAsBytesSync();
  final image = img.decodeImage(bytes)!;

  final width = image.width;
  final height = image.height;

  // In Android notification bar:
  // - Background must be 100% transparent.
  // - The drawing (headphones, ghost outline, eyes, smile, bubbles) is WHITE (alpha = 255).
  // - The white background is TRANSPARENT (alpha = 0).

  final notifIcon = img.Image(width: width, height: height, numChannels: 4);

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final p = image.getPixel(x, y);
      final r = p.r.toInt();
      final g = p.g.toInt();
      final b = p.b.toInt();

      // If it's a dark/black line or feature (headphones, ghost outline, eyes, mouth, bubbles)
      if (r < 180 || g < 180 || b < 180) {
        final lum = 255 - ((r + g + b) ~/ 3);
        notifIcon.setPixelRgba(x, y, 255, 255, 255, lum);
      } else {
        // Transparent
        notifIcon.setPixelRgba(x, y, 0, 0, 0, 0);
      }
    }
  }

  // Find exact bounding box of the ghost drawing (ignoring empty transparent edges)
  int minX = width, maxX = 0, minY = height, maxY = 0;
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final a = notifIcon.getPixel(x, y).a.toInt();
      if (a > 30) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }

  print('Ghost drawing bounds: ($minX, $minY) to ($maxX, $maxY) -> size: ${maxX - minX}x${maxY - minY}');

  // Crop tightly around the ghost
  final cropped = img.copyCrop(
    notifIcon,
    x: minX,
    y: minY,
    width: maxX - minX + 1,
    height: maxY - minY + 1,
  );

  // Put in a square canvas with 20% transparent padding so it doesn't touch the circular notification boundary
  final maxDim = cropped.width > cropped.height ? cropped.width : cropped.height;
  final canvasSize = (maxDim * 1.35).round();

  final finalIcon = img.Image(width: canvasSize, height: canvasSize, numChannels: 4);
  img.fill(finalIcon, color: img.ColorRgba8(0, 0, 0, 0));

  final posX = (canvasSize - cropped.width) ~/ 2;
  final posY = (canvasSize - cropped.height) ~/ 2;
  img.compositeImage(finalIcon, cropped, dstX: posX, dstY: posY);

  // Save preview
  File('c:/Users/Admin/Desktop/music/test/notif_preview.png').writeAsBytesSync(img.encodePng(finalIcon));

  // Save to all Android res drawable and mipmap folders
  final resDir = Directory('c:/Users/Admin/Desktop/music/android/app/src/main/res');
  final notifSizes = {
    'drawable': 96,
    'drawable-mdpi': 24,
    'drawable-hdpi': 36,
    'drawable-xhdpi': 48,
    'drawable-xxhdpi': 72,
    'drawable-xxxhdpi': 96,
  };

  for (final entry in notifSizes.entries) {
    final dir = Directory('${resDir.path}/${entry.key}');
    if (!dir.existsSync()) dir.createSync(recursive: true);

    final resized = img.copyResize(finalIcon, width: entry.value, height: entry.value, interpolation: img.Interpolation.cubic);
    final pngBytes = img.encodePng(resized);
    File('${dir.path}/ic_stat_music.png').writeAsBytesSync(pngBytes);
    File('${dir.path}/ic_notification.png').writeAsBytesSync(pngBytes);
    print('Saved ${dir.path}/ic_stat_music.png (${entry.value}x${entry.value})');
  }

  print('Clean notification icon generated successfully!');
}
