import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:animations/animations.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../history/scan_history_detail_screen.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_decorations.dart';
import '../../../core/utils/extensions.dart';
import '../../../data/models/scan_result_model.dart';
import '../../../data/repositories/scan_repository.dart';
import '../../../domain/providers/session_provider.dart';
import '../../widgets/common/app_empty_state.dart';

final _historyProvider = FutureProvider<List<ScanResultModel>>((ref) async {
  // Wait for auth to resolve — don't fetch while still loading
  final session = ref.watch(sessionProvider).valueOrNull;
  if (session == null) return [];
  try {
    return await ScanRepository().getHistory(session.uid);
  } catch (_) {
    return [];
  }
});

class ScanHistoryScreen extends ConsumerStatefulWidget {
  const ScanHistoryScreen({super.key});

  @override
  ConsumerState<ScanHistoryScreen> createState() => _ScanHistoryScreenState();
}

class _ScanHistoryScreenState extends ConsumerState<ScanHistoryScreen> {
  String _filter = 'All';
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(_historyProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Text(AppStrings.scanHistory, style: AppTextStyles.h2),
            ),
            const SizedBox(height: 14),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 1.5),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                  style: AppTextStyles.bodyMedium.copyWith(fontSize: 13),
                  textAlignVertical: TextAlignVertical.center,
                  decoration: InputDecoration(
                    hintText: 'searchMedicinesHint'.tr(),
                    hintStyle: AppTextStyles.body.copyWith(fontSize: 13, color: AppColors.textHint),
                    prefixIcon: Icon(Icons.search_rounded, size: 20, color: AppColors.textHint),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            icon: Icon(Icons.close_rounded, size: 18, color: AppColors.textHint),
                            splashRadius: 16,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    isCollapsed: true,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Filter chips
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [AppStrings.all, AppStrings.verified, AppStrings.unverified, AppStrings.danger]
                    .map((f) {
                  final isSelected = _filter == f;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Semantics(
                      label: 'Filter by ${f.toLowerCase()}',
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _filter = f);
                          },
                          borderRadius: BorderRadius.circular(20),
                          splashColor: AppColors.primary.withValues(alpha: 0.1),
                          highlightColor: AppColors.primary.withValues(alpha: 0.05),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primary : Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? AppColors.primary : AppColors.border,
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              f,
                              style: AppTextStyles.bodyStrong.copyWith(
                                fontSize: 13,
                                color: isSelected ? AppColors.white : Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // History list
            Expanded(
              child: historyAsync.when(
                data: (history) {
                  // Apply filter + search
                  var filtered = _filter == 'All'
                      ? history
                      : history.where((s) => s.overallVerdict.toUpperCase() == _filter.toUpperCase()).toList();

                  if (_searchQuery.isNotEmpty) {
                    filtered = filtered
                        .where((s) =>
                            s.medicineName.toLowerCase().contains(_searchQuery) ||
                            (s.manufacturer?.toLowerCase().contains(_searchQuery) ?? false))
                        .toList();
                  }

                  if (history.isEmpty) return _buildEmptyState();

                  // Build month-grouped items
                  final groupedItems = _buildGroupedItems(filtered);

                  return Column(
                    children: [
                      // Summary stats bar
                      _SummaryStatsBar(allScans: history),
                      const SizedBox(height: 4),

                      // Grouped list with pull-to-refresh
                      Expanded(
                        child: filtered.isEmpty
                            ? _buildNoResultsState()
                            : RefreshIndicator(
                                color: AppColors.primary,
                                backgroundColor: Theme.of(context).colorScheme.surface,
                                onRefresh: () async {
                                  ref.invalidate(_historyProvider);
                                  // Wait for the provider to reload
                                  await ref.read(_historyProvider.future);
                                },
                                child: AnimationLimiter(
                                  child: ListView.builder(
                                  padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).padding.bottom + 80),
                                  physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
                                  itemCount: groupedItems.length,
                                  itemBuilder: (context, index) {
                                    final item = groupedItems[index];
                                    if (item is String) {
                                      // Month header
                                      return AnimationConfiguration.staggeredList(
                                        position: index,
                                        duration: const Duration(milliseconds: 400),
                                        child: SlideAnimation(
                                          horizontalOffset: -30,
                                          child: FadeInAnimation(
                                            child: Padding(
                                        padding: EdgeInsets.only(
                                          top: index == 0 ? 4 : 32,
                                          bottom: 10,
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: AppColors.primaryLight,
                                                borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                                              ),
                                              child: Text(
                                                item.toUpperCase(),
                                                style: AppTextStyles.sectionHeader.copyWith(fontSize: 10),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Container(
                                                height: 1,
                                                color: Theme.of(context).colorScheme.outlineVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                          ),
                                        ),
                                      );
                                    }
                                    final scan = item as ScanResultModel;
                                    return AnimationConfiguration.staggeredList(
                                      position: index,
                                      duration: const Duration(milliseconds: 500),
                                      child: SlideAnimation(
                                        verticalOffset: 40,
                                        child: FadeInAnimation(
                                          child: OpenContainer(
                                            closedElevation: 0,
                                            openElevation: 0,
                                            closedColor: Colors.transparent,
                                            openColor: Theme.of(context).scaffoldBackgroundColor,
                                            transitionDuration: const Duration(milliseconds: 450),
                                            transitionType: ContainerTransitionType.fadeThrough,
                                            closedBuilder: (context, openContainer) {
                                              return _HistoryCard(
                                      scan: scan,
                                      onTap: openContainer,
                                      onDelete: () async {
                                        await ScanRepository().deleteScan(scan.id);
                                        ref.invalidate(_historyProvider);
                                      },
                                    );
                                            },
                                            openBuilder: (context, _) {
                                              return ScanHistoryDetailScreen(
                                                scanId: scan.id,
                                                result: scan,
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                ),
                              ),
                      ),
                    ],
                  );
                },
                loading: () => Skeletonizer(
                  enabled: true,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    physics: const ClampingScrollPhysics(),
                    itemCount: 5,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppDecorations.accentCard(
                        accentColor: AppColors.primaryLight,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(width: 140, height: 14, color: AppColors.white),
                                  const SizedBox(height: 6),
                                  Container(width: 90, height: 10, color: AppColors.white),
                                  const SizedBox(height: 6),
                                  Container(width: 60, height: 10, color: AppColors.white),
                                ],
                              ),
                            ),
                            Container(width: 70, height: 24, decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(AppSpacing.radiusPill))),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                error: (e, _) => AppEmptyState.error(
                  onRetry: () {
                    HapticFeedback.lightImpact();
                    ref.invalidate(_historyProvider);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build grouped items list: interleaved month headers + scan models
  List<Object> _buildGroupedItems(List<ScanResultModel> scans) {
    if (scans.isEmpty) return [];
    final items = <Object>[];
    String? lastMonth;
    for (final scan in scans) {
      final monthKey = DateFormat('MMMM yyyy').format(scan.scanTimestamp);
      if (monthKey != lastMonth) {
        items.add(monthKey);
        lastMonth = monthKey;
      }
      items.add(scan);
    }
    return items;
  }

  Widget _buildEmptyState() {
    return AppEmptyState.noScans(
      onScanTap: () {
        HapticFeedback.lightImpact();
        context.push('/scan');
      },
    );
  }

  Widget _buildNoResultsState() {
    return AppEmptyState.noResults();
  }
}

/// Summary stats bar showing total, verified, danger counts
class _SummaryStatsBar extends StatelessWidget {
  final List<ScanResultModel> allScans;

  const _SummaryStatsBar({required this.allScans});

  @override
  Widget build(BuildContext context) {
    final total = allScans.length;
    final verifiedCount = allScans.where((s) => s.overallVerdict.toUpperCase() == 'VERIFIED').length;
    final dangerCount = allScans.where((s) => s.overallVerdict.toUpperCase() == 'DANGER').length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        child: Row(
          children: [
            _StatItem(
              icon: Icons.analytics_outlined,
              iconColor: AppColors.primary,
              iconBg: AppColors.primaryLight,
              value: '$total',
              label: 'statTotal'.tr(),
            ),
            _divider(context),
            _StatItem(
              icon: Icons.check_circle_outline_rounded,
              iconColor: AppColors.verified,
              iconBg: AppColors.verifiedLight,
              value: '$verifiedCount',
              label: 'statSafe'.tr(),
            ),
            _divider(context),
            _StatItem(
              icon: Icons.warning_amber_rounded,
              iconColor: AppColors.danger,
              iconBg: AppColors.dangerLight,
              value: '$dangerCount',
              label: 'statDanger'.tr(),
            ),
          ],
        ),
      )
          .animate()
          .fadeIn(duration: 400.ms)
          .slideY(begin: -0.1, end: 0, duration: 300.ms, curve: Curves.easeOutCubic),
    );
  }

  Widget _divider(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String value;
  final String label;

  const _StatItem({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(height: 6),
          Text(value, style: AppTextStyles.statNumber.copyWith(fontSize: 18, color: iconColor)),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.statLabel),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final ScanResultModel scan;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _HistoryCard({required this.scan, required this.onTap, required this.onDelete});

  Color get _verdictColor => switch (scan.overallVerdict.toUpperCase()) {
        'VERIFIED' => AppColors.verified,
        'DANGER' => AppColors.danger,
        _ => AppColors.warning,
      };

  Color get _riskColor {
    if (scan.riskScore <= 25) return AppColors.verified;
    if (scan.riskScore <= 50) return AppColors.warning;
    if (scan.riskScore <= 75) return AppColors.danger;
    return AppColors.dangerDark;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Scan result for ${scan.medicineName}, ${scan.overallVerdict.toLowerCase()}',
      child: Dismissible(
        key: Key(scan.id),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => onDelete(),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: AppColors.danger,
            borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Icon(Icons.delete_rounded, color: AppColors.white, size: 20),
              const SizedBox(width: 6),
              Text('delete'.tr(), style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(width: 16),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                onTap();
              },
              borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
              splashColor: _verdictColor.withValues(alpha: 0.06),
              highlightColor: _verdictColor.withValues(alpha: 0.03),
              child: AppDecorations.accentCard(
                accentColor: _verdictColor,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            scan.medicineName,
                            style: AppTextStyles.bodySemibold.copyWith(fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (scan.manufacturer != null && scan.manufacturer!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              scan.manufacturer!,
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 11,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.access_time_rounded, size: 11, color: AppColors.textHint),
                              const SizedBox(width: 3),
                              Text(
                                scan.scanTimestamp.timeAgo,
                                style: AppTextStyles.caption.copyWith(fontSize: 10),
                              ),
                              // Risk score badge
                              if (scan.riskScore > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _riskColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.shield_outlined, size: 9, color: _riskColor),
                                      const SizedBox(width: 3),
                                      Text(
                                        '${scan.riskScore}',
                                        style: AppTextStyles.badge.copyWith(
                                          fontSize: 9,
                                          color: _riskColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Verdict badge + chevron
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: AppDecorations.statusBadge(_verdictColor),
                          child: Text(
                            scan.overallVerdict,
                            style: AppTextStyles.badge.copyWith(
                              color: _verdictColor,
                              fontSize: 10,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textHint),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
