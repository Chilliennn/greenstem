import 'package:flutter/material.dart';
import 'package:greenstem/domain/entities/delivery.dart';
import 'package:greenstem/domain/services/delivery_service.dart';

class DeliveryScreen extends StatefulWidget {
  const DeliveryScreen({super.key});

  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen> {
  List<Delivery> _deliveries = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDeliveries();
  }

  Future<void> _loadDeliveries() async {
    setState(() => _isLoading = true);

    try {
      final deliveries = await DeliveryService.getAllDeliveries();
      setState(() => _deliveries = deliveries);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading deliveries: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsCompleted(String deliveryId) async {
    try {
      await DeliveryService.markAsCompleted(deliveryId);
      _loadDeliveries(); // Refresh list
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delivery marked as completed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deliveries'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDeliveries,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _deliveries.isEmpty
          ? const Center(child: Text('No deliveries found'))
          : ListView.builder(
              itemCount: _deliveries.length,
              itemBuilder: (context, index) {
                final delivery = _deliveries[index];
                return Card(
                  margin: const EdgeInsets.all(8.0),
                  child: ListTile(
                    title: Text(
                      'Delivery ${delivery.deliveryId.substring(0, 8)}...',
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Status: ${delivery.status ?? 'Unknown'}'),
                        if (delivery.pickupLocation != null)
                          Text('From: ${delivery.pickupLocation}'),
                        if (delivery.deliveryLocation != null)
                          Text('To: ${delivery.deliveryLocation}'),
                      ],
                    ),
                    trailing: delivery.isPending
                        ? ElevatedButton(
                            onPressed: () =>
                                _markAsCompleted(delivery.deliveryId),
                            child: const Text('Complete'),
                          )
                        : Chip(
                            label: Text(delivery.status ?? 'Unknown'),
                            backgroundColor: delivery.isCompleted
                                ? Colors.green
                                : delivery.isOverdue
                                ? Colors.red
                                : Colors.orange,
                          ),
                    isThreeLine: true,
                  ),
                );
              },
            ),
    );
  }
}
