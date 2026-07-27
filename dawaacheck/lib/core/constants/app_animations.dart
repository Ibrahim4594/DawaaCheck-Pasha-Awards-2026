/// Lottie animation asset paths (in `assets/animations/`).
class AppAnimations {
  AppAnimations._();

  static const String _base = 'assets/animations';

  /// White + blue shield-check — verified / safe moments.
  static const String shieldCheck = '$_base/shield-check.json';

  /// 3D robot — the AI "thinking" hero during a scan.
  static const String robot = '$_base/robot-3d.json';

  /// Scanning beam / document scan — capture & processing.
  static const String scanning = '$_base/scanning.json';
  static const String docScan = '$_base/doc-scan.json';

  /// Empty-box state.
  static const String empty = '$_base/empty-state.json';

  /// Lock shield — privacy / security.
  static const String lockShield = '$_base/lock-shield.json';
}
