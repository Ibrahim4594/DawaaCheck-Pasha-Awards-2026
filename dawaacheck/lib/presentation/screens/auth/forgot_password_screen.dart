import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/validators.dart';
import '../../../domain/providers/auth_provider.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  int _selectedTab = 0;
  bool _resetSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.lightImpact();

    await ref.read(authProvider.notifier).resetPassword(_emailController.text.trim());

    if (mounted) {
      setState(() => _resetSent = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                context.pop();
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 1.5),
                ),
                child: const Icon(Icons.arrow_back_rounded, size: 20),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _resetSent ? _buildSuccessView() : _buildFormView(authState),
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.verifiedLight,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.verified.withValues(alpha: 0.3), width: 1.5),
          ),
          child: const Icon(Icons.check_circle_rounded, color: AppColors.verified, size: 44),
        )
            .animate()
            .scale(begin: const Offset(0.5, 0.5), end: const Offset(1, 1), duration: 500.ms, curve: Curves.elasticOut),
        const SizedBox(height: 24),
        Text(AppStrings.resetEmailSent, style: AppTextStyles.h3, textAlign: TextAlign.center)
            .animate()
            .fadeIn(delay: 200.ms, duration: 400.ms),
        const SizedBox(height: 12),
        Text(
          AppStrings.checkInbox,
          style: AppTextStyles.body.copyWith(color: AppColors.textHint),
          textAlign: TextAlign.center,
        )
            .animate()
            .fadeIn(delay: 300.ms, duration: 400.ms),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              context.go('/sign-in');
            },
            child: Text(AppStrings.backToSignIn),
          ),
        )
            .animate()
            .fadeIn(delay: 400.ms, duration: 400.ms),
      ],
    );
  }

  Widget _buildFormView(AuthState authState) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Signature detail: form-label style mono header
          Center(
            child: Text(
              'RESET \u00B7 DWA-AUTH',
              style: AppTextStyles.sectionHeader.copyWith(letterSpacing: 1.6),
            ),
          )
              .animate()
              .fadeIn(duration: 300.ms),
          const SizedBox(height: 16),

          // Icon
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.lock_reset_rounded, color: AppColors.white, size: 32),
            ),
          )
              .animate()
              .fadeIn(duration: 400.ms)
              .scale(begin: const Offset(0.85, 0.85), end: const Offset(1, 1), duration: 350.ms, curve: Curves.easeOutCubic),
          const SizedBox(height: 20),

          Text(AppStrings.resetPassword, style: AppTextStyles.h2, textAlign: TextAlign.center)
              .animate()
              .fadeIn(delay: 100.ms, duration: 400.ms)
              .slideY(begin: 0.1, end: 0, delay: 100.ms, duration: 300.ms, curve: Curves.easeOutCubic),
          const SizedBox(height: 8),
          Text(
            AppStrings.enterEmailReset,
            style: AppTextStyles.body.copyWith(color: AppColors.textHint),
            textAlign: TextAlign.center,
          )
              .animate()
              .fadeIn(delay: 200.ms, duration: 400.ms),
          const SizedBox(height: 24),

          // Tab selector
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                _buildTab(AppStrings.email, 0),
                _buildTab(AppStrings.phone, 1),
              ],
            ),
          )
              .animate()
              .fadeIn(delay: 200.ms, duration: 400.ms),
          const SizedBox(height: 24),

          // Input
          TextFormField(
            controller: _emailController,
            validator: _selectedTab == 0 ? Validators.email : null,
            keyboardType: _selectedTab == 0 ? TextInputType.emailAddress : TextInputType.phone,
            decoration: InputDecoration(
              labelText: _selectedTab == 0 ? AppStrings.emailAddress : AppStrings.phoneNumber,
              prefixIcon: Icon(
                _selectedTab == 0 ? Icons.email_outlined : Icons.phone_outlined,
              ),
            ),
          )
              .animate()
              .fadeIn(delay: 300.ms, duration: 400.ms),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: authState.isLoading ? null : _resetPassword,
              child: authState.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 2.5),
                    )
                  : Text(AppStrings.resetPassword),
            ),
          )
              .animate()
              .fadeIn(delay: 400.ms, duration: 400.ms),
          const SizedBox(height: 32),

          // Trust stamp
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 28, height: 1.5, color: AppColors.border),
                const SizedBox(height: 12),
                Text(
                  'VERIFIED LINK \u00B7 10-MIN EXPIRY',
                  style: AppTextStyles.monoCaption.copyWith(letterSpacing: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedTab = index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySemibold.copyWith(
              color: isSelected ? AppColors.white : Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
