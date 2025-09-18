import 'package:flutter/material.dart';
import 'package:greenstem/domain/entities/delivery.dart';
import 'package:greenstem/domain/services/delivery_service.dart';
import 'package:greenstem/presentation/widgets/home/item_card.dart';

class ActiveTab extends StatefulWidget {
  final List<Delivery> deliveries;
  final DeliveryService deliveryService;

  const ActiveTab({
    super.key,
    required this.deliveries,
    required this.deliveryService,
  });

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
            const Text(
              'No active deliveries',
              style: TextStyle(
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

    // Split deliveries into ongoing and incoming
    final ongoingDeliveries = widget.deliveries
        .where((d) => d.status?.toLowerCase() != "incoming" && d.status?.toLowerCase() != "pending")
        .toList();

    final incomingDeliveries = widget.deliveries
        .where((d) => d.status?.toLowerCase() == "incoming" || d.status?.toLowerCase() == "pending" || d.status == null)
        .toList();

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // Ongoing section
        if (ongoingDeliveries.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              "Ongoing",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          for (final delivery in ongoingDeliveries)
            ItemCard(
              state: delivery.status?.toLowerCase() ?? "incoming",
              delivery: delivery,
              deliveryService: widget.deliveryService,
            ),
        ],

        // Incoming section
        if (incomingDeliveries.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(left: 6, top: 24, bottom: 6),
            child: Text(
              "Incoming Job",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          for (final delivery in incomingDeliveries)
            ItemCard(
              state: delivery.status?.toLowerCase() ?? "incoming",
              delivery: delivery,
              deliveryService: widget.deliveryService,
            ),
        ],
      ],
    );
  }
}
