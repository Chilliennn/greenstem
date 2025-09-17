import 'package:flutter/material.dart';
import 'package:greenstem/domain/entities/delivery.dart';

class ItemCard extends StatefulWidget {
  final String state;
  final Delivery? delivery;

  const ItemCard({super.key, required this.state, this.delivery});

  @override
  State<ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<ItemCard> {
  late String state = widget.state;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case "incoming":
      case "pending":
        return _IncomingCard(delivery: widget.delivery);

      case "awaiting":
        return _StatusCard(
          label: "Awaiting",
          color: Color(0xFFFEA41D),
          delivery: widget.delivery,
        );

      case "picked up":
        return _StatusCard(
          label: "Picked up",
          color: Color(0xFF4B97FA),
          delivery: widget.delivery,
        );

      case "en route":
        return _StatusCard(
          label: "En route",
          color: Color(0xFFC084FC),
          delivery: widget.delivery,
        );

      case "delivered":
        return _DeliveredCard(delivery: widget.delivery);

      default:
        return _StatusCard(
          label: "Unknown Status",
          color: Colors.grey,
          delivery: widget.delivery,
        );
    }
  }
}

class _IncomingCard extends StatelessWidget {
  final Delivery? delivery;

  const _IncomingCard({this.delivery});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Color(0xFF1D1D1D),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.inbox, color: Colors.white),
                SizedBox(width: 10),
                Text(
                  "Incoming Job",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (delivery != null) ...[
              SizedBox(height: 8),
              Text(
                'ID: ${delivery!.deliveryId}',
                style: TextStyle(
                  color: Colors.grey[300],
                  fontSize: 12,
                ),
              ),
              if (delivery!.pickupLocation != null)
                Text(
                  'From: ${delivery!.pickupLocation}',
                  style: TextStyle(
                    color: Colors.grey[300],
                    fontSize: 12,
                  ),
                ),
              if (delivery!.deliveryLocation != null)
                Text(
                  'To: ${delivery!.deliveryLocation}',
                  style: TextStyle(
                    color: Colors.grey[300],
                    fontSize: 12,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String label;
  final Color color;
  final Delivery? delivery;

  const _StatusCard({
    required this.label,
    required this.color,
    this.delivery,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_shipping, color: Colors.white),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (delivery != null) ...[
              SizedBox(height: 8),
              Text(
                'ID: ${delivery!.deliveryId}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
              if (delivery!.pickupLocation != null)
                Text(
                  'From: ${delivery!.pickupLocation}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              if (delivery!.deliveryLocation != null)
                Text(
                  'To: ${delivery!.deliveryLocation}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DeliveredCard extends StatelessWidget {
  final Delivery? delivery;

  const _DeliveredCard({this.delivery});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey[800],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF00B65E)),
                SizedBox(width: 10),
                Text(
                  "Delivered",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (delivery != null) ...[
              SizedBox(height: 8),
              Text(
                'ID: ${delivery!.deliveryId}',
                style: TextStyle(
                  color: Colors.grey[300],
                  fontSize: 12,
                ),
              ),
              if (delivery!.pickupLocation != null)
                Text(
                  'From: ${delivery!.pickupLocation}',
                  style: TextStyle(
                    color: Colors.grey[300],
                    fontSize: 12,
                  ),
                ),
              if (delivery!.deliveryLocation != null)
                Text(
                  'To: ${delivery!.deliveryLocation}',
                  style: TextStyle(
                    color: Colors.grey[300],
                    fontSize: 12,
                  ),
                ),
              if (delivery!.dueDatetime != null)
                Text(
                  'Delivered: ${_formatDate(delivery!.dueDatetime!)}',
                  style: TextStyle(
                    color: Color(0xFF00B65E),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
