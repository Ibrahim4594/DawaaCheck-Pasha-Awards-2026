import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../domain/providers/scan_provider.dart';

class ScanCameraScreen extends ConsumerStatefulWidget {
  const ScanCameraScreen({super.key});

  @override
  ConsumerState<ScanCameraScreen> createState() => _ScanCameraScreenState();
}

class _ScanCameraScreenState extends ConsumerState<ScanCameraScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _beamController;
  final ImagePicker _picker = ImagePicker();
  CameraController? _cameraController;
  bool _isFlashOn = false;
  bool _isCapturing = false;
  bool _showFlash = false;

  final List<String> _stepLabels = [AppStrings.front, AppStrings.back, AppStrings.ingredients];
  final List<String> _captureLabels = [
    AppStrings.captureFrontLabel,
    AppStrings.captureBackLabel,
    AppStrings.captureIngredientsPanel,
  ];
  final List<String> _hintTexts = [
    AppStrings.pointAtFront,
    AppStrings.pointAtBack,
    AppStrings.pointAtIngredients,
  ];

  @override
  void initState() {
    super.initState();
    ref.read(scanProvider.notifier).reset();
    _beamController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
    _initTorch();
  }

  Future<void> _initTorch() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        // Prefer the rear camera — cameras.first is the front (selfie) lens on
        // many phones, which would show the user's face and mis-aim the torch.
        final backCamera = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
          orElse: () => cameras.first,
        );
        _cameraController = CameraController(
          backCamera,
          ResolutionPreset.low,
          enableAudio: false,
        );
        await _cameraController!.initialize();
      }
    } catch (_) {
      // Torch not available (e.g. web or no camera permission)
    }
  }

  Future<void> _toggleFlash() async {
    HapticFeedback.selectionClick();
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      // No camera available, just toggle visual state
      setState(() => _isFlashOn = !_isFlashOn);
      return;
    }
    final newState = !_isFlashOn;
    try {
      await _cameraController!.setFlashMode(
        newState ? FlashMode.torch : FlashMode.off,
      );
      if (mounted) setState(() => _isFlashOn = newState);
    } catch (_) {
      if (mounted) setState(() => _isFlashOn = !_isFlashOn);
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _beamController.dispose();
    super.dispose();
  }

  Future<void> _captureImage() async {
    if (_isCapturing) return;
    setState(() => _isCapturing = true);
    HapticFeedback.mediumImpact();

    // Flash effect
    setState(() => _showFlash = true);
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) setState(() => _showFlash = false);

    // Turn off torch and release camera before ImagePicker takes over
    final wasFlashOn = _isFlashOn;
    if (_isFlashOn && _cameraController?.value.isInitialized == true) {
      try {
        await _cameraController!.setFlashMode(FlashMode.off);
      } catch (_) {}
    }
    await _cameraController?.dispose();
    _cameraController = null;
    if (mounted) setState(() => _isFlashOn = false);

    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 85,
      maxWidth: 1024,
    );

    if (photo != null && mounted) {
      final bytes = await photo.readAsBytes();
      ref.read(scanProvider.notifier).addImage(bytes);

      final scanState = ref.read(scanProvider);
      if (scanState.capturedImages.length == 3) {
        HapticFeedback.heavyImpact();
        if (mounted) context.push('/scan/processing');
        if (mounted) setState(() => _isCapturing = false);
        return;
      }
    }

    // Re-initialize torch control after ImagePicker closes
    if (mounted) {
      await _initTorch();
      // Restore flash state if it was on before
      if (wasFlashOn && _cameraController?.value.isInitialized == true) {
        try {
          await _cameraController!.setFlashMode(FlashMode.torch);
          if (mounted) setState(() => _isFlashOn = true);
        } catch (_) {}
      }
      setState(() => _isCapturing = false);
    }
  }

  /// Pick the current step's photo from the gallery instead of the camera.
  /// Same downstream flow — after the 3rd image the scan starts; photo #1
  /// (front) is what the verdict matcher reads.
  Future<void> _pickFromGallery() async {
    if (_isCapturing) return;
    setState(() => _isCapturing = true);
    HapticFeedback.selectionClick();

    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1024,
      );

      if (photo != null && mounted) {
        final bytes = await photo.readAsBytes();
        ref.read(scanProvider.notifier).addImage(bytes);

        final scanState = ref.read(scanProvider);
        if (scanState.capturedImages.length == 3) {
          HapticFeedback.heavyImpact();
          if (mounted) context.push('/scan/processing');
        }
      }
    } catch (e) {
      debugPrint('[SCAN] gallery pick failed: $e');
    }

    if (mounted) setState(() => _isCapturing = false);
  }

  @override
  Widget build(BuildContext context) {
    final scanState = ref.watch(scanProvider);
    final currentStep = scanState.capturedImages.length.clamp(0, 2);

    return Scaffold(
      backgroundColor: AppColors.scanBackground,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      _buildIconButton(Icons.close_rounded, () => context.pop()),
                      const Spacer(),
                      Text(
                        AppStrings.verifyMedicine,
                        style: AppTextStyles.h4.copyWith(color: AppColors.white, letterSpacing: 0.3),
                      ),
                      const Spacer(),
                      _buildIconButton(
                        _isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                        _toggleFlash,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Step progress
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Row(
                    children: List.generate(5, (i) {
                      if (i.isOdd) {
                        final stepBefore = i ~/ 2;
                        final completed = stepBefore < currentStep;
                        return Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            height: 2,
                            decoration: BoxDecoration(
                              color: completed
                                  ? AppColors.scanAccent
                                  : AppColors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        );
                      }
                      final stepIndex = i ~/ 2;
                      return _buildStepIndicator(stepIndex, currentStep);
                    }),
                  ),
                ),
                // Step labels
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(3, (i) {
                      final isActive = i == currentStep;
                      final isDone = i < currentStep;
                      return Text(
                        '${i + 1}. ${_stepLabels[i]}',
                        style: AppTextStyles.caption.copyWith(
                          color: isActive
                              ? AppColors.scanAccent
                              : isDone
                                  ? AppColors.verified
                                  : AppColors.white.withValues(alpha: 0.35),
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                          fontSize: 11,
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 12),

                // Camera viewfinder
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment.center,
                            radius: 0.8,
                            colors: [
                              AppColors.scanAccent.withValues(alpha: 0.04),
                              AppColors.scanAccent.withValues(alpha: 0.01),
                              Colors.transparent,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: AppColors.scanAccent.withValues(alpha: 0.2),
                            width: 1.5,
                          ),
                        ),
                        child: Stack(
                          children: [
                            // Subtle grid pattern
                            CustomPaint(
                              size: Size.infinite,
                              painter: _GridPainter(
                                color: AppColors.scanAccent.withValues(alpha: 0.04),
                              ),
                            ),

                            // Corner guides — larger, with glow
                            ..._buildCornerGuides(),

                            // Scan beam with enhanced glow
                            AnimatedBuilder(
                              animation: _beamController,
                              builder: (context, child) {
                                final viewHeight = MediaQuery.of(context).size.height * 0.42;
                                return Positioned(
                                  left: 20,
                                  right: 20,
                                  top: _beamController.value * viewHeight,
                                  child: Column(
                                    children: [
                                      // Glow field above beam
                                      Container(
                                        height: 60,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.transparent,
                                              AppColors.scanAccent.withValues(alpha: 0.05),
                                              AppColors.scanAccent.withValues(alpha: 0.1),
                                            ],
                                          ),
                                        ),
                                      ),
                                      // Main beam line
                                      Container(
                                        height: 2.5,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.transparent,
                                              AppColors.scanAccent.withValues(alpha: 0.4),
                                              AppColors.scanAccent,
                                              AppColors.scanAccent.withValues(alpha: 0.4),
                                              Colors.transparent,
                                            ],
                                            stops: const [0, 0.15, 0.5, 0.85, 1],
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.scanAccent.withValues(alpha: 0.6),
                                              blurRadius: 16,
                                              spreadRadius: 2,
                                            ),
                                            BoxShadow(
                                              color: AppColors.scanAccent.withValues(alpha: 0.2),
                                              blurRadius: 40,
                                              spreadRadius: 8,
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Glow field below beam
                                      Container(
                                        height: 30,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              AppColors.scanAccent.withValues(alpha: 0.06),
                                              Colors.transparent,
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),

                            // Center crosshair + hint
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Crosshair ring
                                  Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.scanAccent.withValues(alpha: 0.2),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Center(
                                      child: Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppColors.scanAccent.withValues(alpha: 0.06),
                                          border: Border.all(
                                            color: AppColors.scanAccent.withValues(alpha: 0.15),
                                            width: 1,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.document_scanner_rounded,
                                          color: AppColors.scanAccent.withValues(alpha: 0.5),
                                          size: 22,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  // Hint pill
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: AppColors.scanBackground.withValues(alpha: 0.8),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: AppColors.scanAccent.withValues(alpha: 0.1),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      _hintTexts[currentStep],
                                      style: AppTextStyles.body.copyWith(
                                        color: AppColors.scanAccent.withValues(alpha: 0.7),
                                        fontSize: 12,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Hint chips — Wrap so longer translations (Urdu labels like
                // "مضبوطی سے پکڑیں" are ~2× the width of their English
                // equivalents) flow to the next line instead of overflowing
                // the row.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _HintChip(label: AppStrings.goodLight, icon: Icons.wb_sunny_outlined, isActive: true),
                      _HintChip(label: AppStrings.flatSurface, icon: Icons.crop_landscape_rounded, isActive: false),
                      _HintChip(label: AppStrings.holdSteady, icon: Icons.back_hand_outlined, isActive: false),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Capture button — premium circular design
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Semantics(
                    label: 'Capture medicine photo',
                    child: GestureDetector(
                      onTap: _isCapturing ? null : _captureImage,
                      child: Row(
                        children: [
                          // Capture ring button
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.scanAccent.withValues(alpha: 0.4),
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.scanAccent.withValues(alpha: 0.25),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Container(
                              margin: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Color(0xFF3B9BFF), Color(0xFF1A6FE8)],
                                ),
                              ),
                              child: Icon(
                                Icons.camera_alt_rounded,
                                color: AppColors.white,
                                size: 24,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Label + step info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _captureLabels[currentStep],
                                  style: AppTextStyles.bodySemibold.copyWith(
                                    color: AppColors.white,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${currentStep + 1} / 3',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.white.withValues(alpha: 0.4),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Step badges
                          Row(
                            children: List.generate(3, (i) {
                              final done = i < currentStep;
                              final active = i == currentStep;
                              return Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: done
                                      ? AppColors.verified
                                      : active
                                          ? AppColors.scanAccent
                                          : AppColors.white.withValues(alpha: 0.15),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Upload-from-gallery alternative (reliable for demo / uploads)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isCapturing ? null : _pickFromGallery,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.photo_library_outlined,
                            size: 16,
                            color: AppColors.white.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            AppStrings.uploadFromGallery,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),

          // White flash overlay
          if (_showFlash)
            AnimatedOpacity(
              opacity: _showFlash ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 150),
              child: Container(
                color: AppColors.white.withValues(alpha: 0.85),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.white.withValues(alpha: 0.08), width: 1.5),
        ),
        child: Icon(icon, color: AppColors.white, size: 20),
      ),
    );
  }

  Widget _buildStepIndicator(int stepIndex, int currentStep) {
    final isDone = stepIndex < currentStep;
    final isActive = stepIndex == currentStep;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDone ? AppColors.scanAccent : Colors.transparent,
        border: Border.all(
          color: isDone || isActive ? AppColors.scanAccent : AppColors.white.withValues(alpha: 0.2),
          width: 2,
        ),
        boxShadow: isDone
            ? [
                BoxShadow(
                  color: AppColors.scanAccent.withValues(alpha: 0.3),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
      child: isDone
          ? const Icon(Icons.check_rounded, color: AppColors.white, size: 16)
          : isActive
              ? Center(
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.scanAccent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.scanAccent.withValues(alpha: 0.4),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                )
              : null,
    );
  }

  List<Widget> _buildCornerGuides() {
    const size = 36.0;
    const thickness = 3.0;
    const color = AppColors.scanAccent;

    return [
      Positioned(
        top: 14,
        left: 14,
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(painter: _CornerPainter(color, thickness, _Corner.topLeft)),
        ),
      ),
      Positioned(
        top: 14,
        right: 14,
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(painter: _CornerPainter(color, thickness, _Corner.topRight)),
        ),
      ),
      Positioned(
        bottom: 14,
        left: 14,
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(painter: _CornerPainter(color, thickness, _Corner.bottomLeft)),
        ),
      ),
      Positioned(
        bottom: 14,
        right: 14,
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(painter: _CornerPainter(color, thickness, _Corner.bottomRight)),
        ),
      ),
    ];
  }
}

class _HintChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;

  const _HintChip({required this.label, required this.icon, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.scanAccent.withValues(alpha: 0.15)
            : AppColors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: isActive
            ? Border.all(color: AppColors.scanAccent.withValues(alpha: 0.3), width: 1)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isActive
                ? AppColors.scanAccent
                : AppColors.white.withValues(alpha: 0.4),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: isActive
                  ? AppColors.scanAccent
                  : AppColors.white.withValues(alpha: 0.4),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// Subtle grid overlay for scanner feel
class _GridPainter extends CustomPainter {
  final Color color;
  _GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5;

    const spacing = 40.0;

    // Vertical lines
    for (double x = spacing; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    // Horizontal lines
    for (double y = spacing; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

enum _Corner { topLeft, topRight, bottomLeft, bottomRight }

class _CornerPainter extends CustomPainter {
  final Color color;
  final double thickness;
  final _Corner corner;

  _CornerPainter(this.color, this.thickness, this.corner);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    switch (corner) {
      case _Corner.topLeft:
        path.moveTo(0, size.height);
        path.lineTo(0, 0);
        path.lineTo(size.width, 0);
      case _Corner.topRight:
        path.moveTo(0, 0);
        path.lineTo(size.width, 0);
        path.lineTo(size.width, size.height);
      case _Corner.bottomLeft:
        path.moveTo(0, 0);
        path.lineTo(0, size.height);
        path.lineTo(size.width, size.height);
      case _Corner.bottomRight:
        path.moveTo(0, size.height);
        path.lineTo(size.width, size.height);
        path.lineTo(size.width, 0);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
