import 'dart:io';
import 'package:image/image.dart';

void main() {
  final String basePath = r'c:\Users\ASUS\Desktop\my app';
  final String sourceIconPath = '$basePath\\assets\\App_icon.jpg';
  final Map<String, int> sizes = {
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192,
  };

  // Read source image
  final sourceImage = decodeImage(File(sourceIconPath).readAsBytesSync());
  if (sourceImage == null) {
    print('Failed to load source image');
    return;
  }

  // Convert to PNG and resize for each density
  for (var entry in sizes.entries) {
    final resized = copyResize(sourceImage,
        width: entry.value,
        height: entry.value,
        interpolation: Interpolation.average);
    final png = encodePng(resized);
    final String outputPath =
        '$basePath\\android\\app\\src\\main\\res\\mipmap-${entry.key}\\ic_launcher.png';
    File(outputPath).writeAsBytesSync(png);
    print('Generated icon for ${entry.key}');
  }
}
