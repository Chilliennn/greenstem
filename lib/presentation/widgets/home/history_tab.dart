import 'package:flutter/material.dart';
import 'package:greenstem/domain/entities/delivery.dart';
import 'package:greenstem/domain/services/delivery_service.dart';
import 'package:greenstem/presentation/widgets/home/item_card.dart';

class HistoryTab extends StatefulWidget {
  final List<Delivery> deliveries;
  final DeliveryService deliveryService;

  const HistoryTab({
    super.key,
    required this.deliveries,
    required this.deliveryService,
  });

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  @override
  Widget build(BuildContext context) {
    if (widget.deliveries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'No delivery history',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Completed deliveries will appear here',
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
            child: Padding(
              padding: EdgeInsets.only(left: 4, bottom: 6),
              child: Text(
                "History",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )),
        Expanded(
          child: ListView.builder(
            itemCount: widget.deliveries.length,
            itemBuilder: (context, index) {
              final delivery = widget.deliveries[index];
              return ItemCard(
                state: delivery.status?.toLowerCase() ?? "delivered",
                delivery: delivery,
                deliveryService: widget.deliveryService,
              );
            },
          ),
        ),
      ],
    );
  }
}
