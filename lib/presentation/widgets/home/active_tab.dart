import 'package:flutter/material.dart';
import 'package:greenstem/domain/entities/delivery.dart';
import 'package:greenstem/presentation/widgets/home/item_card.dart';

class ActiveTab extends StatefulWidget {
  final List<Delivery> deliveries;

  const ActiveTab({super.key, required this.deliveries});

  @override
  State<ActiveTab> createState() => _ActiveTabState();
}

class _ActiveTabState extends State<ActiveTab> {
  @override
  Widget build(BuildContext context) {
    if (widget.deliveries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'No active deliveries',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Active deliveries will appear here',
              style: TextStyle(
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            "Incoming Job",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            itemCount: widget.deliveries.length,
            itemBuilder: (context, index) {
              final delivery = widget.deliveries[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: ItemCard(
                  state: delivery.status?.toLowerCase() ?? "incoming",
                  delivery: delivery,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
