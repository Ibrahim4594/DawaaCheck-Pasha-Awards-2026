// ignore_for_file: avoid_print
// One-off: compute the 8x8 average-hash of every bundled reference medicine
// front image and print a Dart const map (key -> 16-char hex). Run with:
//   dart run tool/gen_ahash.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

List<bool>? aHash(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final cw = (decoded.width * 0.6).round().clamp(1, decoded.width);
  final ch = (decoded.height * 0.6).round().clamp(1, decoded.height);
  final cx = ((decoded.width - cw) / 2).round();
  final cy = ((decoded.height - ch) / 2).round();
  final cropped = img.copyCrop(decoded, x: cx, y: cy, width: cw, height: ch);
  final small = img.copyResize(img.grayscale(cropped), width: 8, height: 8);
  final lums = <double>[];
  double sum = 0;
  for (var y = 0; y < 8; y++) {
    for (var x = 0; x < 8; x++) {
      final l = small.getPixel(x, y).luminance.toDouble();
      lums.add(l);
      sum += l;
    }
  }
  final mean = sum / lums.length;
  return [for (final l in lums) l >= mean];
}

String toHex(List<bool> bits) {
  final buf = StringBuffer();
  for (var i = 0; i < 64; i += 4) {
    var nibble = 0;
    for (var j = 0; j < 4; j++) {
      nibble = (nibble << 1) | (bits[i + j] ? 1 : 0);
    }
    buf.write(nibble.toRadixString(16));
  }
  return buf.toString();
}

void main() {
  final entries = Directory('assets/reference_packs')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.jpg'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  print('const Map<String, String> kRefHashes = {');
  for (final f in entries) {
    final key = f.uri.pathSegments.last.replaceAll('.jpg', '');
    final bits = aHash(f.readAsBytesSync());
    if (bits != null) print("  '$key': '${toHex(bits)}',");
  }
  print('};');
}
