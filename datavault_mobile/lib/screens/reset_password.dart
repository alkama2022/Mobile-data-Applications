import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config.dart';
import '../theme.dart';
import '../widgets.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final password = TextEditingController();
  bool show = false;
  bool busy = false;

  // ── Auth-state listener ───────────────────────────────────────────────────
  // Supabase sends a PASSWORD_RECOVERY event when the user follows the reset
  // link.  We listen for it so we know the OTP has been validated server-side
  // before we allow a password update.  Until that event arrives the form is
  // disabled and we show a waiting state.
  bool _tokenReady = false;
  late final Stream<AuthState> _authStream;

  @override
  void initState() {
    super.initState();

    // If the user is already in a PASSWORD_RECOVERY session (they tapped the
    // link and the deep-link opened this screen with a valid OTP in the URL),
    // the SDK will have already fired the event before initState runs.
    // We check the current session type first so we don't wait unnecessarily.
    final session = AppConfig.client.auth.currentSession;
    if (session != null) {
      // A live session means Supabase already exchanged the OTP — allow update.
      _tokenReady = true;
    }

    _authStream = AppConfig.client.auth.onAuthStateChange;
    _authStream.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        if (mounted) setState(() => _tokenReady = true);
      }
    });
  }

  @override
  void dispose() {
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!_tokenReady) {
      showAppToast(context, 'Open the reset link from your email first.');
      return;
    }
    if (password.text.length < 8) {
      showAppToast(context, 'Password must be at least 8 characters');
      return;
    }
    setState(() => busy = true);
    try {
      await AppConfig.client.auth
          .updateUser(UserAttributes(password: password.text));
      showAppToast(context, 'Password updated — please sign in again.');
      if (mounted) context.go('/auth');
    } catch (e) {
      showAppToast(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void showAppToast(context, String msg) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              const Brand(),
              const SizedBox(height: 40),
              const Eyebrow('Account security'),
              const SizedBox(height: 12),
              Text('Set a new password', style: displayStyle(size: 28)),
              const SizedBox(height: 8),
              const Text(
                'Choose at least 8 characters you do not use elsewhere.',
                style: TextStyle(color: AppColors.mutedForeground),
              ),

              // ── Waiting for OTP exchange ────────────────────────────
              if (!_tokenReady) ...[
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.highlightSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Waiting for your reset link to be verified…\n'
                        'Open the link from your email to continue.',
                        style: TextStyle(
                          color: AppColors.highlightForeground,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: TextButton(
                    onPressed: () => context.go('/auth'),
                    child: const Text('Back to sign in',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],

              // ── Password form (only when OTP is validated) ──────────
              if (_tokenReady) ...[
                const SizedBox(height: 28),
                const Text('New password',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: password,
                  obscureText: !show,
                  decoration: InputDecoration(
                    hintText: 'At least 8 characters',
                    prefixIcon: const Icon(Icons.lock_outline,
                        size: 20, color: AppColors.mutedForeground),
                    suffixIcon: IconButton(
                      icon: Icon(
                          show ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => show = !show),
                    ),
                    filled: true,
                    fillColor: AppColors.card,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.input)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.input)),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                    onPressed: busy ? null : submit,
                    child: busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Update password',
                            style:
                                TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
