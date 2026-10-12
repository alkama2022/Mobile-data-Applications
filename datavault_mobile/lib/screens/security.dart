import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import '../widgets.dart';

// ── PIN hashing helpers ───────────────────────────────────────────────────────

/// Generates a cryptographically random 32-byte hex salt.
String _generateSalt() {
  final rng = Random.secure();
  final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// Returns SHA-256(salt + pin) as a hex string.
String _hashPin(String salt, String pin) {
  final bytes = utf8.encode('$salt:$pin');
  return sha256.convert(bytes).toString();
}

// ── PIN Screen ────────────────────────────────────────────────────────────────

class PinScreen extends StatefulWidget {
  /// If true, the user is setting a new PIN. If false, they are verifying.
  final bool setup;

  /// Called when PIN is confirmed successfully (verified or newly set).
  final VoidCallback? onSuccess;

  const PinScreen({super.key, this.setup = false, this.onSuccess});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen>
    with SingleTickerProviderStateMixin {
  static const _hashKey = 'app_pin_hash';
  static const _saltKey = 'app_pin_salt';
  static const _pinEnabledKey = 'pin_enabled';

  String _entered = '';
  String? _firstPin; // used during setup confirmation step
  String _error = '';
  bool _confirming = false; // true when on the confirm step in setup

  late AnimationController _shake;
  late Animation<double> _offset;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _offset = Tween<double>(begin: 0, end: 12)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shake);
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void _onKey(String k) {
    if (_entered.length >= 4) return;
    HapticFeedback.selectionClick();
    setState(() {
      _entered += k;
      _error = '';
    });
    if (_entered.length == 4) _onComplete();
  }

  void _onDelete() {
    if (_entered.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  Future<void> _onComplete() async {
    final prefs = await SharedPreferences.getInstance();

    if (widget.setup) {
      if (!_confirming) {
        // First entry — hold in memory and ask to confirm.
        setState(() {
          _firstPin = _entered;
          _entered = '';
          _confirming = true;
        });
      } else {
        // Confirm step — PINs must match before anything is persisted.
        if (_entered == _firstPin) {
          final salt = _generateSalt();
          final hash = _hashPin(salt, _entered);
          await prefs.setString(_saltKey, salt);
          await prefs.setString(_hashKey, hash);
          await prefs.setBool(_pinEnabledKey, true);
          widget.onSuccess?.call();
        } else {
          _shakeAndClear('PINs do not match. Try again.');
          setState(() {
            _confirming = false;
            _firstPin = null;
          });
        }
      }
    } else {
      // Verify — hash the entered PIN with the stored salt and compare.
      final salt = prefs.getString(_saltKey) ?? '';
      final storedHash = prefs.getString(_hashKey) ?? '';
      if (salt.isEmpty || storedHash.isEmpty) {
        // No PIN set — treat as success so the user isn't locked out.
        widget.onSuccess?.call();
        return;
      }
      final enteredHash = _hashPin(salt, _entered);
      if (enteredHash == storedHash) {
        widget.onSuccess?.call();
      } else {
        _shakeAndClear('Incorrect PIN. Try again.');
      }
    }
  }

  void _shakeAndClear(String msg) {
    HapticFeedback.heavyImpact();
    _shake.forward(from: 0).then((_) => _shake.reverse());
    setState(() {
      _entered = '';
      _error = msg;
    });
  }

  String get _title {
    if (widget.setup) return _confirming ? 'Confirm your PIN' : 'Set a 4-digit PIN';
    return 'Enter your PIN';
  }

  String get _subtitle {
    if (widget.setup) {
      return _confirming
          ? 'Re-enter the PIN you just created.'
          : "You'll use this to confirm payments.";
    }
    return 'Your PIN protects sensitive actions.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const SizedBox(height: 24),
              const Brand(),
              const SizedBox(height: 40),
              Text(_title, style: displayStyleOf(context, size: 24)),
              const SizedBox(height: 8),
              Text(_subtitle,
                  style: const TextStyle(color: AppColors.mutedForeground),
                  textAlign: TextAlign.center),
              const SizedBox(height: 40),

              // PIN dots
              AnimatedBuilder(
                animation: _offset,
                builder: (_, child) => Transform.translate(
                  offset: Offset(
                      _offset.value *
                          (_shake.status == AnimationStatus.forward ? 1 : -1),
                      0),
                  child: child,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (i) {
                    final filled = i < _entered.length;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: filled ? AppColors.primary : Colors.transparent,
                        border: Border.all(
                          color:
                              filled ? AppColors.primary : AppColors.border,
                          width: 2,
                        ),
                      ),
                    );
                  }),
                ),
              ),

              const SizedBox(height: 16),
              if (_error.isNotEmpty)
                Text(_error,
                    style: const TextStyle(
                        color: AppColors.destructive,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),

              const Spacer(),
              _numpad(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _numpad() {
    const keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'del'],
    ];
    return Column(
      children: keys
          .map((row) => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: row.map((k) {
                  if (k.isEmpty) return const SizedBox(width: 90, height: 72);
                  if (k == 'del') {
                    return SizedBox(
                      width: 90,
                      height: 72,
                      child: TextButton(
                        onPressed: _onDelete,
                        child: const Icon(Icons.backspace_outlined,
                            color: AppColors.mutedForeground),
                      ),
                    );
                  }
                  return SizedBox(
                    width: 90,
                    height: 72,
                    child: TextButton(
                      onPressed: () => _onKey(k),
                      style: TextButton.styleFrom(
                        shape: const CircleBorder(),
                        backgroundColor: AppColors.muted,
                        foregroundColor: AppColors.foreground,
                        padding: EdgeInsets.zero,
                      ),
                      child: Text(k,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w700)),
                    ),
                  );
                }).toList(),
              ))
          .toList(),
    );
  }
}

// ── Security Settings Screen ──────────────────────────────────────────────────

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  static const _hashKey = 'app_pin_hash';
  static const _saltKey = 'app_pin_salt';
  static const _pinEnabledKey = 'pin_enabled';

  bool _pinEnabled = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pinEnabled = prefs.getBool(_pinEnabledKey) ?? false;
      _loading = false;
    });
  }

  Future<void> _togglePin(bool value) async {
    if (value) {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PinScreen(
          setup: true,
          onSuccess: () {
            Navigator.of(context).pop();
            setState(() => _pinEnabled = true);
            _showSnack('PIN protection enabled');
          },
        ),
      ));
    } else {
      // Require the user to verify their existing PIN before disabling.
      final prefs = await SharedPreferences.getInstance();
      final hasPin = prefs.getBool(_pinEnabledKey) ?? false;
      if (!hasPin) {
        await prefs.setBool(_pinEnabledKey, false);
        setState(() => _pinEnabled = false);
        return;
      }
      if (!mounted) return;
      final nav = Navigator.of(context);
      await nav.push(MaterialPageRoute(
        builder: (_) => PinScreen(
          setup: false,
          onSuccess: () async {
            final p = await SharedPreferences.getInstance();
            await p.remove(_hashKey);
            await p.remove(_saltKey);
            await p.setBool(_pinEnabledKey, false);
            if (mounted) {
              nav.pop();
              setState(() => _pinEnabled = false);
              _showSnack('PIN protection disabled');
            }
          },
        ),
      ));
    }
  }

  Future<void> _changePin() async {
    // Verify current PIN first so an attacker who unlocks the screen can't
    // immediately change the PIN without knowing the original.
    if (!mounted) return;
    final nav = Navigator.of(context);
    await nav.push(MaterialPageRoute(
      builder: (_) => PinScreen(
        setup: false,
        onSuccess: () => nav.pushReplacement(MaterialPageRoute(
          builder: (_) => PinScreen(
            setup: true,
            onSuccess: () {
              nav.pop();
              _showSnack('PIN updated successfully');
            },
          ),
        )),
      ),
    ));
  }

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Security')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(12)),
                      child:
                          const Icon(Icons.lock_rounded, color: AppColors.primary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text('App Security',
                              style: displayStyleOf(context, size: 17)),
                          const SizedBox(height: 2),
                          const Text('Protect your account with a PIN.',
                              style: TextStyle(
                                  color: AppColors.mutedForeground,
                                  fontSize: 13)),
                        ])),
                  ]),
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(children: [
                    SwitchListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      title: const Text('PIN protection',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: const Text(
                          'Require PIN to open the app and confirm payments'),
                      value: _pinEnabled,
                      onChanged: _togglePin,
                    ),
                    if (_pinEnabled) ...[
                      const Divider(height: 1, indent: 16),
                      ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: const Icon(Icons.edit_rounded,
                            color: AppColors.primary),
                        title: const Text('Change PIN',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _changePin,
                      ),
                    ],
                  ]),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: AppColors.successSoft,
                      borderRadius: BorderRadius.circular(12)),
                  child: const Row(children: [
                    Icon(Icons.verified_user_rounded,
                        color: AppColors.success, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                        child: Text(
                      'Your PIN is stored as a secure hash on this device only '
                      'and is never transmitted.',
                      style: TextStyle(
                          color: AppColors.success,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    )),
                  ]),
                ),
              ],
            ),
    );
  }
}
