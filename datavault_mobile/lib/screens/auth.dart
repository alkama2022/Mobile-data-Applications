import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../account_store.dart';
import '../config.dart';
import '../theme.dart';
import '../widgets.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  String mode = 'signin'; // signin | signup | forgot
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  bool show = false;
  bool busy = false;

  Future<void> submit() async {
    if (!email.text.contains('@')) { _toast('Enter a valid email address'); return; }
    setState(() => busy = true);
    try {
      if (mode == 'forgot') {
        await AppConfig.client.auth.resetPasswordForEmail(email.text.trim());
        _toast('Check your email for the reset link');
        setState(() => mode = 'signin');
        return;
      }
      if (password.text.length < 8) { _toast('Password must be at least 8 characters'); return; }
      if (mode == 'signup') {
        if (name.text.trim().length < 2) { _toast('Enter your full name'); return; }
        final res = await AppConfig.client.auth.signUp(email: email.text.trim(), password: password.text, data: {'full_name': name.text.trim()});
        if (res.session == null) { _toast('Check your email to confirm your account'); setState(() => mode = 'signin'); return; }
      } else {
        await AppConfig.client.auth.signInWithPassword(email: email.text.trim(), password: password.text);
      }
      await accountStore.refresh();
      if (mounted) context.go('/app');
    } catch (e) {
      _toast(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final title = mode == 'signup' ? 'Create your account' : mode == 'forgot' ? 'Reset your password' : 'Welcome back';
    final subtitle = mode == 'forgot' ? "We'll send a secure reset link to your inbox." : 'Secure payments for everyday essentials.';
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
              const Eyebrow('Welcome to DataVault'),
              const SizedBox(height: 12),
              Text(title, style: displayStyle(size: 28)),
              const SizedBox(height: 8),
              Text(subtitle, style: const TextStyle(color: AppColors.mutedForeground)),
              const SizedBox(height: 28),
              if (mode == 'signup') ...[
                const Text('Full name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(controller: name, decoration: _dec('Alkam Umar', Icons.person_outline)),
                const SizedBox(height: 18),
              ],
              const Text('Email address', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: _dec('you@example.com', Icons.mail_outline)),
              const SizedBox(height: 18),
              if (mode != 'forgot') ...[
                Row(children: [
                  const Text('Password', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const Spacer(),
                  if (mode == 'signin') TextButton(onPressed: () => setState(() => mode = 'forgot'), child: const Text('Forgot password?', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                ]),
                const SizedBox(height: 8),
                TextField(
                  controller: password,
                  obscureText: !show,
                  decoration: _dec('At least 8 characters', Icons.lock_outline).copyWith(
                    suffixIcon: IconButton(icon: Icon(show ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => show = !show)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: busy ? null : submit,
                  child: busy
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(mode == 'signup' ? 'Create account' : mode == 'forgot' ? 'Send reset link' : 'Sign in', style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: mode == 'forgot'
                    ? TextButton(onPressed: () => setState(() => mode = 'signin'), child: const Text('Back to sign in', style: TextStyle(fontWeight: FontWeight.w800)))
                    : Wrap(alignment: WrapAlignment.center, children: [
                        Text(mode == 'signup' ? 'Already have an account? ' : 'New to DataVault? ', style: const TextStyle(color: AppColors.mutedForeground)),
                        GestureDetector(
                          onTap: () => setState(() => mode = mode == 'signup' ? 'signin' : 'signup'),
                          child: Text(mode == 'signup' ? 'Sign in' : 'Create account', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
                        ),
                      ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _dec(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: AppColors.mutedForeground),
        filled: true,
        fillColor: AppColors.card,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.input)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.input)),
      );
}
