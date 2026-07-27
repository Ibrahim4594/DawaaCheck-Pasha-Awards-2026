import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/validators.dart';
import '../../../core/errors/error_handler.dart';
import '../../../domain/providers/auth_provider.dart';
import '../../widgets/design_system/design_system.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.lightImpact();

    final success = await ref.read(authProvider.notifier).signInWithEmail(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (success && mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen(authStateProvider, (previous, next) {
      final user = next.valueOrNull;
      if (user != null && context.mounted) {
        context.go('/home');
      }
    });

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
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24),

          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // Signature detail: form-label style mono header
              Center(
                child: Text(
                  'SIGN-IN \u00B7 DWA-AUTH',
                  style: AppTextStyles.sectionHeader.copyWith(letterSpacing: 1.6),
                ),
              )
                  .animate()
                  .fadeIn(duration: 300.ms),
              const SizedBox(height: 16),

                // Logo badge
              const Center(child: BrandLogo(size: 64))
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .scale(begin: const Offset(0.85, 0.85), end: const Offset(1, 1), duration: 350.ms, curve: Curves.easeOutCubic),
              const SizedBox(height: 20),

              Text(AppStrings.welcomeBack, style: AppTextStyles.h2, textAlign: TextAlign.center)
                  .animate()
                  .fadeIn(delay: 100.ms, duration: 400.ms)
                  .slideY(begin: 0.1, end: 0, delay: 100.ms, duration: 300.ms, curve: Curves.easeOutCubic),
              const SizedBox(height: 8),
              Text(
                AppStrings.signInToContinue,
                style: AppTextStyles.body.copyWith(color: AppColors.textHint),
                textAlign: TextAlign.center,
              )
                  .animate()
                  .fadeIn(delay: 200.ms, duration: 400.ms),
              const SizedBox(height: 32),

                // Email
                TextFormField(
                  controller: _emailController,
                  validator: Validators.email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: AppStrings.emailAddress,
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                )
                    .animate()
                    .fadeIn(delay: 200.ms, duration: 400.ms),
                const SizedBox(height: 16),

                // Password
                TextFormField(
                  controller: _passwordController,
                  validator: Validators.password,
                  obscureText: !_showPassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _signIn(),
                  decoration: InputDecoration(
                    labelText: AppStrings.password,
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        size: 20,
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() => _showPassword = !_showPassword);
                      },
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(delay: 300.ms, duration: 400.ms),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      context.push('/forgot-password');
                    },
                    child: Text(
                      AppStrings.forgotPassword,
                      style: AppTextStyles.bodySemibold.copyWith(
                        color: AppColors.primary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Error
                if (authState.error != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.dangerLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.danger.withValues(alpha: 0.15), width: 1.5),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            ErrorHandler.getAuthErrorMessage(authState.error),
                            style: AppTextStyles.caption.copyWith(color: AppColors.danger),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Sign In
                Semantics(
                  label: 'Sign in button',
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: authState.isLoading ? null : _signIn,
                      child: authState.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 2.5),
                            )
                          : Text(AppStrings.signIn),
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(delay: 400.ms, duration: 400.ms),
                const SizedBox(height: 24),

                // Or divider
                Row(
                  children: [
                    Expanded(child: Divider(color: AppColors.border.withValues(alpha: 0.5))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(AppStrings.or, style: AppTextStyles.caption.copyWith(color: AppColors.textHint)),
                    ),
                    Expanded(child: Divider(color: AppColors.border.withValues(alpha: 0.5))),
                  ],
                ),
                const SizedBox(height: 24),

                // Google
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton(
                    onPressed: authState.isLoading
                        ? null
                        : () async {
                            HapticFeedback.lightImpact();
                            final success = await ref.read(authProvider.notifier).signInWithGoogle();
                            if (success && context.mounted) context.go('/home');
                          },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant, width: 1.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SvgPicture.asset('assets/icons/google_g_logo.svg', width: 20, height: 20),
                        const SizedBox(width: 12),
                        Text(AppStrings.continueWithGoogle),
                      ],
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(delay: 500.ms, duration: 400.ms),
                const SizedBox(height: 24),

                // Create Account
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(AppStrings.dontHaveAccount, style: AppTextStyles.body.copyWith(color: AppColors.textHint)),
                    TextButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        context.go('/sign-up');
                      },
                      child: Text(
                        AppStrings.createAccount,
                        style: AppTextStyles.bodySemibold.copyWith(color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Trust stamp
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 28, height: 1.5, color: AppColors.border),
                      const SizedBox(height: 12),
                      Text(
                        'E2E ENCRYPTED \u00B7 NEVER STORED \u00B7 DRAP-SCOPED',
                        style: AppTextStyles.monoCaption.copyWith(letterSpacing: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
