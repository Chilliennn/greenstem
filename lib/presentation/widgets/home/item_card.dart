import 'package:flutter/material.dart';
import 'package:greenstem/domain/entities/delivery.dart';
import 'package:greenstem/presentation/screens/profiles/profile_screen.dart';
import 'package:intl/intl.dart';
import '../../../domain/services/delivery_service.dart';

class ItemCard extends StatefulWidget {
  final String state;
  final Delivery? delivery;
  final DeliveryService? deliveryService;

  const ItemCard(
      {super.key, required this.state, this.delivery, this.deliveryService});

  @override
  State<ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<ItemCard> {
  late String state = widget.state;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case "incoming":
        return _IncomingCard(
            delivery: widget.delivery, deliveryService: widget.deliveryService);

      case "awaiting":
        return _StatusCard(
          label: "Awaiting",
          color: Color(0xFFFEA41D),
          delivery: widget.delivery,
          deliveryService: widget.deliveryService,
        );

      case "picked up":
        return _StatusCard(
          label: "Picked up",
          color: Color(0xFF4B97FA),
          delivery: widget.delivery,
          deliveryService: widget.deliveryService,
        );

      case "en route":
        return _StatusCard(
          label: "En Route",
          color: Color(0xFFC084FC),
          delivery: widget.delivery,
          deliveryService: widget.deliveryService,
        );

      case "delivered":
        return _StatusCard(
          label: "Delivered",
          color: Color(0xFFC084FC),
          delivery: widget.delivery,
          deliveryService: widget.deliveryService,
        );

      default:
        return _StatusCard(
          label: "Unknown Status",
          color: Colors.grey,
          delivery: widget.delivery,
          deliveryService: widget.deliveryService,
        );
    }
  }
}

class _IncomingCard extends StatelessWidget {
  final Delivery? delivery;
  final DeliveryService? deliveryService;

  const _IncomingCard({this.delivery, this.deliveryService});

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
            Icon(
              Icons.inbox_rounded,
              color: Colors.white,
              size: 32,
            ),
            if (delivery != null) ...[
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "From",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  Text(
                    "To",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
              SizedBox(
                height: 4,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (delivery!.pickupLocation != null)
                    FutureBuilder<String>(
                      future: deliveryService
                              ?.getLocationName(delivery!.pickupLocation) ??
                          Future.value(delivery!.pickupLocation ?? 'Unknown'),
                      builder: (context, snapshot) {
                        return Text(
                          snapshot.data ??
                              delivery!.pickupLocation ??
                              'Loading',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600),
                        );
                      },
                    ),
                  if (delivery!.deliveryLocation != null)
                    FutureBuilder<String>(
                      future: deliveryService
                              ?.getLocationName(delivery!.deliveryLocation) ??
                          Future.value(delivery!.deliveryLocation ?? 'Unknown'),
                      builder: (context, snapshot) {
                        return Text(
                          snapshot.data ??
                              delivery!.deliveryLocation ??
                              'Loading...',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600),
                        );
                      },
                    ),
                ],
              ),
              SizedBox(
                height: 4,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Due ${DateFormat("dd MMM yyyy - hh:mm a").format(delivery!.dueDatetime!)}',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
              SizedBox(
                height: 16,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        spacing: 8,
                        children: [
                          Icon(
                            Icons.shopping_bag_outlined,
                            color: Colors.white,
                            size: 18,
                          ),
                          StreamBuilder<int?>(
                            stream: deliveryService?.getNumberOfDeliveryPartsByDeliveryId(delivery!.deliveryId),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return Text(
                                  "loading items",
                                  style: TextStyle(color: Colors.grey, fontSize: 12),
                                );
                              }

                              final itemCount = snapshot.data ?? 0;
                              return Text(
                                "$itemCount items",
                                style: TextStyle(color: Colors.grey, fontSize: 12),
                              );
                            },
                          ),
                        ],
                      ),
                      SizedBox(
                        height: 6,
                      ),
                      Row(
                        spacing: 8,
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          Text(
                            "n km",
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          )
                        ],
                      )
                    ],
                  ),
                  TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      "Accept",
                      style: TextStyle(fontSize: 14),
                    ),
                  )
                ],
              )
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
  final DeliveryService? deliveryService;

  const _StatusCard({
    required this.label,
    required this.color,
    this.delivery,
    this.deliveryService,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // TODO: waiting delivery_detail_screen.dart to be implemented
      // onTap: () async => await Navigator.push(
      //   context,
      //   MaterialPageRoute(builder: (context) => const ProfileScreen()),
      // ),
      child: Card(
        color: Color(0xFF1D1D1D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(
                    Icons.inbox_rounded,
                    color: label == 'Awaiting'
                        ? Color(0xFFFEA41D)
                        : label == 'Picked up'
                            ? Color(0xFF4B97FA)
                            : label == 'En Route'
                                ? Color(0xFFC084FC)
                                : Color(0xFF00B65E),
                    size: 32,
                  ),
                  Text(
                    label,
                    style: TextStyle(
                        color: label == 'Awaiting'
                            ? Color(0xFFFEA41D)
                            : label == 'Picked up'
                                ? Color(0xFF4B97FA)
                                : label == 'En Route'
                                    ? Color(0xFFC084FC)
                                    : Color(0xFF00B65E),
                        fontWeight: FontWeight.w800),
                  )
                ],
              ),
              if (delivery != null) ...[
                SizedBox(height: 8),
                Text(
                  label == 'Awaiting'
                      ? 'Pick up from'
                      : label == 'Picked up'
                          ? 'Deliver to'
                          : label == 'En Route'
                              ? 'Delivering to'
                              : 'Delivered to',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                SizedBox(
                  height: 4,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    FutureBuilder<String>(
                      future: deliveryService?.getLocationName(
                            label == 'Awaiting'
                                ? delivery?.pickupLocation
                                : delivery?.deliveryLocation,
                          ) ??
                          Future.value(
                            label == 'Awaiting'
                                ? delivery?.pickupLocation ?? 'Unknown'
                                : delivery?.deliveryLocation ?? 'Unknown',
                          ),
                      builder: (context, snapshot) {
                        return Text(
                          snapshot.data ??
                              (label == 'Awaiting'
                                  ? delivery?.pickupLocation ?? 'Unknown'
                                  : delivery?.deliveryLocation ?? 'Unknown'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                SizedBox(
                  height: 20,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          spacing: 8,
                          children: [
                            Icon(
                              Icons.shopping_bag_outlined,
                              color: Colors.white,
                              size: 18,
                            ),
                            StreamBuilder<int?>(
                              stream: deliveryService?.getNumberOfDeliveryPartsByDeliveryId(delivery!.deliveryId),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return Text(
                                    "loading items",
                                    style: TextStyle(color: Colors.grey, fontSize: 12),
                                  );
                                }

                                final itemCount = snapshot.data ?? 0;
                                return Text(
                                  "$itemCount items",
                                  style: TextStyle(color: Colors.grey, fontSize: 12),
                                );
                              },
                            ),
                          ],
                        ),
                        SizedBox(
                          height: 6,
                        ),
                        Row(
                          spacing: 8,
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            Text(
                              "n km",
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 12),
                            )
                          ],
                        )
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      spacing: 4,
                      children: [
                        label == 'Delivered'
                            ? Align(
                                alignment: Alignment.topRight,
                                child: Text(
                                  'Delivered at',
                                  style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600),
                                ),
                              )
                            : Container(),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Text(
                            '${label == 'Delivered' ? '' : 'Due '}${DateFormat("dd MMM yyyy - hh:mm a").format(delivery!.dueDatetime!)}',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ),
                      ],
                    )
                  ],
                )
              ],
            ],
          ),
        ),
      ),
    );
  }
}
