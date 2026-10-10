import '../config.dart';
import '../format.dart';
import 'vtu_service.dart';

class ScheduleService {
  static Future<List<Map<String, dynamic>>> fetch() async {
    final user = AppConfig.client.auth.currentUser;
    if (user == null) return [];
    final res = await AppConfig.client
        .from('schedules')
        .select()
        .eq('user_id', user.id)
        .order('next_run_at');
    return (res as List).cast<Map<String, dynamic>>();
  }

  static Future<void> create(Map<String, dynamic> row) async {
    final user = AppConfig.client.auth.currentUser;
    if (user == null) throw Exception('Sign in again');
    await AppConfig.client.from('schedules').insert({...row, 'user_id': user.id});
  }

  static Future<void> toggle(String id, bool active) async {
    await AppConfig.client.from('schedules').update({'active': active}).eq('id', id);
  }

  static Future<void> remove(String id) async {
    await AppConfig.client.from('schedules').delete().eq('id', id);
  }

  static DateTime nextAfter(String freq, DateTime from) {
    switch (freq) {
      case 'daily':
        return from.add(const Duration(days: 1));
      case 'weekly':
        return from.add(const Duration(days: 7));
      case 'monthly':
        return DateTime(from.year, from.month + 1, from.day, from.hour, from.minute);
      default:
        return from;
    }
  }

  /// Runs due schedules (active + next_run_at <= now). Returns executed count.
  /// Live mode uses vtu-pay Edge Function (atomic debit); demo inserts success rows.
  static Future<int> runDue() async {
    final user = AppConfig.client.auth.currentUser;
    if (user == null) return 0;
    final now = DateTime.now().toUtc();
    final res = await AppConfig.client
        .from('schedules')
        .select()
        .eq('user_id', user.id)
        .eq('active', true)
        .lte('next_run_at', now.toIso8601String());
    final due = (res as List).cast<Map<String, dynamic>>();
    var ran = 0;
    for (final s in due) {
      try {
        final kind = s['kind'].toString();
        final recipient = s['recipient'].toString();
        final amountKobo = s['amount_kobo'] as int;
        final ref = generateReference();
        if (AppConfig.useEdge) {
          await VtuService.pay(
            kind: kind,
            title: 'Scheduled ${s['provider'] ?? kind}',
            recipient: recipient,
            amountKobo: amountKobo,
            reference: ref,
            provider: (s['provider']?.toString() ?? '').isNotEmpty ? s['provider'].toString() : kind,
            vtpass: {
              'serviceID': VtpassMapping.serviceIDFor(kind, s['provider_id']?.toString() ?? kind),
              'billersCode': recipient,
              'phone': recipient,
              if ((s['product_id']?.toString() ?? '').isNotEmpty) 'variation_code': s['product_id'].toString(),
            },
            extraMetadata: {'scheduled': true, 'schedule_id': s['id'].toString()},
          );
        } else {
          await AppConfig.client.from('transactions').insert({
            'user_id': user.id,
            'kind': kind,
            'title': 'Scheduled ${s['provider'] ?? kind}',
            'recipient': recipient,
            'amount_kobo': amountKobo,
            'reference': ref,
            'provider': s['provider'] ?? kind,
            'status': 'success',
            'metadata': {'scheduled': true, 'schedule_id': s['id'].toString()},
          });
        }
        final freq = s['frequency']?.toString() ?? 'monthly';
        if (freq == 'once') {
          await AppConfig.client.from('schedules').update({'active': false, 'last_run_at': now.toIso8601String()}).eq('id', s['id']);
        } else {
          await AppConfig.client.from('schedules').update({
            'last_run_at': now.toIso8601String(),
            'next_run_at': nextAfter(freq, now).toIso8601String(),
          }).eq('id', s['id']);
        }
        ran++;
      } catch (_) {
        // leave for next run; do not deactivate
      }
    }
    return ran;
  }
}
