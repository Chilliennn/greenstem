import 'dart:async';
import 'package:flutter/material.dart';
import '../../../domain/entities/delivery.dart';
import '../../../domain/services/delivery_service.dart';
import '../../../data/repositories/delivery_repository_impl.dart';
import '../../../data/datasources/local/local_database_service.dart';
import '../../../data/datasources/remote/remote_delivery_datasource.dart';
import '../../../core/services/network_service.dart';
import '../profile/profile_screen.dart';

class DeliveryDetailScreen extends StatefulWidget {
  final Delivery delivery;
  final Function(Delivery) onDeliveryUpdated;

  const DeliveryDetailScreen({
    super.key,
    required this.delivery,
    required this.onDeliveryUpdated,
  });

  @override
  State<DeliveryDetailScreen> createState() => _DeliveryDetailScreenState();
}

class _DeliveryDetailScreenState extends State<DeliveryDetailScreen> {
  late final DeliveryService _deliveryService;
  late final DeliveryRepositoryImpl _repository;

  bool _isOnline = false;
  bool _isUpdating = false;
  StreamSubscription<bool>? _connectivitySubscription;
  StreamSubscription<Delivery?>? _deliverySubscription;
  Delivery? _currentDelivery;

  @override
  void initState() {
    super.initState();
    _currentDelivery = widget.delivery;
    _initializeServices();
    _checkConnectivity();
    _listenToConnectivity();
    _watchDelivery();
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

  void _watchDelivery() {
    _deliverySubscription = _deliveryService
        .watchDeliveryById(_currentDelivery!.deliveryId)
        .listen((delivery) {
      if (delivery != null && mounted) {
        setState(() {
          _currentDelivery = delivery;
        });
        widget.onDeliveryUpdated(delivery);
      }
    });
  }

  Future<void> _updateDeliveryStatus(String newStatus) async {
    if (_currentDelivery == null) return;

    setState(() => _isUpdating = true);

    try {
      DateTime? pickupTime;
      DateTime? deliveredTime;

      // Set timestamps based on status
      switch (newStatus.toLowerCase()) {
        case 'picked up':
          pickupTime = DateTime.now();
          break;
        case 'delivered':
          deliveredTime = DateTime.now();
          break;
      }

      final updatedDelivery = _currentDelivery!.copyWith(
        status: newStatus,
        pickupTime: pickupTime ?? _currentDelivery!.pickupTime,
        deliveredTime: deliveredTime ?? _currentDelivery!.deliveredTime,
        updatedAt: DateTime.now(),
      );

      await _deliveryService.updateDelivery(updatedDelivery);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to $newStatus'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.blue;
      case 'awaiting':
        return Colors.orange;
      case 'picked up':
        return Colors.blue;
      case 'en route':
        return Colors.purple;
      case 'delivered':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.inbox;
      case 'awaiting':
        return Icons.schedule;
      case 'picked up':
        return Icons.local_shipping;
      case 'en route':
        return Icons.navigation;
      case 'delivered':
        return Icons.check_circle;
      default:
        return Icons.help_outline;
    }
  }

  Widget _buildStatusActions() {
    if (_currentDelivery == null) return const SizedBox.shrink();

    final currentStatus = _currentDelivery!.status?.toLowerCase() ?? '';

    switch (currentStatus) {
      case 'pending':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed:
                  _isUpdating ? null : () => _updateDeliveryStatus('awaiting'),
              icon: const Icon(Icons.schedule),
              label: const Text('Mark as Awaiting'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );

      case 'awaiting':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed:
                  _isUpdating ? null : () => _updateDeliveryStatus('picked up'),
              icon: const Icon(Icons.local_shipping),
              label: const Text('Mark as Picked Up'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );

      case 'picked up':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed:
                  _isUpdating ? null : () => _updateDeliveryStatus('en route'),
              icon: const Icon(Icons.navigation),
              label: const Text('Mark as En Route'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );

      case 'en route':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed:
                  _isUpdating ? null : () => _updateDeliveryStatus('delivered'),
              icon: const Icon(Icons.check_circle),
              label: const Text('Mark as Delivered'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );

      case 'delivered':
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade600),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Delivery Completed',
                  style: TextStyle(
                    color: Colors.green.shade600,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentDelivery == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Delivery Details')),
        body: const Center(
          child: Text('Delivery not found'),
        ),
      );
    }

    final delivery = _currentDelivery!;
    final statusColor = _getStatusColor(delivery.status ?? '');
    final statusIcon = _getStatusIcon(delivery.status ?? '');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Details'),
        backgroundColor: Colors.green.shade50,
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
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
            tooltip: 'Profile',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: statusColor, width: 2),
                      ),
                      child: Icon(
                        statusIcon,
                        size: 40,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      delivery.status?.toUpperCase() ?? 'UNKNOWN',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Delivery Status',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Delivery Information
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delivery Information',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow('Delivery ID', delivery.deliveryId),
                    _buildDetailRow(
                        'User ID', delivery.userId ?? 'Not assigned'),
                    _buildDetailRow('Status', delivery.status ?? 'Unknown'),
                    _buildDetailRow('Pickup Location',
                        delivery.pickupLocation ?? 'Not specified'),
                    _buildDetailRow('Delivery Location',
                        delivery.deliveryLocation ?? 'Not specified'),
                    _buildDetailRow('Vehicle Number',
                        delivery.vehicleNumber ?? 'Not assigned'),
                    if (delivery.dueDatetime != null)
                      _buildDetailRow(
                          'Due Date', _formatDateTime(delivery.dueDatetime!)),
                    _buildDetailRow(
                        'Created At', _formatDateTime(delivery.createdAt)),
                    _buildDetailRow(
                        'Updated At', _formatDateTime(delivery.updatedAt)),
                    if (delivery.pickupTime != null)
                      _buildDetailRow(
                          'Pickup Time', _formatDateTime(delivery.pickupTime!)),
                    if (delivery.deliveredTime != null)
                      _buildDetailRow('Delivered Time',
                          _formatDateTime(delivery.deliveredTime!)),
                    if (delivery.proofImgPath != null)
                      _buildDetailRow('Proof Image', delivery.proofImgPath!),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Status Actions
            if (_isUpdating)
              const Center(
                child: CircularProgressIndicator(),
              )
            else
              _buildStatusActions(),

            const SizedBox(height: 24),

            // Additional Information
            if (delivery.status?.toLowerCase() == 'delivered' &&
                delivery.deliveredTime != null) ...[
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle,
                              color: Colors.green.shade600),
                          const SizedBox(width: 8),
                          Text(
                            'Delivery Completed',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Delivered on ${_formatDateTime(delivery.deliveredTime!)}',
                        style: TextStyle(color: Colors.green.shade600),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            if (delivery.status?.toLowerCase() == 'en route') ...[
              Card(
                color: Colors.purple.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.navigation, color: Colors.purple.shade600),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Delivery In Progress',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.purple.shade600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Package is on the way to destination',
                              style: TextStyle(color: Colors.purple.shade600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _deliverySubscription?.cancel();
    _repository.dispose();
    super.dispose();
  }
}
