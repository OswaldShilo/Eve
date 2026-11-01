import 'package:flutter/material.dart';

class BentoCardData {
  const BentoCardData({required this.title, required this.value, required this.description, this.fullWidth = false});
  final String title;
  final String value;
  final String description;
  final bool fullWidth;
}

class BentoCard extends StatelessWidget {
  const BentoCard({super.key, required this.data, this.onTap});

  final BentoCardData data;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('bento-card-${data.title}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 8)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            const SizedBox(height: 6),
            Text(data.value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 4),
            Text(data.description, style: const TextStyle(fontSize: 12, color: Color(0xFF666666))),
          ],
        ),
      ),
    );
  }
}
