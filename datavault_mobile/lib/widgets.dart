import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'theme.dart';

class Brand extends StatelessWidget {
  final bool inverse;
  final bool compact;
  const Brand({super.key, this.inverse = false, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final fg = inverse ? Colors.white : AppColors.foreground;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: AppColors.highlight, borderRadius: BorderRadius.circular(10)),
          child: Stack(
            alignment: Alignment.center,
            children: const [
              Icon(Icons.verified_user_rounded, color: AppColors.highlightForeground, size: 22),
              Positioned(bottom: 8, child: Icon(Icons.bolt, color: AppColors.highlightForeground, size: 12)),
            ],
          ),
        ),
        if (!compact) ...[
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('DataVault', style: displayStyle(size: 20, color: fg)),
              Text('STAY CONNECTED', style: TextStyle(fontSize: 9, letterSpacing: 1.6, color: fg.withValues(alpha: 0.7), fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ],
    );
  }
}

class Eyebrow extends StatelessWidget {
  final String text;
  final Color? color;
  const Eyebrow(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2, color: color ?? AppColors.primary));
}

class StateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  const StateView({super.key, required this.icon, required this.title, required this.description});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 44, color: AppColors.mutedForeground),
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 6),
          Text(description, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.mutedForeground, fontSize: 13)),
        ]),
      );
}

/// A small info banner
class InfoBanner extends StatelessWidget {
  final String message;
  final Color? color;
  final Color? bgColor;
  final IconData icon;
  const InfoBanner({super.key, required this.message, this.color, this.bgColor, this.icon = Icons.info_outline_rounded});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor ?? AppColors.primarySoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Icon(icon, color: color ?? AppColors.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: TextStyle(color: color ?? AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600))),
        ]),
      );
}

/// Animated shimmer skeleton for loading states
class Skeleton extends StatelessWidget {
  final double width;
  final double height;
  final double radius;
  const Skeleton({super.key, required this.width, required this.height, this.radius = 8});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = dark ? AppColors.darkBorder : AppColors.muted;
    final shine = dark ? AppColors.darkCard : Colors.white;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(radius)),
    )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(duration: 1200.ms, color: shine, angle: 0.3);
  }
}

/// Full-page skeleton for the home screen
class HomeSkeletonLoader extends StatelessWidget {
  const HomeSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const Skeleton(width: 160, height: 28),
      const SizedBox(height: 8),
      const Skeleton(width: 240, height: 16),
      const SizedBox(height: 20),
      // Wallet card skeleton
      Container(
        height: 150,
        decoration: BoxDecoration(color: AppColors.muted, borderRadius: BorderRadius.circular(16)),
      ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms, color: Colors.white.withValues(alpha: 0.15)),
      const SizedBox(height: 28),
      const Skeleton(width: 120, height: 20),
      const SizedBox(height: 14),
      GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
        children: List.generate(7, (i) => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Skeleton(width: 52, height: 52, radius: 14),
          const SizedBox(height: 6),
          const Skeleton(width: 44, height: 12),
        ])),
      ),
    ],
  );
}
