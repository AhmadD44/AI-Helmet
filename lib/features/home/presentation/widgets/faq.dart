import 'package:flutter/material.dart';

class FaqPage extends StatelessWidget {
  const FaqPage({super.key});

  @override
  Widget build(BuildContext context) {
    final faqs = <Map<String, String>>[
      {
        'q': 'How do I start tracking?',
        'a': 'Just open the app and allow location permissions.'
      },
      {
        'q': 'What location source is used?',
        'a': 'Your phone GPS directly, no Bluetooth / external device.'
      },
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('FAQ')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: faqs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          return Material(
            elevation: 0,
            color: Theme.of(context)
                .colorScheme
                .surfaceVariant
                .withOpacity(0.35),
            borderRadius: BorderRadius.circular(14),
            child: ExpansionTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              collapsedShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              title: Text(faqs[i]['q']!),
              childrenPadding:
                  const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [Text(faqs[i]['a']!)],
            ),
          );
        },
      ),
    );
  }
}
