import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;

void main() async {
  final sourceIconPath = path.join('assets', 'App_icon.png');
  final sourceIcon = File(sourceIconPath);

  if (!await sourceIcon.exists()) {
    print('Source icon not found at: $sourceIconPath');
    return;
  }

  final sourceImage = img.decodePng(await sourceIcon.readAsBytes());
  if (sourceImage == null) {
    print('Failed to decode source image');
    return;
  }

  final Map<String, int> sizes = {
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192,
  };

  for (var entry in sizes.entries) {
    final resized = img.copyResize(sourceImage,
        width: entry.value,
        height: entry.value,
        interpolation: img.Interpolation.linear);

    final targetPath = path.join('android', 'app', 'src', 'main', 'res',
        'mipmap-${entry.key}', 'ic_launcher.png');

    await File(targetPath).writeAsBytes(img.encodePng(resized));
    print('Generated icon for ${entry.key}: $targetPath');
  }
}
