import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';

/// Floating bottom navigation bar — shared by the shell AND by the scan-flow
/// screens (processing / results) so the user is never stranded without a way
/// back to Home, Console, etc.
///
/// Computes the active tab from the current route and navigates with
/// `context.go`. Routes that aren't tabs (scan / result) simply highlight
/// nothing.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key});

  static const _routes = ['/home', '/history', '/terminal', '/recalls', '/profile'];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/history')) return 1;
    if (location.startsWith('/terminal')) return 2;
    if (location.startsWith('/recalls')) return 3;
    if (location.startsWith('/profile')) return 4;
    if (location.startsWith('/home')) return 0;
    return -1; // scan / result — no tab active
  }

  void _onTap(BuildContext context, int index) {
    HapticFeedback.lightImpact();
    context.go(_routes[index]);
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentIndex(context);
    final theme = Theme.of(context);

    final items = <_NavItem>[
      _NavItem(icon: Iconsax.home_2, activeIcon: Iconsax.home_1, label: AppStrings.home),
      _NavItem(icon: Iconsax.clock, activeIcon: Iconsax.clock_1, label: AppStrings.history),
      _NavItem(icon: Iconsax.code, activeIcon: Iconsax.code_1, label: AppStrings.terminal),
      _NavItem(icon: Iconsax.shield_tick, activeIcon: Iconsax.shield_tick, label: AppStrings.recalls),
      _NavItem(icon: Iconsax.profile_circle, activeIcon: Iconsax.profile_circle, label: AppStrings.profile),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      height: 68,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outlineVariant, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 48,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(items.length, (i) {
          return Expanded(
            child: _NavBarItem(
              item: items[i],
              isActive: i == current,
              onTap: () => _onTap(context, i),
            ),
          );
        }),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hintColor = Theme.of(context).hintColor;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.primary.withValues(alpha: 0.08),
        highlightColor: AppColors.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: double.infinity,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.symmetric(
                    horizontal: isActive ? 16 : 0,
                    vertical: isActive ? 6 : 0,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isActive ? item.activeIcon : item.icon,
                    color: isActive ? AppColors.primary : hintColor,
                    size: isActive ? 24 : 22,
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: AppTextStyles.caption.copyWith(
                    color: isActive ? AppColors.primary : hintColor,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    fontSize: 10,
                  ),
                  child: Text(item.label),
                ),
                const SizedBox(height: 2),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: isActive ? 4 : 0,
                  height: isActive ? 4 : 0,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
