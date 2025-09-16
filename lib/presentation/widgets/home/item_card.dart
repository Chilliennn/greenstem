import 'package:flutter/material.dart';

class ItemCard extends StatefulWidget {
  String state;

  ItemCard({super.key, required this.state});

  @override
  State<ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<ItemCard> {
  late String state = widget.state;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case "incoming":
        return _IncomingCard();

      case "awaiting":
        return _StatusCard(
          label: "Awaiting",
          color: Color(0xFFFEA41D)!,
        );

      case "picked up":
        return _StatusCard(
          label: "Picked up",
          color: Color(0xFF4B97FA)!,
        );

      case "en route":
        return _StatusCard(
          label: "En route",
          color: Color(0xFFC084FC)!,
        );

      case "delivered":
        return _DeliveredCard();

      default:
        return const Text("Unknown");
    }
  }
}

class _IncomingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      color: Color(0xFF1D1D1D),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.inbox, color: Colors.white),
            SizedBox(width: 10),
            Text(
              "Incoming Job",
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusCard({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.local_shipping, color: Colors.white),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeliveredCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey[800],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF00B65E)),
            SizedBox(width: 10),
            Text(
              "Delivered",
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
