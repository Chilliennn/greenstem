import 'package:flutter/material.dart';
import 'package:greenstem/domain/entities/delivery.dart';
import '../../../data/datasources/delivery_datasource.dart';
import '../../../data/repositories/delivery_repository_impl.dart';
import '../../../domain/usecases/get_deliveries_usecase.dart';

class DeliveryScreen extends StatefulWidget {
  const DeliveryScreen({super.key});

  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen> {
  late final GetDeliveriesUseCase _getDeliveriesUseCase;
  List<Delivery> _deliveries = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    // Dependency injection setup
    final dataSource = SupabaseDeliveryDataSource();
    final repository = DeliveryRepositoryImpl(dataSource);
    _getDeliveriesUseCase = GetDeliveriesUseCase(repository);

    _loadDeliveries();
  }

  Future<void> _loadDeliveries() async {
    setState(() => _isLoading = true);

    try {
      final deliveries = await _getDeliveriesUseCase();
      setState(() => _deliveries = deliveries);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading deliveries: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Deliveries')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _deliveries.length,
              itemBuilder: (context, index) {
                final delivery = _deliveries[index];
                return ListTile(
                  title: Text('Delivery ${delivery.deliveryId}'),
                  subtitle: Text('Status: ${delivery.status ?? 'Unknown'}'),
                  trailing: Text(delivery.createdAt.toString()),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadDeliveries,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
