import 'package:flutter/material.dart';
import '../account_store.dart';
import '../config.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    accountStore.addListener(_onChange);
    _markAllRead();
  }

  void _onChange() => setState(() {});

  @override
  void dispose() {
    accountStore.removeListener(_onChange);
    super.dispose();
  }

  Future<void> _markAllRead() async {
    final ids = accountStore.data.notifications
        .where((n) => n['read_at'] == null)
        .map((n) => n['id'])
        .toList();
    if (ids.isNotEmpty) {
      await AppConfig.client
          .from('notifications')
          .update({'read_at': DateTime.now().toIso8601String()})
          .inFilter('id', ids);
      await accountStore.refresh();
    }
  }

  Future<void> _deleteOne(dynamic id) async {
    await AppConfig.client.from('notifications').delete().eq('id', id);
    await accountStore.refresh();
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear all notifications?'),
        content: const Text('All notifications will be permanently removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear all', style: TextStyle(color: AppColors.destructive)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final user = AppConfig.client.auth.currentUser;
      if (user != null) {
        await AppConfig.client.from('notifications').delete().eq('user_id', user.id);
        await accountStore.refresh();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = accountStore.data.notifications;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (items.isNotEmpty)
            TextButton(
              onPressed: _clearAll,
              child: const Text('Clear all', style: TextStyle(color: AppColors.destructive, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (items.isEmpty)
            Container(
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
              child: const StateView(
                icon: Icons.notifications_none_rounded,
                title: "You're all caught up",
                description: 'Account and transaction updates will appear here.',
              ),
            )
          else
            Container(
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
              child: Column(
                children: items.asMap().entries.map((entry) {
                  final n = entry.value;
                  final isLast = entry.key == items.length - 1;
                  final isUnread = n['read_at'] == null;

                  return Dismissible(
                    key: ValueKey(n['id']),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      color: AppColors.destructive,
                      child: const Icon(Icons.delete_outline, color: Colors.white),
                    ),
                    onDismissed: (_) => _deleteOne(n['id']),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Container(
                              margin: const EdgeInsets.only(top: 5),
                              width: 10, height: 10,
                              decoration: BoxDecoration(
                                color: isUnread ? AppColors.primary : AppColors.border,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(n['title']?.toString() ?? '', style: TextStyle(fontWeight: isUnread ? FontWeight.w800 : FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(n['message']?.toString() ?? '', style: const TextStyle(color: AppColors.mutedForeground, fontSize: 13)),
                              const SizedBox(height: 6),
                              Text(formatDate(n['created_at']?.toString() ?? ''), style: const TextStyle(color: AppColors.mutedForeground, fontSize: 11)),
                            ])),
                          ]),
                        ),
                        if (!isLast) const Divider(height: 1, indent: 40),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
