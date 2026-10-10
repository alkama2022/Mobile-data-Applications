import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models.dart';
import '../theme.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  String q = '';

  @override
  Widget build(BuildContext context) {
    final visible = ServiceKind.values.where((s) => (s.title + s.description).toLowerCase().contains(q.toLowerCase()));
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          onChanged: (v) => setState(() => q = v),
          decoration: InputDecoration(
            hintText: 'Search services',
            prefixIcon: const Icon(Icons.search, color: AppColors.mutedForeground),
            filled: true,
            fillColor: AppColors.card,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
          ),
        ),
        const SizedBox(height: 20),
        ...visible.map((s) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => context.push('/app/services/${s.dbValue}'),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
              child: Row(children: [
                Container(width: 48, height: 48, decoration: BoxDecoration(color: s.iconBg, borderRadius: BorderRadius.circular(12)), child: Icon(s.icon, color: s.iconFg)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.title, style: displayStyle(size: 16)),
                  const SizedBox(height: 4),
                  Text(s.description, style: const TextStyle(color: AppColors.mutedForeground, fontSize: 13)),
                ])),
                const Text('›', style: TextStyle(fontSize: 22, color: AppColors.mutedForeground)),
              ]),
            ),
          ),
        )),
      ],
    );
  }
}
