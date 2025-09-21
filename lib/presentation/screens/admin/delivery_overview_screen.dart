import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/delivery.dart';
import '../../../domain/services/delivery_service.dart';
import '../../../data/repositories/delivery_repository_impl.dart';
import '../../../data/datasources/local/local_delivery_database_service.dart';
import '../../../data/datasources/remote/remote_delivery_datasource.dart';
import '../../../core/utils/distance_calculator.dart';
import '../../providers/auth_provider.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/services/user_service.dart';
import '../../../data/repositories/user_repository_impl.dart';
import '../../../data/datasources/local/local_user_database_service.dart';
import '../../../data/datasources/remote/remote_user_datasource.dart';
import '../delivery_detail/delivery_detail_screen.dart';


class DeliveryOverviewScreen extends ConsumerStatefulWidget {
  const DeliveryOverviewScreen({super.key});

  @override
  ConsumerState<DeliveryOverviewScreen> createState() =>
      _DeliveryOverviewScreenState();
}

class _DeliveryOverviewScreenState extends ConsumerState<DeliveryOverviewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late DeliveryService _deliveryService;
  late UserService _userService;

  List<Delivery> _assignedDeliveries = [];
  List<Delivery> _completedDeliveries = [];
  List<Delivery> _filteredAssignedDeliveries = [];
  List<Delivery> _filteredCompletedDeliveries = [];

  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeServices();
    _loadCurrentUser();
    _loadDeliveries();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _initializeServices() {
    // Initialize delivery services
    final localDeliveryDataSource = LocalDeliveryDatabaseService();
    final remoteDeliveryDataSource = SupabaseDeliveryDataSource();
    final deliveryRepository = DeliveryRepositoryImpl(
        localDeliveryDataSource, remoteDeliveryDataSource);
    _deliveryService = DeliveryService(deliveryRepository);

    // Initialize user services
    final localUserDataSource = LocalUserDatabaseService();
    final remoteUserDataSource = SupabaseUserDataSource();
    final userRepository =
        UserRepositoryImpl(localUserDataSource, remoteUserDataSource);
    _userService = UserService(userRepository);
  }

  Future<void> _loadCurrentUser() async {
    try {
      final authState = ref.read(authProvider);
      if (authState.user != null) {
        final user =
            await _userService.watchUserById(authState.user!.userId).first;
        if (mounted) {
          setState(() {
            _currentUser = user;
          });
        }
      }
    } catch (e) {
      print('Error loading current user: $e');
    }
  }

  Future<void> _loadDeliveries() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final allDeliveries = await _deliveryService.watchAllDeliveries().first;

      setState(() {
        _assignedDeliveries = allDeliveries
            .where((delivery) => delivery.status != 'delivered')
            .toList();
        _completedDeliveries = allDeliveries
            .where((delivery) => delivery.status == 'delivered')
            .toList();

        _filteredAssignedDeliveries = _assignedDeliveries;
        _filteredCompletedDeliveries = _completedDeliveries;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load deliveries: $e';
        _isLoading = false;
      });
    }
  }

ImageProvider? _getProfileImage(User user) {
    if (user.profilePath == null || user.profilePath!.isEmpty) {
      return null;
    }

    if (user.profilePath!.startsWith('/')) {
      return FileImage(File(user.profilePath!));
    }

    if (user.profilePath!.startsWith('http')) {
      return NetworkImage(user.profilePath!);
    }

    return null;
  }

  void _filterDeliveries(String query) {
    setState(() {
      _searchQuery = query;

      if (query.isEmpty) {
        _filteredAssignedDeliveries = _assignedDeliveries;
        _filteredCompletedDeliveries = _completedDeliveries;
      } else {
        _filteredAssignedDeliveries = _assignedDeliveries
            .where((delivery) =>
                delivery.deliveryId
                    .toLowerCase()
                    .contains(query.toLowerCase()) ||
                delivery.pickupLocation
                        ?.toLowerCase()
                        .contains(query.toLowerCase()) ==
                    true ||
                delivery.deliveryLocation
                        ?.toLowerCase()
                        .contains(query.toLowerCase()) ==
                    true ||
                delivery.status?.toLowerCase().contains(query.toLowerCase()) ==
                    true)
            .toList();

        _filteredCompletedDeliveries = _completedDeliveries
            .where((delivery) =>
                delivery.deliveryId
                    .toLowerCase()
                    .contains(query.toLowerCase()) ||
                delivery.pickupLocation
                        ?.toLowerCase()
                        .contains(query.toLowerCase()) ==
                    true ||
                delivery.deliveryLocation
                        ?.toLowerCase()
                        .contains(query.toLowerCase()) ==
                    true)
            .toList();
      }
      
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Delivery Overview',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (_currentUser != null)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey.shade300,
                backgroundImage:
                _currentUser != null ? _getProfileImage(_currentUser!) : null,
                child: _currentUser != null &&
                    _getProfileImage(_currentUser!) == null
                    ? (_currentUser!.username?.isNotEmpty == true
                    ? Text(
                  _currentUser!.username![0].toUpperCase(),
                  style: const TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold),
                )
                    : const Icon(Icons.person, color: Colors.black, size: 20))
                    : null,
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar and Filter
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: Colors.white70),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Search deliveries...',
                      hintStyle: TextStyle(color: Colors.white54),
                      border: InputBorder.none,
                    ),
                    onChanged: _filterDeliveries,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.tune, color: Colors.white70),
                  onPressed: () {
                    // TODO: Implement filter options
                  },
                ),
              ],
            ),
          ),

          // Tab Bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: const Color(0xFFFEA41D),
                borderRadius: BorderRadius.circular(12),
              ),
              labelColor: Colors.black,
              unselectedLabelColor: Colors.white,
              labelStyle: const TextStyle(fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'Assigned'),
                Tab(text: 'Completed'),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Tab Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildDeliveryList(_filteredAssignedDeliveries),
                          _buildDeliveryList(_filteredCompletedDeliveries),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryList(List<Delivery> deliveries) {
    if (deliveries.isEmpty) {
      return const Center(
        child: Text(
          'No deliveries found',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: deliveries.length,
      itemBuilder: (context, index) {
        final delivery = deliveries[index];
        return _DeliveryCard(
          delivery: delivery,
          deliveryService: _deliveryService,
          onTap: () => _navigateToDeliveryDetail(delivery),
        );
      },
    );
  }

  void _navigateToDeliveryDetail(Delivery delivery) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DeliveryDetailScreen(
          delivery: delivery,
          onDeliveryUpdated: (updatedDelivery) {
            _loadDeliveries(); // Refresh the list
          },
        ),
      ),
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  final Delivery delivery;
  final DeliveryService deliveryService;
  final VoidCallback onTap;

  const _DeliveryCard({
    required this.delivery,
    required this.deliveryService,
    required this.onTap,
  });

  Future<String> _calculateDistance() async {
    if (delivery.pickupLocation == null || delivery.deliveryLocation == null) {
      return 'n/a';
    }

    try {
      final coordinates = await deliveryService.getDeliveryCoordinates(
        delivery.pickupLocation!,
        delivery.deliveryLocation!,
      );

      final distance = await DistanceCalculator.calculateDistance(
        coordinates['pickupLat'],
        coordinates['pickupLon'],
        coordinates['deliveryLat'],
        coordinates['deliveryLon'],
        useApi: false,
      );

      return DistanceCalculator.formatDistance(distance);
    } catch (e) {
      return 'n/a';
    }
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Color _getStatusColor() {
    switch (delivery.status?.toLowerCase()) {
      case 'awaiting':
        return const Color(0xFFFEA41D);
      case 'picked up':
        return const Color(0xFF4B97FA);
      case 'en route':
        return const Color(0xFFC084FC);
      case 'delivered':
        return const Color(0xFF10B981);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3A3A3A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.local_shipping_outlined,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'From',
                            style:
                                TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                          const Text(
                            'To',
                            style:
                                TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              delivery.pickupLocation ?? 'Location Name',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              delivery.deliveryLocation ?? 'Location Name',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.right,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Delivery Status: ',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getStatusColor().withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: _getStatusColor(), width: 1),
                  ),
                  child: Text(
                    delivery.status ?? 'Unknown',
                    style: TextStyle(
                      color: _getStatusColor(),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'Due ${_formatTime(delivery.dueDatetime)}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.inventory_2_outlined,
                    color: Colors.white54, size: 16),
                const SizedBox(width: 4),
                const Text(
                  '2 items', // This should be calculated from delivery parts
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.location_on_outlined,
                    color: Colors.white54, size: 16),
                const SizedBox(width: 4),
                FutureBuilder<String>(
                  future: _calculateDistance(),
                  builder: (context, snapshot) {
                    return Text(
                      snapshot.data ?? 'calculating...',
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
