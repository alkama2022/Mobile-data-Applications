import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../config.dart';
import '../theme.dart';
import '../widgets.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int i = 0;
  final PageController _page = PageController();

  static const slides = [
    (
      icon: Icons.wifi_rounded,
      kicker: 'Connect instantly',
      title: 'Buy data in seconds',
      copy: 'Affordable bundles for every major network, delivered without delay.',
      color: Color(0xFF2F6FED),
    ),
    (
      icon: Icons.verified_user_rounded,
      kicker: 'Built for trust',
      title: 'Simple. Fast. Secure.',
      copy: 'Clear payment reviews, instant receipts, and a protected wallet.',
      color: Color(0xFF2E9E77),
    ),
    (
      icon: Icons.bolt_rounded,
      kicker: 'One app, more ease',
      title: 'Everything you need',
      copy: 'Airtime, utilities, TV and education payments in one calm experience.',
      color: Color(0xFFF0B429),
    ),
  ];

  @override
  void initState() {
    super.initState();
    final user = AppConfig.client.auth.currentUser;
    if (user != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/app'));
    }
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _next() {
    if (i < slides.length - 1) {
      _page.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    } else {
      context.go('/auth');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brand,
      body: SafeArea(
        child: Column(children: [
          // Top bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(children: [
              const Brand(inverse: true),
              const Spacer(),
              TextButton(
                onPressed: () => context.go('/auth'),
                child: const Text('Skip', style: TextStyle(color: Colors.white60, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),

          // Slides
          Expanded(
            child: PageView.builder(
              controller: _page,
              onPageChanged: (v) => setState(() => i = v),
              itemCount: slides.length,
              itemBuilder: (_, idx) {
                final slide = slides[idx];
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(children: [
                    const Spacer(),
                    // Animated icon
                    Stack(alignment: Alignment.center, children: [
                      Container(width: 280, height: 280, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1.5))),
                      Container(width: 200, height: 200, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.06), width: 1.5))),
                      Container(
                        width: 120, height: 120,
                        decoration: BoxDecoration(
                          color: slide.color,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: slide.color.withValues(alpha: 0.5), blurRadius: 48)],
                        ),
                        child: Icon(slide.icon, color: Colors.white, size: 52),
                      ),
                    ]).animate(key: ValueKey(idx)).scale(begin: const Offset(0.7, 0.7), duration: 500.ms, curve: Curves.elasticOut),
                    const Spacer(),
                    Text(slide.kicker.toUpperCase(), style: const TextStyle(color: AppColors.highlight, letterSpacing: 2, fontWeight: FontWeight.w800, fontSize: 11))
                        .animate(key: ValueKey('kicker-$idx')).fadeIn(duration: 400.ms).slideY(begin: 0.3, curve: Curves.easeOut),
                    const SizedBox(height: 14),
                    Text(slide.title, textAlign: TextAlign.center, style: displayStyle(size: 30, color: Colors.white))
                        .animate(key: ValueKey('title-$idx')).fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.3, curve: Curves.easeOut),
                    const SizedBox(height: 12),
                    Text(slide.copy, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, height: 1.6, fontSize: 15))
                        .animate(key: ValueKey('copy-$idx')).fadeIn(duration: 400.ms, delay: 200.ms),
                    const SizedBox(height: 32),
                  ]),
                );
              },
            ),
          ),

          // Dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(slides.length, (n) => AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: n == i ? 28 : 8, height: 8,
              decoration: BoxDecoration(color: n == i ? AppColors.highlight : Colors.white24, borderRadius: BorderRadius.circular(4)),
            )),
          ),
          const SizedBox(height: 20),

          // Buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            child: Column(children: [
              SizedBox(
                width: double.infinity, height: 54,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.highlight,
                    foregroundColor: AppColors.highlightForeground,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _next,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      i < slides.length - 1 ? 'Next' : 'Get started',
                      key: ValueKey(i),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ),
                ),
              ),
              if (i == slides.length - 1) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity, height: 48,
                  child: TextButton(
                    onPressed: () => context.go('/auth'),
                    child: const Text('Already have an account? Sign in', style: TextStyle(color: Colors.white60, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}
