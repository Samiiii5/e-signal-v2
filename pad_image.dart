import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final file = File('design/logo_onboarding.png');
  if (!file.existsSync()) {
    print('Image not found');
    return;
  }
  
  final image = img.decodePng(file.readAsBytesSync());
  if (image == null) {
    print('Failed to decode image');
    return;
  }
  
  final size = image.width > image.height ? image.width : image.height;
  // Android 12 recommends a padded icon. Let's make the canvas even bigger so it's not cropped by the circle mask.
  final canvasSize = (size * 1.5).toInt();
  
  // Create a white square image
  final canvas = img.Image(width: canvasSize, height: canvasSize, numChannels: 4);
  img.fill(canvas, color: img.ColorRgba8(255, 255, 255, 255));
  
  // Draw the original image in the center
  final dstX = (canvasSize - image.width) ~/ 2;
  final dstY = (canvasSize - image.height) ~/ 2;
  
  img.compositeImage(canvas, image, dstX: dstX, dstY: dstY);
  
  // Save the new image
  File('design/logo_onboarding_square.png').writeAsBytesSync(img.encodePng(canvas));
  print('Image padded successfully!');
}
