# DataVault Mobile 📱

A full-featured Nigerian VTU & bill payment mobile app built with **Flutter** and **Supabase**.

---

## Features

| Feature | Status |
|---|---|
| Onboarding (animated 3-slide) | ✅ |
| Sign up / Sign in / Forgot password | ✅ |
| Email-based password reset | ✅ |
| Wallet balance display | ✅ |
| **Wallet top-up flow** (card/transfer/USSD) | ✅ |
| Buy airtime (all 4 networks) | ✅ |
| Buy data bundles (Daily/Weekly/Monthly) | ✅ |
| Electricity bill payment (11 Discos, prepaid/postpaid, verification) | ✅ |
| Cable TV renewal (DStv, GOtv, StarTimes) | ✅ |
| Education PINs (WAEC, NECO, JAMB, NABTEB) | ✅ |
| Internet bundles (Smile, Spectranet, ntel) | ✅ |
| Betting wallet funding | ✅ |
| **Transaction detail view** (with token/PIN copy) | ✅ |
| **Activity screen** with filter chips + search | ✅ |
| **Saved beneficiaries** (add, view, delete, re-pay) | ✅ |
| Notifications (auto mark-read, swipe delete, clear all) | ✅ |
| **Profile** with avatar upload (Supabase Storage) | ✅ |
| **Dark / Light / System theme** (persisted) | ✅ |
| **4-digit local app lock** (SharedPreferences; not transaction authorization) | ✅ |
| Proper unique transaction references (DVT-YYYYMMDD-XXXXXX) | ✅ |

---

## Tech Stack

| Layer | Tech |
|---|---|
| Framework | Flutter 3.x (Dart) |
| Backend / Auth | Supabase |
| Navigation | go_router |
| Typography | Google Fonts (Manrope + Sora) |
| Animations | flutter_animate |
| Theming | Material 3 + custom dark/light palette |
| Local storage | shared_preferences |
| Image picker | image_picker → Supabase Storage |
| Local app lock | SharedPreferences (not secure storage; not financial authorization) |

---

## Getting Started

The app requires a Supabase project in **both** debug and release builds. A
`.env` file is not loaded by Flutter automatically; pass the values using
`--dart-define`:

```bash
# Install dependencies
flutter pub get

# Run the debug app (the local demo paths still require Supabase)
flutter run --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_ANON_KEY=sb_publishable_your_key

# Run on web
flutter run -d chrome --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_ANON_KEY=sb_publishable_your_key
```

`USE_EDGE=false` (the debug default) selects debug-only demo purchase paths; it
does not provide offline mode or real provider payments. Demo writes may be
blocked by the project's row-level security policies. Do not use this mode to
represent successful real payments. Live payments require the Edge Functions
and server secrets described below. Only the Supabase publishable key belongs
in the app; never ship Supabase service-role, VTpass, or Paystack secret keys.
See `.env.example` for variable names (it is a reference file, not an
automatically loaded environment file).

The local 4-digit app lock is a convenience barrier only. It is stored in
`SharedPreferences` and is not a substitute for OS-backed secure storage,
account authentication, or server-side authorization of financial operations.

---

## Go live: VTpass + Paystack

Live mode:

```bash
# 1. DB: run migrations in order in the Supabase SQL editor:
#    supabase/migrations/001_wallet_ledger.sql
#    supabase/migrations/002_schedules.sql
#    supabase/migrations/003_storefronts.sql
#    supabase/migrations/004_profiles.sql
#    supabase/migrations/005_wallet_rpc_security.sql
# 2. Secrets:
supabase secrets set VTPASS_API_KEY=xxx VTPASS_SECRET_KEY=xxx VTPASS_BASE_URL=https://sandbox.vtpass.com
supabase secrets set PAYSTACK_SECRET_KEY=sk_test_xxx APP_CALLBACK_URL=https://yourapp/callback
supabase secrets set SUPABASE_URL=https://xxx.supabase.co SUPABASE_SERVICE_ROLE_KEY=eyJ...

# 3. Deploy:
supabase functions deploy vtu-verify vtu-pay vtu-query paystack-init paystack-webhook

# 4. Paystack dashboard: webhook URL -> https://xxx.supabase.co/functions/v1/paystack-webhook

# 5. Run app live:
flutter run --dart-define=SUPABASE_URL=https://xxx.supabase.co --dart-define=SUPABASE_ANON_KEY=eyJ... --dart-define=USE_EDGE=true
```

Flow: `lib/services/vtu_service.dart` -> `vtu-verify`/`vtu-pay` (debit -> VTpass `/api/pay` -> success/failed + auto-refund). Top-up: `lib/services/paystack_service.dart` -> `paystack-init` -> browser checkout -> `paystack-webhook` credits wallet idempotently on `reference`.

---

## Supabase Schema

Tables required:

| Table | Key columns |
|---|---|
| `profiles` | `id`, `full_name`, `phone`, `avatar_url`, `email_notifications`, `push_notifications` |
| `wallets` | `user_id`, `balance_kobo` |
| `transactions` | `user_id`, `kind`, `title`, `recipient`, `amount_kobo`, `reference`, `provider`, `status`, `metadata` |
| `beneficiaries` | `user_id`, `kind`, `nickname`, `recipient`, `provider` |
| `notifications` | `user_id`, `title`, `message`, `read_at` |

Storage bucket: `avatars` (public read)
