import 'package:flutter/material.dart';
import 'package:greenstem/domain/entities/delivery.dart';
import 'package:greenstem/domain/services/delivery_service.dart';
import 'package:greenstem/presentation/widgets/home/item_card.dart';
import 'package:intl/intl.dart';

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
  String _getDateSectionTitle(DateTime deliveredDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final thisWeekStart = today.subtract(Duration(days: today.weekday - 1));
    final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));
    final lastWeekEnd = thisWeekStart.subtract(const Duration(days: 1));
    final thisMonthStart = DateTime(now.year, now.month, 1);
    final lastMonthStart = DateTime(now.year, now.month - 1, 1);
    final lastMonthEnd = thisMonthStart.subtract(const Duration(days: 1));

    final deliveryDate =
        DateTime(deliveredDate.year, deliveredDate.month, deliveredDate.day);

    if (deliveryDate.isAtSameMomentAs(today)) {
      return 'Today';
    } else if (deliveryDate.isAtSameMomentAs(yesterday)) {
      return 'Yesterday';
    } else if (deliveryDate
            .isAfter(thisWeekStart.subtract(const Duration(days: 1))) &&
        deliveryDate.isBefore(today)) {
      return 'This Week';
    } else if (deliveryDate
            .isAfter(lastWeekStart.subtract(const Duration(days: 1))) &&
        deliveryDate.isBefore(thisWeekStart)) {
      return 'Last Week';
    } else if (deliveryDate
            .isAfter(thisMonthStart.subtract(const Duration(days: 1))) &&
        deliveryDate.isBefore(today)) {
      return 'This Month';
    } else if (deliveryDate
            .isAfter(lastMonthStart.subtract(const Duration(days: 1))) &&
        deliveryDate.isBefore(thisMonthStart)) {
      return 'Last Month';
    } else if (deliveredDate.year == now.year) {
      // same year, show month name
      return DateFormat('MMMM').format(deliveredDate);
    } else {
      // different year, show month and year
      return DateFormat('MMMM yyyy').format(deliveredDate);
    }
  }

  Map<String, List<Delivery>> _groupDeliveriesByDateSection(
      List<Delivery> deliveries) {
    final grouped = <String, List<Delivery>>{};

    for (final delivery in deliveries) {
      final deliveredDate = delivery.deliveredTime ?? delivery.updatedAt;
      final sectionTitle = _getDateSectionTitle(deliveredDate);

      if (!grouped.containsKey(sectionTitle)) {
        grouped[sectionTitle] = [];
      }
      grouped[sectionTitle]!.add(delivery);
    }

    // sort each section by delivered time (most recent first)
    for (final section in grouped.values) {
      section.sort((a, b) {
        final aDate = a.deliveredTime ?? a.updatedAt;
        final bDate = b.deliveredTime ?? b.updatedAt;
        return bDate.compareTo(aDate);
      });
    }

    return grouped;
  }

  List<String> _getSortedSectionKeys(
      Map<String, List<Delivery>> groupedDeliveries) {
    final keys = groupedDeliveries.keys.toList();

    // define section priority (lower number = higher priority)
    final sectionPriority = {
      'Today': 1,
      'Yesterday': 2,
      'This Week': 3,
      'Last Week': 4,
      'This Month': 5,
      'Last Month': 6,
    };

    keys.sort((a, b) {
      final aPriority = sectionPriority[a];
      final bPriority = sectionPriority[b];

      if (aPriority != null && bPriority != null) {
        return aPriority.compareTo(bPriority);
      } else if (aPriority != null) {
        return -1; // a has priority
      } else if (bPriority != null) {
        return 1; // b has priority
      } else {
        // both are month/year sections, sort by date
        final now = DateTime.now();

        // try to parse as month name or "month year"
        try {
          DateTime aDate, bDate;

          if (a.contains(' ')) {
            // "month year" format
            aDate = DateFormat('MMMM yyyy').parse(a);
          } else {
            // "month" format, assume current year
            aDate = DateFormat('MMMM').parse('$a ${now.year}');
          }

          if (b.contains(' ')) {
            // "month year" format
            bDate = DateFormat('MMMM yyyy').parse(b);
          } else {
            // "month" format, assume current year
            bDate = DateFormat('MMMM').parse('$b ${now.year}');
          }

          return bDate.compareTo(aDate); // most recent first
        } catch (e) {
          return a.compareTo(b); // fallback to alphabetical
        }
      }
    });

    return keys;
  }

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

    // sort deliveries by delivered date in descending order (most recent first)
    final sortedDeliveries = List<Delivery>.from(widget.deliveries);
    sortedDeliveries.sort((a, b) {
      final aDate = a.deliveredTime ?? a.updatedAt;
      final bDate = b.deliveredTime ?? b.updatedAt;
      return bDate.compareTo(aDate);
    });

    // group deliveries by date sections
    final groupedDeliveries = _groupDeliveriesByDateSection(sortedDeliveries);
    final sortedSectionKeys = _getSortedSectionKeys(groupedDeliveries);

    // flatten the grouped data for ListView
    final List<dynamic> listItems = [];
    for (final sectionKey in sortedSectionKeys) {
      listItems.add(sectionKey); // section title
      listItems
          .addAll(groupedDeliveries[sectionKey]!); // deliveries in this section
    }

    return ListView.builder(
      itemCount: listItems.length,
      itemBuilder: (context, index) {
        final item = listItems[index];

        if (item is String) {
          // section title
          return Padding(
            padding:
                EdgeInsets.only(left: 4, bottom: 6, top: index == 0 ? 0 : 16),
            child: Text(
              item,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          );
        } else if (item is Delivery) {
          // delivery item
          return ItemCard(
            state: item.status?.toLowerCase() ?? "delivered",
            delivery: item,
            deliveryService: widget.deliveryService,
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}
