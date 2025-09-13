import 'dart:async';
import 'package:flutter/material.dart';
import '../../../domain/entities/delivery.dart';
import '../../../domain/services/delivery_service.dart';
import '../../../data/repositories/delivery_repository_impl.dart';
import '../../../data/datasources/local/local_database_service.dart';
import '../../../data/datasources/remote/remote_delivery_datasource.dart';
import '../../../core/services/network_service.dart';

class DeliveryScreen extends StatefulWidget {
  const DeliveryScreen({super.key});

  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen> {
  late final DeliveryService _deliveryService;
  late final DeliveryRepositoryImpl _repository;
  bool _isOnline = false;
  StreamSubscription<bool>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _checkConnectivity();
    _listenToConnectivity();
  }

  void _initializeServices() {
    final localDataSource = LocalDatabaseService();
    final remoteDataSource = SupabaseDeliveryDataSource();
    _repository = DeliveryRepositoryImpl(localDataSource, remoteDataSource);
    _deliveryService = DeliveryService(_repository);
  }

  Future<void> _checkConnectivity() async {
    final isOnline = await NetworkService.hasConnection();
    if (mounted) {
      setState(() => _isOnline = isOnline);
    }
  }

  void _listenToConnectivity() {
    _connectivitySubscription =
        NetworkService.connectionStream.listen((isConnected) {
      if (mounted) {
        setState(() => _isOnline = isConnected);
      }
    });
  }

  Future<void> _syncData() async {
    try {
      await _deliveryService.syncData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data synced successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e')),
        );
      }
    }
  }

  Future<void> _markAsCompleted(String deliveryId) async {
    try {
      await _deliveryService.markAsCompleted(deliveryId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isOnline
                ? 'Delivery marked as completed'
                : 'Delivery marked as completed (will sync when online)'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _createSampleDelivery() async {
    try {
      final delivery = Delivery(
        deliveryId: '',
        userId: null,
        // Set to null to avoid foreign key constraint
        status: 'pending',
        pickupLocation: 'Warehouse A',
        deliveryLocation: 'Customer Address',
        dueDatetime: DateTime.now().add(const Duration(days: 1)),
        vehicleNumber: 'ABC123',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _deliveryService.createDelivery(delivery);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isOnline
                ? 'Delivery created'
                : 'Delivery created (will sync when online)'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating delivery: $e')),
        );
      }
    }
  }

  Future<void> _clearOldData() async {
    try {
      await _repository.clearCache();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Local data cleared')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error clearing data: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deliveries'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: Chip(
              label: Text(_isOnline ? 'Online' : 'Offline'),
              backgroundColor: _isOnline ? Colors.green : Colors.orange,
              labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: _isOnline ? _syncData : null,
            tooltip: _isOnline ? 'Sync data' : 'No connection',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear') {
                _clearOldData();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear',
                child: Text('Clear Local Data'),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<List<Delivery>>(
        stream: _deliveryService.watchAllDeliveries(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _checkConnectivity,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final deliveries = snapshot.data ?? [];

          if (deliveries.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.inbox, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No deliveries found',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isOnline
                        ? 'Data syncs automatically when online'
                        : 'Working offline - will sync when connected',
                    style: TextStyle(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _createSampleDelivery,
                    child: const Text('Create Sample Delivery'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: deliveries.length,
            itemBuilder: (context, index) {
              final delivery = deliveries[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                    'Delivery ${delivery.deliveryId.substring(0, 8)}...',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.circle,
                            size: 8,
                            color:
                                _getStatusColor(delivery.status ?? 'unknown'),
                          ),
                          const SizedBox(width: 4),
                          Text('Status: ${delivery.status ?? 'Unknown'}'),
                        ],
                      ),
                      if (delivery.pickupLocation != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.location_on,
                                size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'From: ${delivery.pickupLocation}',
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (delivery.deliveryLocation != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.flag,
                                size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'To: ${delivery.deliveryLocation}',
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (delivery.dueDatetime != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.schedule,
                                size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Due: ${_formatDateTime(delivery.dueDatetime!)}',
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  trailing: SizedBox(
                    width: 100,
                    child: delivery.isPending
                        ? ElevatedButton(
                            onPressed: () =>
                                _markAsCompleted(delivery.deliveryId),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(80, 32),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            child: const Text('Complete',
                                style: TextStyle(fontSize: 11)),
                          )
                        : Chip(
                            label: Text(
                              delivery.status ?? 'Unknown',
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.white),
                            ),
                            backgroundColor:
                                _getStatusColor(delivery.status ?? 'unknown'),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createSampleDelivery,
        tooltip: 'Create Delivery',
        child: const Icon(Icons.add),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    // Cancel the connectivity subscription to prevent memory leaks
    _connectivitySubscription?.cancel();
    _repository.dispose();
    super.dispose();
  }
}
