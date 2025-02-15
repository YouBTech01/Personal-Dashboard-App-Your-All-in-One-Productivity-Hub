import 'dart:io';
import 'package:image/image.dart';

void main() {
  final Map<String, int> sizes = {
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192,
  };

  final String basePath = r'c:\Users\ASUS\Desktop\my app';
  final String sourceIconPath = '$basePath\\assets\\App_icon.jpg';
  final sourceImage = decodeImage(File(sourceIconPath).readAsBytesSync());

  if (sourceImage == null) {
    print('Failed to load source image');
    return;
  }

  for (var entry in sizes.entries) {
    final resized =
        copyResize(sourceImage, width: entry.value, height: entry.value);
    final outputPath =
        '$basePath\\android\\app\\src\\main\\res\\mipmap-${entry.key}\\ic_launcher.png';
    File(outputPath).writeAsBytesSync(encodePng(resized));
    print('Generated icon for ${entry.key}');
  }
}
