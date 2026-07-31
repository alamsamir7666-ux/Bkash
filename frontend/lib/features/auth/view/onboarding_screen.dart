import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../providers/auth_provider.dart';
import '../../../shared/widgets/widgets.dart';

/// Onboarding screen — shown when a user is signed in via Firebase but
/// hasn't yet created their shop profile in the backend.
///
/// This happens when:
///   - The user just registered via FirebaseAuth (createUserWithEmailAndPassword)
///     but the backend POST /auth/onboard call hasn't happened yet (e.g.
///     network failed mid-flow), OR
///   - The user was created in the Firebase Console directly without going
///     through the app's register screen.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pre-fill the name with the Firebase user's display name if available.
    final fbUser = FirebaseAuth.instance.currentUser;
    if (fbUser?.displayName != null && fbUser!.displayName!.isNotEmpty) {
      _nameCtrl.text = fbUser.displayName!;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(authProvider.notifier).completeOnboarding(
          name: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim().isEmpty
              ? null
              : _phoneCtrl.text.trim(),
        );
    if (!ok && mounted) {
      _showError(ref.read(authProvider).error ?? 'Onboarding failed');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final email = FirebaseAuth.instance.currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppTheme.textPrimary,
        title: const Text('Complete Your Profile'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Welcome to Smart Shop Ledger!',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'You\'re signed in as $email. Just need a few details to '
                  'finish setting up your shop. Three default accounts '
                  '(agent bKash, personal bKash, physical cash) will be '
                  'created automatically.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 24),
                AppTextField(
                  label: 'Shop Owner Name',
                  controller: _nameCtrl,
                  prefixIcon: Icons.person_outline,
                  validator: (v) => Validators.required(v, label: 'Name'),
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: 'Phone (optional)',
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  prefixIcon: Icons.phone_outlined,
                  validator: Validators.phone,
                  hint: '01XXXXXXXXX',
                ),
                const SizedBox(height: 28),
                PrimaryButton(
                  label: 'Complete Setup',
                  icon: Icons.check_circle_outline,
                  loading: auth.loadingAction,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
