import 'package:flutter/material.dart';

class FaqPage extends StatelessWidget {
  const FaqPage({super.key});

  @override
  Widget build(BuildContext context) {
    final faqs = <Map<String, String>>[
      {
        'q': 'How do I start tracking?',
        'a': 'Just open the app and allow location permissions.',
      },
      {
        'q': 'What location source is used?',
        'a': 'Your phone GPS directly, and Bluetooth from the helmet.',
      },
      {
        'q': 'Does the helmet automatically call emergency services?',
        'a': 'Yes, in the event of a crash or fall, our AI system can detect it and send an automatic alert to your emergency contacts.',
      },
      {
        'q': 'Does the app work offline?',
        'a': 'Basic tracking works offline, but automatic emergency alerts require a mobile network connection.',
      },
      {
        'q': 'Is my ride data private?',
        'a': 'Yes, all ride and helmet data is encrypted and only accessible to you unless you share it.',
      },
      {
        'q': 'Which helmets are compatible?',
        'a': 'Our app works with all AI-enabled helmets from our product line. Check the compatibility section in the app for details.',
      },
      {
        'q': 'How do I update the helmet firmware?',
        'a': 'The app will notify you of any available firmware updates, which can be applied via Bluetooth.',
      },
      {
        'q': 'What happens if my phone battery dies during a ride?',
        'a': 'The helmet will still protect you physically, but crash alerts and tracking will be paused until your phone reconnects.',
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
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [Text(faqs[i]['a']!)],
            ),
          );
        },
      ),
    );
  }
}