import 'package:flutter/material.dart';
import 'package:greenstem/presentation/widgets/home/item_card.dart';

class ActiveTab extends StatefulWidget {
  const ActiveTab({super.key});

  @override
  State<ActiveTab> createState() => _ActiveTabState();
}

class _ActiveTabState extends State<ActiveTab> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: const Text(
            "Incoming Job",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(
          height: 16,
        ),
        Column(
          children: [
            ItemCard(state: "incoming"),
            ItemCard(state: "awaiting"),
            ItemCard(state: "picked up"),
            ItemCard(state: "en route"),
            ItemCard(state: "delivered")
          ],
        )
      ],
    );
  }
}
