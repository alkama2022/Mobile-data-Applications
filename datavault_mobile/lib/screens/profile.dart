import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../account_store.dart';
import '../config.dart';
import '../theme.dart';
import '../theme_store.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final name = TextEditingController();
  final phone = TextEditingController();
  bool emailN = true;
  bool pushN = true;
  bool busy = false;
  String? _avatarUrl;
  File? _avatarFile;
  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    if (accountStore.loading) accountStore.refresh();
    accountStore.addListener(_onChange);
    themeStore.addListener(_onChange);
    _sync();
  }

  void _onChange() {
    _sync();
    setState(() {});
  }

  void _sync() {
    final p = accountStore.data.profile;
    if (p != null) {
      name.text = p['full_name']?.toString() ?? '';
      phone.text = p['phone']?.toString() ?? '';
      emailN = p['email_notifications'] == true;
      pushN = p['push_notifications'] == true;
      _avatarUrl = p['avatar_url']?.toString();
    }
  }

  @override
  void dispose() {
    accountStore.removeListener(_onChange);
    themeStore.removeListener(_onChange);
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 512);
    if (picked == null) return;
    setState(() { _avatarFile = File(picked.path); _uploadingAvatar = true; });
    try {
      final user = AppConfig.client.auth.currentUser!;
      final bytes = await File(picked.path).readAsBytes();
      final ext = picked.path.split('.').last;
      final path = 'avatars/${user.id}.$ext';
      await AppConfig.client.storage.from('avatars').uploadBinary(
        path, bytes,
        fileOptions: FileOptions(contentType: 'image/$ext', upsert: true),
      );
      final url = AppConfig.client.storage.from('avatars').getPublicUrl(path);
      await AppConfig.client.from('profiles').update({'avatar_url': url}).eq('id', user.id);
      setState(() { _avatarUrl = url; _uploadingAvatar = false; });
      await accountStore.refresh();
    } catch (e) {
      setState(() => _uploadingAvatar = false);
      showAppToast(context, 'Avatar upload failed: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  Future<void> save() async {
    if (name.text.trim().length < 2) {
      showAppToast(context, 'Enter your full name');
      return;
    }
    setState(() => busy = true);
    final id = accountStore.data.profile?['id'];
    await AppConfig.client.from('profiles').update({
      'full_name': name.text.trim(),
      'phone': phone.text.trim(),
      'email_notifications': emailN,
      'push_notifications': pushN,
    }).eq('id', id ?? '');
    setState(() => busy = false);
    showAppToast(context, 'Profile updated');
    await accountStore.refresh();
  }

  Future<void> logout() async {
    await accountStore.clearOnLogout();
    await AppConfig.client.auth.signOut();
    if (mounted) context.go('/auth');
  }

  void showAppToast(context, String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final email = AppConfig.client.auth.currentUser?.email ?? '';
    final displayName = accountStore.data.profile?['full_name']?.toString() ?? 'User';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ── Avatar card ──────────────────────────────────────────
        Center(
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              GestureDetector(
                onTap: _pickAvatar,
                child: Container(
                  width: 90, height: 90,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 2),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _uploadingAvatar
                      ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                      : _avatarFile != null
                          ? Image.file(_avatarFile!, fit: BoxFit.cover)
                          : (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                              ? Image.network(_avatarUrl!, fit: BoxFit.cover,
                                  errorBuilder: (ctx, err, stack) => const Icon(Icons.person, color: AppColors.primary, size: 44))
                              : const Icon(Icons.person, color: AppColors.primary, size: 44),
                ),
              ),
              Container(
                width: 28, height: 28,
                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Center(child: Text(displayName, style: displayStyleOf(context, size: 18))),
        Center(child: Text(email, style: const TextStyle(color: AppColors.mutedForeground, fontSize: 13))),

        const SizedBox(height: 24),

        // ── Personal details ─────────────────────────────────────
        _sectionHeader(context, 'Personal details', Icons.person_outline_rounded),
        const SizedBox(height: 12),
        const Text('Full name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 8),
        TextField(controller: name, decoration: _dec()),
        const SizedBox(height: 16),
        const Text('Phone number', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 8),
        TextField(controller: phone, keyboardType: TextInputType.phone, decoration: _dec('080 1234 5678')),
        const SizedBox(height: 20),
        SizedBox(
          height: 54,
          child: FilledButton(
            onPressed: busy ? null : save,
            child: busy
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Save changes', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),

        const SizedBox(height: 28),

        // ── Notifications ─────────────────────────────────────────
        _sectionHeader(context, 'Notifications', Icons.notifications_outlined),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(children: [
            SwitchListTile(
              title: const Text('Email updates', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text('Receipts and important account updates'),
              value: emailN,
              onChanged: (v) => setState(() => emailN = v),
            ),
            const Divider(height: 1, indent: 16),
            SwitchListTile(
              title: const Text('Push updates', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text('Instant payment status notifications'),
              value: pushN,
              onChanged: (v) => setState(() => pushN = v),
            ),
          ]),
        ),

        const SizedBox(height: 28),

        // ── Appearance ────────────────────────────────────────────
        _sectionHeader(context, 'Appearance', Icons.palette_outlined),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(children: [
            _themeOption(context, ThemeMode.system, 'System default', 'Follow device setting', Icons.brightness_auto_rounded),
            const Divider(height: 1, indent: 16),
            _themeOption(context, ThemeMode.light, 'Light mode', 'Always light', Icons.light_mode_rounded),
            const Divider(height: 1, indent: 16),
            _themeOption(context, ThemeMode.dark, 'Dark mode', 'Always dark', Icons.dark_mode_rounded),
          ]),
        ),

        const SizedBox(height: 28),

        // ── Quick links ────────────────────────────────────────────
        _sectionHeader(context, 'Account', Icons.manage_accounts_outlined),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(children: [
            _link(Icons.people_alt_outlined, 'Saved recipients', () => context.push('/app/beneficiaries')),
            const Divider(height: 1, indent: 56),
            _link(Icons.lock_outline_rounded, 'Security & PIN', () => context.push('/app/security')),
          ]),
        ),

        const SizedBox(height: 24),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: const Row(children: [
            Icon(Icons.verified_user_rounded, color: AppColors.success),
            SizedBox(width: 12),
            Expanded(child: Text('Passwords are checked against known breaches.', style: TextStyle(color: AppColors.mutedForeground))),
          ]),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 54,
          child: OutlinedButton.icon(
            onPressed: logout,
            icon: const Icon(Icons.logout, color: AppColors.destructive),
            label: const Text('Log out', style: TextStyle(color: AppColors.destructive, fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _sectionHeader(BuildContext ctx, String label, IconData icon) {
    return Row(children: [
      Icon(icon, size: 18, color: AppColors.mutedForeground),
      const SizedBox(width: 8),
      Text(label, style: displayStyleOf(ctx, size: 16)),
    ]);
  }

  Widget _themeOption(BuildContext context, ThemeMode mode, String title, String sub, IconData icon) {
    final selected = themeStore.mode == mode;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : AppColors.muted,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: selected ? AppColors.primary : AppColors.mutedForeground),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: selected ? AppColors.primary : null)),
      subtitle: Text(sub, style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
      trailing: selected ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
      onTap: () => themeStore.setMode(mode),
    );
  }

  Widget _link(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(icon, color: AppColors.mutedForeground),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.mutedForeground),
      onTap: onTap,
    );
  }

  InputDecoration _dec([String? hint]) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: AppColors.card,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.input)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.input)),
  );
}
