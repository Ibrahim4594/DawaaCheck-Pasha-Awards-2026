import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../data/models/adr_report_model.dart';
import '../../../data/repositories/adr_repository.dart';
import '../../../domain/providers/session_provider.dart';

class ADRReportScreen extends ConsumerStatefulWidget {
  final String? medicineName;
  final String? batchNumber;

  const ADRReportScreen({super.key, this.medicineName, this.batchNumber});

  @override
  ConsumerState<ADRReportScreen> createState() => _ADRReportScreenState();
}

class _ADRReportScreenState extends ConsumerState<ADRReportScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _medicineController;
  final _reactionController = TextEditingController();
  String _severity = 'MODERATE';
  DateTime _reactionDate = DateTime.now();
  String _ageGroup = 'Adult (18-64)';
  bool _isSubmitting = false;

  final _ageGroups = ['Child (0-12)', 'Adolescent (13-17)', 'Adult (18-64)', 'Elderly (65+)'];

  @override
  void initState() {
    super.initState();
    _medicineController = TextEditingController(text: widget.medicineName ?? '');
  }

  @override
  void dispose() {
    _medicineController.dispose();
    _reactionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.mediumImpact();
    setState(() => _isSubmitting = true);

    try {
      final user = ref.read(sessionProvider).valueOrNull;
      final report = AdrReportModel(
        userId: user?.uid ?? 'anonymous',
        medicineName: _medicineController.text.trim(),
        batchNumber: widget.batchNumber,
        reactionDescription: _reactionController.text.trim(),
        severity: _severity,
        reactionDate: _reactionDate,
        patientAgeGroup: _ageGroup,
      );

      await AdrRepository().submitReport(report);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.reportSuccess), backgroundColor: AppColors.verified),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('failedToSubmit'.tr(namedArgs: {'error': e.toString()})), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          // Gradient header
          SliverToBoxAdapter(
            child: Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.surface,
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              context.pop();
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Theme.of(context).scaffoldBackgroundColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 1.5),
                              ),
                              child: Icon(Icons.arrow_back_rounded, color: Theme.of(context).colorScheme.onSurface, size: 20),
                            ),
                          ),
                          ),
                          const Spacer(),
                          Text(AppStrings.reportAdr, style: AppTextStyles.h4),
                          const Spacer(),
                          const SizedBox(width: 40),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Mono signature header
                    Text(
                      'ADR FORM \u00B7 DRAP \u00A74',
                      style: AppTextStyles.sectionHeader.copyWith(letterSpacing: 1.6),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.medical_information_rounded, color: AppColors.white, size: 28),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Report Side Effect',
                      style: AppTextStyles.h2,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Help improve medicine safety in Pakistan',
                      style: AppTextStyles.caption.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),

          // Form body
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              // Medicine name
              TextFormField(
                controller: _medicineController,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                decoration: InputDecoration(
                  labelText: AppStrings.medicineName,
                  prefixIcon: const Icon(Icons.medication_rounded),
                ),
              )
                  .animate()
                  .fadeIn(duration: 400.ms),
              const SizedBox(height: 16),

              // Reaction description
              TextFormField(
                controller: _reactionController,
                validator: (v) => v == null || v.isEmpty ? 'Please describe the reaction' : null,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: AppStrings.reactionDescription,
                  alignLabelWithHint: true,
                ),
              )
                  .animate()
                  .fadeIn(delay: 100.ms, duration: 400.ms),
              const SizedBox(height: 24),

              // Severity
              Text(
                'SEVERITY \u00B7 \u00A74.1',
                style: AppTextStyles.sectionHeader.copyWith(letterSpacing: 1.6),
              )
                  .animate()
                  .fadeIn(delay: 200.ms, duration: 400.ms),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  (AppStrings.mild, 'MILD', AppColors.verified, AppColors.verifiedLight),
                  (AppStrings.moderate, 'MODERATE', AppColors.warning, AppColors.warningLight),
                  (AppStrings.severe, 'SEVERE', AppColors.danger, AppColors.dangerLight),
                  (AppStrings.lifeThreatening, 'LIFE_THREATENING', AppColors.dangerDark, AppColors.dangerLight),
                ].map((entry) {
                  final isSelected = _severity == entry.$2;
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _severity = entry.$2);
                      },
                      borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? entry.$4 : Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusButton),
                          border: Border.all(
                            color: isSelected ? entry.$3 : Theme.of(context).colorScheme.outlineVariant,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: entry.$3,
                                borderRadius: BorderRadius.circular(1.5),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              entry.$1,
                              style: AppTextStyles.bodyStrong.copyWith(
                                color: isSelected ? entry.$3 : AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              )
                  .animate()
                  .fadeIn(delay: 250.ms, duration: 400.ms),
              const SizedBox(height: 24),

              // Date
              Text(AppStrings.dateOfReaction, style: AppTextStyles.bodySemibold)
                  .animate()
                  .fadeIn(delay: 300.ms, duration: 400.ms),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () async {
                  HapticFeedback.selectionClick();
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _reactionDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) setState(() => _reactionDate = date);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Text(
                        '${_reactionDate.day}/${_reactionDate.month}/${_reactionDate.year}',
                        style: AppTextStyles.bodyMedium,
                      ),
                    ],
                  ),
                ),
              )
                  .animate()
                  .fadeIn(delay: 350.ms, duration: 400.ms),
              const SizedBox(height: 24),

              // Age Group
              Text(AppStrings.patientAgeGroup, style: AppTextStyles.bodySemibold)
                  .animate()
                  .fadeIn(delay: 400.ms, duration: 400.ms),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _ageGroup,
                items: _ageGroups.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                onChanged: (v) => setState(() => _ageGroup = v!),
                decoration: const InputDecoration(),
              )
                  .animate()
                  .fadeIn(delay: 450.ms, duration: 400.ms),
              const SizedBox(height: 32),

              Semantics(
                label: 'Submit adverse reaction report',
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 2.5),
                          )
                        : Text(AppStrings.submit),
                  ),
                ),
              )
                  .animate()
                  .fadeIn(delay: 500.ms, duration: 400.ms),

              SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
            ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
