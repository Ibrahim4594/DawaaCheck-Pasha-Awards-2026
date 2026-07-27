import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// The DawaaCheck brand mark — blue scan-frame shield with a green check.
///
/// Renders the real logo asset in a white, hairline-bordered rounded tile so it
/// reads as an intentional brand plate on any light surface (the raw asset has
/// a white background, which would otherwise blend into the app background).
class BrandLogo extends StatelessWidget {
  final double size;

  /// Corner radius of the tile. Defaults to a size-proportional value.
  final double? radius;

  /// When false, shows the bare image with no tile/border (for dark or already
  /// framed surfaces).
  final bool framed;

  const BrandLogo({
    super.key,
    this.size = 96,
    this.radius,
    this.framed = true,
  });

  static const String asset = 'assets/icons/dawacheck_logo.png';

  @override
  Widget build(BuildContext context) {
    final r = radius ?? size * 0.22;
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(framed ? r - 2 : r),
      child: Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => Container(
          width: size,
          height: size,
          color: AppColors.primary,
          alignment: Alignment.center,
          child: Icon(
            Icons.verified_user_rounded,
            color: AppColors.white,
            size: size * 0.5,
          ),
        ),
      ),
    );

    if (!framed) return image;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      alignment: Alignment.center,
      child: image,
    );
  }
}
