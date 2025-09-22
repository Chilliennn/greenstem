import 'package:flutter/material.dart';
import 'package:greenstem/domain/entities/delivery.dart';
import 'package:intl/intl.dart';
import '../../../domain/services/delivery_service.dart';
import '../../../core/utils/distance_calculator.dart';
import '../../../presentation/widgets/delivery_detail/picked_up.dart';
import '../../../presentation/screens/delivery_detail/delivery_detail_screen.dart';
import '../../../presentation/widgets/delivery_detail/awaiting.dart';
import '../../../presentation/widgets/delivery_detail/en_route.dart';
import '../../../presentation/widgets/delivery_detail/delivered.dart';

_setUseApi() => true;

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

  Future<String> _calculateDistance() async {
    if (delivery?.pickupLocation == null ||
        delivery?.deliveryLocation == null ||
        deliveryService == null) {
      return 'n/a';
    }

    try {
      final coordinates = await deliveryService!.getDeliveryCoordinates(
        delivery!.pickupLocation!,
        delivery!.deliveryLocation!,
      );

      final distance = await DistanceCalculator.calculateDistance(
        coordinates['pickupLat'],
        coordinates['pickupLon'],
        coordinates['deliveryLat'],
        coordinates['deliveryLon'],
        useApi: _setUseApi(),
      );

      return DistanceCalculator.formatDistance(distance);
    } catch (e) {
      print('error calculating distance: $e');
      return 'n/a';
    }
  }

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
                            stream: deliveryService
                                ?.getNumberOfDeliveryPartsByDeliveryId(
                                    delivery!.deliveryId),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return Text(
                                  "loading items",
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 12),
                                );
                              }

                              final itemCount = snapshot.data ?? 0;
                              return Text(
                                "$itemCount items",
                                style:
                                    TextStyle(color: Colors.grey, fontSize: 12),
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
                          FutureBuilder<String>(
                            future: _calculateDistance(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return Text(
                                  "calculating...",
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 12),
                                );
                              }

                              return Text(
                                snapshot.data ?? 'n/a',
                                style:
                                    TextStyle(color: Colors.grey, fontSize: 12),
                              );
                            },
                          ),
                        ],
                      )
                    ],
                  ),
                  TextButton(
                    onPressed: () async {
                      if (delivery != null && deliveryService != null) {
                        try {
                          // show loading
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );

                          // update delivery
                          final updatedDelivery = delivery!.copyWith(
                            status: 'awaiting',
                            updatedAt: DateTime.now(),
                          );

                          await deliveryService!
                              .updateDelivery(updatedDelivery);

                          // close loading dialog
                          if (context.mounted) {
                            Navigator.pop(context);

                            // show success message
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Delivery accepted successfully!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          // close loading dialog
                          if (context.mounted) {
                            Navigator.pop(context);

                            // show error message
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to accept delivery: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      }
                    },
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
  final Function(Delivery)? onDeliveryUpdated = null;

  const _StatusCard({
    required this.label,
    required this.color,
    this.delivery,
    this.deliveryService,
  });

  Future<String> _calculateDistance() async {
    if (delivery?.pickupLocation == null ||
        delivery?.deliveryLocation == null ||
        deliveryService == null) {
      return 'n/a';
    }

    try {
      final coordinates = await deliveryService!.getDeliveryCoordinates(
        delivery!.pickupLocation!,
        delivery!.deliveryLocation!,
      );

      final distance = await DistanceCalculator.calculateDistance(
        coordinates['pickupLat'],
        coordinates['pickupLon'],
        coordinates['deliveryLat'],
        coordinates['deliveryLon'],
        useApi: _setUseApi(),
      );

      return DistanceCalculator.formatDistance(distance);
    } catch (e) {
      print('error calculating distance: $e');
      return 'n/a';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (delivery != null) {
          if (label == "Awaiting") {
            // Add navigation to AwaitingPage
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AwaitingPage(delivery: delivery!),
              ),
            );
          } else if (label == "Picked up") {
            // Direct navigation to PickedUpPage for picked up deliveries
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PickedUpPage(delivery: delivery!),
              ),
            );
          } else if (label == "En Route") {
            // Add navigation to EnRoutePage
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EnRoutePage(delivery: delivery!),
              ),
            );
          } else if (label == "Delivered") {
            // Add navigation to DeliveredPage
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DeliveredPage(delivery: delivery!),
              ),
            );
          } else {
            // Navigate to DeliveryDetailScreen for other statuses
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DeliveryDetailScreen(
                  delivery: delivery!,
                  onDeliveryUpdated: onDeliveryUpdated ?? (_) {},
                ),
              ),
            );
          }
        }
      },
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
                              stream: deliveryService
                                  ?.getNumberOfDeliveryPartsByDeliveryId(
                                      delivery!.deliveryId),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return Text(
                                    "loading items",
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 12),
                                  );
                                }

                                final itemCount = snapshot.data ?? 0;
                                return Text(
                                  "$itemCount items",
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 12),
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
                            FutureBuilder<String>(
                              future: _calculateDistance(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return Text(
                                    "calculating...",
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 12),
                                  );
                                }

                                return Text(
                                  snapshot.data ?? 'n/a',
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 12),
                                );
                              },
                            ),
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
