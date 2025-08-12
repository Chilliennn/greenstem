import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

class CounterDisplay extends StatelessWidget {
  final int count;
  final String? label;

  const CounterDisplay({super.key, required this.count, this.label});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (label != null) ...[
              Text(label!, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
            ],
            Text(
              '$count',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
