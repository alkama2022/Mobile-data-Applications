import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../config.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

class BeneficiariesScreen extends StatefulWidget {
  const BeneficiariesScreen({super.key});

  @override
  State<BeneficiariesScreen> createState() => _BeneficiariesScreenState();
}

class _BeneficiariesScreenState extends State<BeneficiariesScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final user = AppConfig.client.auth.currentUser;
      if (user == null) { setState(() => _loading = false); return; }
      final res = await AppConfig.client
          .from('beneficiaries')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);
      setState(() {
        _items = (res as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _delete(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove beneficiary?'),
        content: const Text('This recipient will be removed from your saved list.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: AppColors.destructive)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await AppConfig.client.from('beneficiaries').delete().eq('id', id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _items.where((b) {
      final text = '${b['nickname']}${b['recipient']}${b['provider']}'.toLowerCase();
      return text.contains(_q.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Saved recipients')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            onChanged: (v) => setState(() => _q = v),
            decoration: InputDecoration(
              hintText: 'Search beneficiaries',
              prefixIcon: const Icon(Icons.search, color: AppColors.mutedForeground),
              filled: true,
              fillColor: AppColors.card,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
            ),
          ),
          const SizedBox(height: 20),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
          else if (filtered.isEmpty)
            Container(
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
              child: StateView(
                icon: Icons.people_outline_rounded,
                title: _q.isEmpty ? 'No saved recipients' : 'No matching recipients',
                description: _q.isEmpty
                    ? 'When you tick "Save for next time" during a payment, your recipient will appear here.'
                    : 'Try a different search term.',
              ),
            )
          else
            Container(
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
              child: Column(
                children: filtered.asMap().entries.map((e) {
                  final b = e.value;
                  final isLast = e.key == filtered.length - 1;
                  final kind = ServiceKind.fromDb(b['kind']?.toString() ?? '');
                  return Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          width: 46, height: 46,
                          decoration: BoxDecoration(color: kind.iconBg, borderRadius: BorderRadius.circular(12)),
                          child: Icon(kind.icon, color: kind.iconFg, size: 22),
                        ),
                        title: Text(b['nickname']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text(
                          '${b['recipient']} · ${b['provider']}',
                          style: const TextStyle(color: AppColors.mutedForeground, fontSize: 12),
                        ),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            icon: const Icon(Icons.send_rounded, size: 18, color: AppColors.primary),
                            tooltip: 'Pay again',
                            onPressed: () => context.push('/app/services/${b['kind']}'),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.destructive),
                            tooltip: 'Remove',
                            onPressed: () => _delete(b['id'].toString()),
                          ),
                        ]),
                      ),
                      if (!isLast)
                        const Divider(height: 1, indent: 72),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
