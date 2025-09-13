import 'dart:async';
import 'package:flutter/material.dart';
import '../../../domain/entities/delivery_part.dart';
import '../../../domain/services/delivery_part_service.dart';
import '../../../data/repositories/delivery_part_repository_impl.dart';
import '../../../data/datasources/local/local_delivery_part_database_service.dart';
import '../../../data/datasources/remote/remote_delivery_part_datasource.dart';
import '../../../core/services/network_service.dart';

class DeliveryPartScreen extends StatefulWidget {
  final String? deliveryId;

  const DeliveryPartScreen({super.key, this.deliveryId});

  @override
  State<DeliveryPartScreen> createState() => _DeliveryPartScreenState();
}

class _DeliveryPartScreenState extends State<DeliveryPartScreen> {
  late final DeliveryPartService _deliveryPartService;
  late final DeliveryPartRepositoryImpl _repository;
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
    final localDataSource = LocalDeliveryPartDatabaseService();
    final remoteDataSource = SupabaseDeliveryPartDataSource();
    _repository = DeliveryPartRepositoryImpl(localDataSource, remoteDataSource);
    _deliveryPartService = DeliveryPartService(_repository);
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
      await _deliveryPartService.syncData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delivery parts synced successfully')),
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

  Future<void> _createSampleDeliveryPart() async {
    try {
      final deliveryPart = DeliveryPart(
        deliveryId: widget.deliveryId ?? 'sample-delivery-id',
        partId: null,
        // Set to null to avoid foreign key constraint
        quantity: 10,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _deliveryPartService.createDeliveryPart(deliveryPart);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isOnline
                ? 'Delivery part created'
                : 'Delivery part created (will sync when online)'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating delivery part: $e')),
        );
      }
    }
  }

  Future<void> _updateQuantity(String deliveryId, int newQuantity) async {
    try {
      await _deliveryPartService.updateQuantity(deliveryId, newQuantity);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isOnline
                ? 'Quantity updated'
                : 'Quantity updated (will sync when online)'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating quantity: $e')),
        );
      }
    }
  }

  Future<void> _clearOldData() async {
    try {
      await _repository.clearCache();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Local delivery parts data cleared')),
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

  void _showQuantityDialog(DeliveryPart deliveryPart) {
    final controller = TextEditingController(
      text: deliveryPart.quantity?.toString() ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Quantity'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Quantity',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newQuantity = int.tryParse(controller.text);
              if (newQuantity != null) {
                _updateQuantity(deliveryPart.deliveryId, newQuantity);
                Navigator.pop(context);
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.deliveryId != null
            ? 'Delivery Parts - ${widget.deliveryId!.substring(0, 8)}...'
            : 'All Delivery Parts'),
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
      body: StreamBuilder<List<DeliveryPart>>(
        stream: widget.deliveryId != null
            ? _deliveryPartService
                .watchDeliveryPartsByDeliveryId(widget.deliveryId!)
            : _deliveryPartService.watchAllDeliveryParts(),
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

          final deliveryParts = snapshot.data ?? [];

          if (deliveryParts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.inventory_2, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No delivery parts found',
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
                    onPressed: _createSampleDeliveryPart,
                    child: const Text('Create Sample Delivery Part'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: deliveryParts.length,
            itemBuilder: (context, index) {
              final deliveryPart = deliveryParts[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.blue,
                    child: Icon(Icons.inventory_2, color: Colors.white),
                  ),
                  title: Text(
                    'Delivery: ${deliveryPart.deliveryId.substring(0, 8)}...',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      if (deliveryPart.partId != null) ...[
                        Row(
                          children: [
                            const Icon(Icons.label,
                                size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Part ID: ${deliveryPart.partId!.substring(0, 8)}...',
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                      ],
                      Row(
                        children: [
                          const Icon(Icons.numbers,
                              size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            'Quantity: ${deliveryPart.quantity ?? 'Not set'}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.schedule,
                              size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Created: ${_formatDateTime(deliveryPart.createdAt)}',
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () => _showQuantityDialog(deliveryPart),
                        tooltip: 'Edit Quantity',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete,
                            size: 20, color: Colors.red),
                        onPressed: () => _repository
                            .deleteDeliveryPart(deliveryPart.deliveryId),
                        tooltip: 'Delete',
                      ),
                    ],
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createSampleDeliveryPart,
        tooltip: 'Create Delivery Part',
        child: const Icon(Icons.add),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _repository.dispose();
    super.dispose();
  }
}
