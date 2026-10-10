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
| **4-digit PIN security lock** (on-device, SharedPreferences) | ✅ |
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
| PIN security | SharedPreferences (device-only) |

---

## Getting Started

```bash
# Install dependencies
flutter pub get

# Run on Android/iOS device or emulator
flutter run

# Run on web
flutter run -d chrome
```

> ⚠️ Keys now come from `--dart-define`. See `.env.example`. Never ship `sb_publishable` + VTpass/Paystack secrets in-app.

---

## Go live: VTpass + Paystack

Demo mode (default): `USE_EDGE=false` — fake verify + instant wallet credit, no keys needed.

Live mode:

```bash
# 1. DB: run supabase/migrations/001_wallet_ledger.sql in Supabase SQL editor
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
