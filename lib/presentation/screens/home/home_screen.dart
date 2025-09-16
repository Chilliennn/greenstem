import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:greenstem/presentation/widgets/home/active_tab.dart';
import 'package:greenstem/presentation/widgets/home/history_tab.dart';
import 'package:greenstem/presentation/widgets/home/sliding_tab_switcher.dart';
import '../../../domain/entities/delivery.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/services/delivery_service.dart';
import '../../../domain/services/user_service.dart';
import '../../../data/repositories/delivery_repository_impl.dart';
import '../../../data/repositories/user_repository_impl.dart';
import '../../../data/datasources/local/local_delivery_database_service.dart';
import '../../../data/datasources/local/local_user_database_service.dart';
import '../../../data/datasources/remote/remote_delivery_datasource.dart';
import '../../../data/datasources/remote/remote_user_datasource.dart';
import '../../../core/services/network_service.dart';
import '../delivery_detail/delivery_detail_screen.dart';
import '../profile/profile_screen.dart';
import '../auth/sign_in_screen.dart';
import '../../providers/auth_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final DeliveryService _deliveryService;
  late final UserService _userService;
  late final DeliveryRepositoryImpl _deliveryRepository;
  late final UserRepositoryImpl _userRepository;

  bool _isOnline = false;
  User? _currentUser;
  StreamSubscription<bool>? _connectivitySubscription;
  StreamSubscription<User?>? _userSubscription;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _checkConnectivity();
    _listenToConnectivity();
    _loadCurrentUser();
  }

  void _initializeServices() {
    // Delivery services
    final localDeliveryDataSource = LocalDeliveryDatabaseService();
    final remoteDeliveryDataSource = SupabaseDeliveryDataSource();
    _deliveryRepository = DeliveryRepositoryImpl(
        localDeliveryDataSource, remoteDeliveryDataSource);
    _deliveryService = DeliveryService(_deliveryRepository);

    // User services
    final localUserDataSource = LocalUserDatabaseService();
    final remoteUserDataSource = SupabaseUserDataSource();
    _userRepository =
        UserRepositoryImpl(localUserDataSource, remoteUserDataSource);
    _userService = UserService(_userRepository);
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

  void _loadCurrentUser() {
    _userSubscription = _userService.watchCurrentUser().listen((user) {
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
      }
    });
  }

  Future<void> _acceptDelivery(Delivery delivery) async {
    try {
      final updatedDelivery = delivery.copyWith(
        status: 'awaiting',
        updatedAt: DateTime.now(),
      );

      await _deliveryService.updateDelivery(updatedDelivery);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isOnline
                ? 'Delivery accepted'
                : 'Delivery accepted (will sync when online)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accepting delivery: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool isActiveTab = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            title: const Text(
              'Home',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            backgroundColor: Color(0xFF111111),
            actions: [
              Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const ProfileScreen()),
                      );
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: CircleAvatar(
                      radius: 20,
                      // TODO: fetch pfp from db
                      // backgroundImage:
                      //     const AssetImage('assets/profile_image.jpg'),
                      backgroundColor: Colors.grey[300],
                    ),
                  )),
            ]),
        backgroundColor: Color(0xFF111111),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              SlidingTabSwitcher(
                tabs: ["Active", "History"],
                onTabSelected: (index) {
                  setState(() {
                    isActiveTab = index == 0;
                  });
                },
              ),
              const SizedBox(
                height: 16,
              ),
              isActiveTab ? ActiveTab() : HistoryTab(),
            ],
          ),
        ));
  }

  Widget _buildAcceptedDeliveryCard(Delivery delivery) {
    Color statusColor;
    IconData statusIcon;

    switch (delivery.status?.toLowerCase()) {
      case 'awaiting':
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
        break;
      case 'picked up':
        statusColor = Colors.blue;
        statusIcon = Icons.local_shipping;
        break;
      case 'en route':
        statusColor = Colors.purple;
        statusIcon = Icons.navigation;
        break;
      case 'delivered':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 3,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DeliveryDetailScreen(
                delivery: delivery,
                onDeliveryUpdated: (updatedDelivery) {
                  // Delivery will be updated through the stream
                },
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(statusIcon, color: statusColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delivery ${delivery.deliveryId.substring(0, 8)}...',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            delivery.status?.toUpperCase() ?? 'UNKNOWN',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16),
                ],
              ),
              if (delivery.pickupLocation != null ||
                  delivery.deliveryLocation != null) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                if (delivery.pickupLocation != null) ...[
                  Row(
                    children: [
                      Icon(Icons.location_on,
                          size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Text(
                        'From: ${delivery.pickupLocation}',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
                if (delivery.deliveryLocation != null) ...[
                  Row(
                    children: [
                      Icon(Icons.flag, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Text(
                        'To: ${delivery.deliveryLocation}',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _userSubscription?.cancel();
    _deliveryRepository.dispose();
    _userRepository.dispose();
    super.dispose();
  }
}
