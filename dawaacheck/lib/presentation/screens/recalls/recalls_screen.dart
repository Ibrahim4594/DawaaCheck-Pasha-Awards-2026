import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/extensions.dart';
import '../../../data/models/recall_alert_model.dart';
import '../../../domain/providers/recall_provider.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/design_system/design_system.dart';

class RecallsScreen extends ConsumerStatefulWidget {
  const RecallsScreen({super.key});

  @override
  ConsumerState<RecallsScreen> createState() => _RecallsScreenState();
}

class _RecallsScreenState extends ConsumerState<RecallsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recallsAsync = ref.watch(recallProvider);
    final affected = ref.watch(affectedRecallsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(
            affectedCount: affected.length,
            recallsAsync: recallsAsync,
            onRefresh: () {
              HapticFeedback.lightImpact();
              ref.read(recallProvider.notifier).refresh();
            },
          ),
          _SearchBar(
            controller: _searchController,
            query: _searchQuery,
            onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
            onClear: () {
              HapticFeedback.lightImpact();
              _searchController.clear();
              setState(() => _searchQuery = '');
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(recallProvider.notifier).refresh(),
              color: AppColors.primary,
              child: recallsAsync.when(
                data: (recalls) => _buildList(recalls, affected),
                loading: _buildLoading,
                error: (e, _) => AppEmptyState.error(
                  onRetry: () {
                    HapticFeedback.lightImpact();
                    ref.read(recallProvider.notifier).refresh();
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    List<RecallAlertModel> recalls,
    List<RecallAlertModel> affected,
  ) {
    if (recalls.isEmpty) return AppEmptyState.noRecalls();

    final searching = _searchQuery.isNotEmpty;
    final filtered = searching
        ? recalls
            .where((r) =>
                r.medicineName.toLowerCase().contains(_searchQuery) ||
                r.recallReason.toLowerCase().contains(_searchQuery))
            .toList()
        : recalls;

    if (filtered.isEmpty) return AppEmptyState.noResults();

    // Bucket into affected vs. the rest (only when not searching).
    final others = searching
        ? filtered
        : filtered.where((r) => !r.userAffected).toList();

    final items = <Widget>[];

    if (!searching && affected.isNotEmpty) {
      items.add(_SectionLabel(
        label: 'YOUR MEDICINES',
        count: affected.length,
        color: AppColors.danger,
      ));
      items.add(Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          'recallYourMedicinesSub'.tr(),
          style: AppTextStyles.body.copyWith(fontSize: 12.5, height: 1.4),
        ),
      ));
      for (var i = 0; i < affected.length; i++) {
        items.add(_AffectedCard(recall: affected[i], index: i));
      }
      items.add(const SizedBox(height: 8));
    }

    if (others.isNotEmpty) {
      if (!searching) {
        items.add(_SectionLabel(
          label: 'ALL ACTIVE RECALLS',
          count: others.length,
          color: AppColors.textSecondary,
        ));
      }
      for (var i = 0; i < others.length; i++) {
        items.add(_RecallCard(recall: others[i], index: i));
      }
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(
          20, 4, 20, MediaQuery.of(context).padding.bottom + 80),
      physics:
          const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
      children: items,
    );
  }

  Widget _buildLoading() {
    return Skeletonizer(
      enabled: true,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: 4,
        itemBuilder: (context, index) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
            border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 80, height: 24, color: Theme.of(context).colorScheme.surface),
              const SizedBox(height: 14),
              Container(width: 200, height: 16, color: Theme.of(context).colorScheme.surface),
              const SizedBox(height: 8),
              Container(width: double.infinity, height: 12, color: Theme.of(context).colorScheme.surface),
              const SizedBox(height: 14),
              Container(width: 100, height: 10, color: Theme.of(context).colorScheme.surface),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HEADER + SEARCH
// ═══════════════════════════════════════════════════════════════════════════

class _Header extends StatelessWidget {
  final int affectedCount;
  final AsyncValue<List<RecallAlertModel>> recallsAsync;
  final VoidCallback onRefresh;

  const _Header({
    required this.affectedCount,
    required this.recallsAsync,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final hasAffected = affectedCount > 0;
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppStrings.recallAlerts, style: AppTextStyles.h2),
                    const SizedBox(height: 4),
                    recallsAsync.when(
                      data: (recalls) => hasAffected
                          ? Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded,
                                    size: 14, color: AppColors.danger),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    'recallAffectedCount'.tr(
                                        namedArgs: {'count': '$affectedCount'}),
                                    style: AppTextStyles.bodySemibold.copyWith(
                                      fontSize: 12.5,
                                      color: AppColors.danger,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              'recallActiveCount'.tr(
                                  namedArgs: {'count': '${recalls.length}'}),
                              style: AppTextStyles.body.copyWith(fontSize: 13),
                            ),
                      loading: () => Text('recallLoading'.tr(),
                          style: AppTextStyles.body.copyWith(fontSize: 13)),
                      error: (e, s) => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
              Material(
                color: AppColors.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onRefresh,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.danger.withValues(alpha: 0.15),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(Icons.refresh_rounded,
                        size: 20, color: AppColors.danger),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant, width: 1.5),
        ),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          style: AppTextStyles.bodyMedium.copyWith(fontSize: 13),
          textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            hintText: 'searchRecallsHint'.tr(),
            hintStyle: AppTextStyles.body
                .copyWith(fontSize: 13, color: AppColors.textHint),
            prefixIcon: const Icon(Icons.search_rounded,
                size: 20, color: AppColors.textHint),
            suffixIcon: query.isNotEmpty
                ? IconButton(
                    onPressed: onClear,
                    icon: const Icon(Icons.close_rounded,
                        size: 18, color: AppColors.textHint),
                    splashRadius: 16,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 36, minHeight: 36),
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            isCollapsed: true,
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _SectionLabel({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 13,
            decoration:
                BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 8),
          Text(label,
              style: AppTextStyles.sectionHeader
                  .copyWith(color: color, letterSpacing: 1.6)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('$count',
                style: AppTextStyles.monoCaption
                    .copyWith(color: color, letterSpacing: 0)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// AFFECTED CARD — a recall matching a medicine in the user's cabinet
// ═══════════════════════════════════════════════════════════════════════════

class _AffectedCard extends StatelessWidget {
  final RecallAlertModel recall;
  final int index;

  const _AffectedCard({required this.recall, required this.index});

  @override
  Widget build(BuildContext context) {
    final isClassI = recall.isClassI;
    final accent = isClassI ? AppColors.danger : AppColors.warning;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClinicalCard(
        accentStripColor: accent,
        backgroundColor: AppColors.dangerLight,
        onTap: () {
          HapticFeedback.selectionClick();
          context.push('/recalls/${recall.id}', extra: recall);
        },
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // "IN YOUR CABINET" ribbon + class
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.inventory_2_rounded,
                          size: 11, color: AppColors.white),
                      const SizedBox(width: 5),
                      Text('IN YOUR CABINET',
                          style: AppTextStyles.badge.copyWith(
                              color: AppColors.white,
                              fontSize: 9.5,
                              letterSpacing: 0.6)),
                    ],
                  ),
                ),
                _ClassBadge(isClassI: isClassI),
                if (recall.exactBatchMatch)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: AppColors.danger.withValues(alpha: 0.3),
                          width: 1),
                    ),
                    child: Text('YOUR EXACT BATCH',
                        style: AppTextStyles.badge.copyWith(
                            color: AppColors.danger,
                            fontSize: 9,
                            letterSpacing: 0.5)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(recall.medicineName, style: AppTextStyles.h4.copyWith(fontSize: 15.5)),
            const SizedBox(height: 6),
            // "You scanned this Xd ago" line
            Row(
              children: [
                const Icon(Icons.history_rounded,
                    size: 13, color: AppColors.danger),
                const SizedBox(width: 5),
                Text(
                  recall.scannedOn != null
                      ? 'recallScannedAgo'.tr(
                          namedArgs: {'time': recall.scannedOn!.timeAgo})
                      : 'recallInCabinet'.tr(),
                  style: AppTextStyles.caption.copyWith(
                      fontSize: 11.5,
                      color: AppColors.danger,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              recall.exactBatchMatch
                  ? 'recallExactBatchWarn'.tr()
                  : 'recallCheckBatch'.tr(),
              style: AppTextStyles.body.copyWith(
                  fontSize: 12.5,
                  height: 1.4,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded,
                    size: 12, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(recall.recallDate.formatted,
                    style: AppTextStyles.caption.copyWith(fontSize: 11)),
                const Spacer(),
                _ViewDetailsPill(color: AppColors.danger),
              ],
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(delay: (70 * index).ms, duration: 350.ms)
        .slideY(
            begin: 0.06,
            end: 0,
            delay: (70 * index).ms,
            duration: 300.ms,
            curve: Curves.easeOutCubic);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// STANDARD RECALL CARD
// ═══════════════════════════════════════════════════════════════════════════

class _RecallCard extends StatelessWidget {
  final RecallAlertModel recall;
  final int index;

  const _RecallCard({required this.recall, required this.index});

  @override
  Widget build(BuildContext context) {
    final isClassI = recall.isClassI;
    final accent = isClassI ? AppColors.danger : AppColors.warning;

    return Semantics(
      label: 'Drug recall alert for ${recall.medicineName}',
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: ClinicalCard(
          accentStripColor: accent,
          onTap: () {
            HapticFeedback.selectionClick();
            context.push('/recalls/${recall.id}', extra: recall);
          },
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.account_balance_rounded,
                            size: 11,
                            color: AppColors.primary.withValues(alpha: 0.8)),
                        const SizedBox(width: 4),
                        Text('DRAP',
                            style: AppTextStyles.badge.copyWith(
                                color: AppColors.primary,
                                fontSize: 9,
                                letterSpacing: 0.8)),
                      ],
                    ),
                  ),
                  _ClassBadge(isClassI: isClassI),
                ],
              ),
              const SizedBox(height: 12),
              Text(recall.medicineName,
                  style: AppTextStyles.h4.copyWith(fontSize: 15)),
              const SizedBox(height: 6),
              Text(
                recall.recallReason,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body.copyWith(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              if (recall.drapNoticeNumber != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.description_outlined,
                        size: 12, color: AppColors.textHint),
                    const SizedBox(width: 5),
                    Text('Notice: ${recall.drapNoticeNumber}',
                        style: AppTextStyles.caption
                            .copyWith(fontSize: 11, color: AppColors.textHint)),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded,
                      size: 13, color: AppColors.textHint),
                  const SizedBox(width: 6),
                  Text(recall.recallDate.formatted,
                      style: AppTextStyles.caption.copyWith(fontSize: 11)),
                  const Spacer(),
                  _ViewDetailsPill(color: AppColors.primary),
                ],
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: (70 * index).ms, duration: 350.ms)
        .slideY(
            begin: 0.05,
            end: 0,
            delay: (70 * index).ms,
            duration: 300.ms,
            curve: Curves.easeOutCubic);
  }
}

class _ClassBadge extends StatelessWidget {
  final bool isClassI;
  const _ClassBadge({required this.isClassI});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isClassI ? AppColors.dangerLight : AppColors.warningLight,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        border: Border.all(
          color: (isClassI ? AppColors.danger : AppColors.warning)
              .withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Text(
        isClassI ? AppStrings.classI : AppStrings.classII,
        style: AppTextStyles.badge.copyWith(
          color: isClassI ? AppColors.danger : AppColors.warning,
          fontSize: 10,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _ViewDetailsPill extends StatelessWidget {
  final Color color;
  const _ViewDetailsPill({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(AppStrings.viewDetails,
              style: AppTextStyles.bodySemibold
                  .copyWith(color: color, fontSize: 12)),
          const SizedBox(width: 4),
          Icon(Icons.arrow_forward_rounded, size: 13, color: color),
        ],
      ),
    );
  }
}
