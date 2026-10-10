import 'config.dart';

class AccountData {
  final Map<String, dynamic>? profile;
  final Map<String, dynamic>? wallet;
  final List<Map<String, dynamic>> transactions;
  final List<Map<String, dynamic>> notifications;
  final List<Map<String, dynamic>> beneficiaries;
  AccountData({
    this.profile,
    this.wallet,
    this.transactions = const [],
    this.notifications = const [],
    this.beneficiaries = const [],
  });
}

class AccountRepository {
  static Future<AccountData> fetch() async {
    final user = AppConfig.client.auth.currentUser;
    if (user == null) return AccountData();

    var profile = await AppConfig.client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (profile == null) {
      await AppConfig.client.from('profiles').insert({
        'id': user.id,
        'full_name': (user.userMetadata?['full_name']?.toString().isNotEmpty ?? false)
            ? user.userMetadata!['full_name']
            : (user.email?.split('@').first ?? 'Customer'),
        'onboarding_complete': true,
        'email_notifications': true,
        'push_notifications': true,
      });
      profile = await AppConfig.client.from('profiles').select().eq('id', user.id).single();
    }

    final results = await Future.wait([
      AppConfig.client.from('wallets').select().eq('user_id', user.id).maybeSingle(),
      AppConfig.client.from('transactions').select().eq('user_id', user.id).order('created_at', ascending: false),
      AppConfig.client.from('notifications').select().eq('user_id', user.id).order('created_at', ascending: false),
      AppConfig.client.from('beneficiaries').select().eq('user_id', user.id).order('created_at', ascending: false),
    ]);

    return AccountData(
      profile: profile,
      wallet: results[0] as Map<String, dynamic>?,
      transactions: (results[1] as List).cast<Map<String, dynamic>>(),
      notifications: (results[2] as List).cast<Map<String, dynamic>>(),
      beneficiaries: (results[3] as List).cast<Map<String, dynamic>>(),
    );
  }
}
