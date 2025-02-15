import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final inputPath = 'c:/Users/ASUS/Desktop/my app/assets/App_icon.jpg';
  final outputPath = 'c:/Users/ASUS/Desktop/my app/assets/App_icon.png';

  final bytes = File(inputPath).readAsBytesSync();
  final image = img.decodeImage(bytes);

  if (image != null) {
    final pngBytes = img.encodePng(image);
    File(outputPath).writeAsBytesSync(pngBytes);
    print('Image converted successfully');
  } else {
    print('Failed to decode image');
  }
}
