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
  /// Number of transactions fetched per page.
  static const int txPageSize = 25;

  /// Returns the current user's UUID or null if not signed in.
  static String? get currentUserId =>
      AppConfig.client.auth.currentUser?.id;

  // ── Full snapshot ─────────────────────────────────────────────────────────

  /// Full account snapshot — profile, wallet, first page of transactions,
  /// notifications, and beneficiaries all in one parallel call.
  /// Profile is upserted in a single round-trip (no select → insert → select).
  static Future<AccountData> fetch() async {
    final user = AppConfig.client.auth.currentUser;
    if (user == null) return AccountData();

    // Single upsert collapses 3 sequential round-trips into 1.
    // ignoreDuplicates:false returns the existing row on conflict without
    // overwriting onboarding_complete or notification prefs already set by
    // the user — the DB trigger keeps updated_at current.
    final profile = await AppConfig.client
        .from('profiles')
        .upsert(
          {
            'id': user.id,
            'full_name':
                (user.userMetadata?['full_name']?.toString().isNotEmpty ??
                        false)
                    ? user.userMetadata!['full_name']
                    : (user.email?.split('@').first ?? 'Customer'),
            'onboarding_complete': true,
            'email_notifications': true,
            'push_notifications': true,
          },
          onConflict: 'id',
          ignoreDuplicates: false,
        )
        .select()
        .single();

    final results = await Future.wait([
      AppConfig.client
          .from('wallets')
          .select()
          .eq('user_id', user.id)
          .maybeSingle(),
      AppConfig.client
          .from('transactions')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(txPageSize),
      AppConfig.client
          .from('notifications')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(20),
      AppConfig.client
          .from('beneficiaries')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(50),
    ]);

    return AccountData(
      profile: profile,
      wallet: results[0] as Map<String, dynamic>?,
      transactions: (results[1] as List).cast<Map<String, dynamic>>(),
      notifications: (results[2] as List).cast<Map<String, dynamic>>(),
      beneficiaries: (results[3] as List).cast<Map<String, dynamic>>(),
    );
  }

  // ── Targeted helpers (used after a purchase) ──────────────────────────────

  /// Fetches only the wallet row — fast post-payment balance update.
  static Future<Map<String, dynamic>?> fetchWallet(String userId) async {
    return await AppConfig.client
        .from('wallets')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
  }

  /// Fetches the latest page of transactions — fast post-payment tx update.
  static Future<List> fetchRecentTransactions(String userId) async {
    return await AppConfig.client
        .from('transactions')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(txPageSize);
  }

  // ── Pagination ────────────────────────────────────────────────────────────

  /// Fetches the next page of transactions using cursor-based pagination.
  /// Pass the `created_at` of the last row already loaded as [beforeCreatedAt].
  /// Optionally filter by [kindFilter] (e.g. 'airtime', 'wallet_funding').
  static Future<List<Map<String, dynamic>>> fetchMoreTransactions({
    required String beforeCreatedAt,
    String? kindFilter,
  }) async {
    final user = AppConfig.client.auth.currentUser;
    if (user == null) return [];

    var builder = AppConfig.client
        .from('transactions')
        .select()
        .eq('user_id', user.id)
        .lt('created_at', beforeCreatedAt)
        .order('created_at', ascending: false)
        .limit(txPageSize);

    if (kindFilter != null) {
      builder = AppConfig.client
          .from('transactions')
          .select()
          .eq('user_id', user.id)
          .eq('kind', kindFilter)
          .lt('created_at', beforeCreatedAt)
          .order('created_at', ascending: false)
          .limit(txPageSize);
    }

    final res = await builder;
    return (res as List).cast<Map<String, dynamic>>();
  }
}
