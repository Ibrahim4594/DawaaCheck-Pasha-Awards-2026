/// A single recognised text line (shared by the mobile + web OCR backends).
class OcrLine {
  final String text;
  final double height;
  final double top;
  const OcrLine(this.text, this.height, this.top);
}
