import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../gift_helper.dart';
import '../services/storefront_service.dart';
import '../theme.dart';
import '../widgets.dart';

class StorefrontScreen extends StatefulWidget {
  const StorefrontScreen({super.key});

  @override
  State<StorefrontScreen> createState() => _StorefrontScreenState();
}

class _StorefrontScreenState extends State<StorefrontScreen> {
  final handle = TextEditingController();
  final displayName = TextEditingController();
  double markup = 0;
  bool active = true;
  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final m = await StorefrontService.mine();
      if (m != null && mounted) {
        handle.text = m['handle']?.toString() ?? '';
        displayName.text = m['display_name']?.toString() ?? '';
        markup = (m['markup_pct'] as num? ?? 0).toDouble();
        active = (m['active'] as bool? ?? true);
      }
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      await StorefrontService.save(handle: handle.text, displayName: displayName.text, markupPct: markup, active: active);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Storefront saved')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final link = handle.text.trim().isEmpty ? 'https://datavault.ng/s/yourname' : StorefrontService.publicLink(handle.text.trim().toLowerCase());
    return Scaffold(
      appBar: AppBar(title: const Text('My storefront')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const InfoBanner(message: 'Share your link — customers order, you earn markup on every sale.'),
                const SizedBox(height: 12),
                TextField(controller: displayName, decoration: const InputDecoration(labelText: 'Shop name', hintText: 'Chinedu Data Hub')),
                const SizedBox(height: 12),
                TextField(
                  controller: handle,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Handle', hintText: 'chinedu', prefixText: 'datavault.ng/s/'),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: Text('Markup: ${markup.toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.w800))),
                  Switch(value: active, onChanged: (v) => setState(() => active = v)),
                  const Text('Open'),
                ]),
                Slider(value: markup, max: 20, divisions: 20, label: '${markup.toStringAsFixed(0)}%', onChanged: (v) => setState(() => markup = v)),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.muted, borderRadius: BorderRadius.circular(12)),
                  child: SelectableText(link, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
                ),
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, height: 52, child: FilledButton(onPressed: saving ? null : _save, child: Text(saving ? 'Saving…' : 'Save storefront'))),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.share_rounded),
                        label: const Text('Share on WhatsApp'),
                        onPressed: () => shareViaWhatsApp(StorefrontService.salesPitch(handle: handle.text.trim().toLowerCase(), displayName: displayName.text.trim())),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('Copy'),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: link));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied')));
                      },
                    ),
                  ),
                ]),
              ],
            ),
    );
  }
}
