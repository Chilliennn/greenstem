import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:greenstem/domain/entities/delivery.dart';
import '../../../presentation/widgets/home/active_tab.dart';
import '../../../presentation/widgets/home/history_tab.dart';
import '../../../presentation/widgets/home/sliding_tab_switcher.dart';
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
import '../profiles/profile_screen.dart';

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
  bool isActiveTab = true;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _checkConnectivity();
    _listenToConnectivity();
    _loadCurrentUser();

    // debug data synchronization
    _debugDataSync();
  }

  Future<void> _debugDataSync() async {
    print('DEBUG: Checking data synchronization...');

    try {
      // check local data
      final localDeliveries = await _deliveryRepository.getCachedDeliveries();
      print('Local deliveries count: ${localDeliveries.length}');

      if (await NetworkService.hasConnection()) {
        print('Network is available, checking remote data...');

        // try to fetch from remote
        final remoteDataSource = SupabaseDeliveryDataSource();
        final remoteDeliveries = await remoteDataSource.getAllDeliveries();
        print('Remote deliveries count: ${remoteDeliveries.length}');

        // force a sync
        print('Forcing sync from remote...');
        await _deliveryRepository.syncFromRemote();

        // check local again
        final localAfterSync = await _deliveryRepository.getCachedDeliveries();
        print('Local deliveries after sync: ${localAfterSync.length}');
      } else {
        print('No network connection');
      }
    } catch (e) {
      print('Debug sync error: $e');
    }
  }

  void _initializeServices() {
    // delivery services
    final localDeliveryDataSource = LocalDeliveryDatabaseService();
    final remoteDeliveryDataSource = SupabaseDeliveryDataSource();
    _deliveryRepository = DeliveryRepositoryImpl(
        localDeliveryDataSource, remoteDeliveryDataSource);
    _deliveryService = DeliveryService(_deliveryRepository);

    // user services
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

      // trigger sync when we come online
      if (isOnline) {
        _syncAllData();
      }
    }
  }

  void _listenToConnectivity() {
    _connectivitySubscription =
        NetworkService.connectionStream.listen((isConnected) {
      if (mounted) {
        setState(() => _isOnline = isConnected);

        // trigger sync when connectivity changes to online
        if (isConnected) {
          _syncAllData();
        }
      }
    });
  }

  Future<void> _syncAllData() async {
    try {
      setState(() {
        _isSyncing = true;
      });
      print('Starting data synchronization...');
      await _deliveryRepository.syncFromRemote();
      await _userRepository.syncFromRemote();
      print('Data synchronization completed');
    } catch (e) {
      print('Sync error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Home',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        backgroundColor: const Color(0xFF111111),
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
                backgroundColor: Colors.grey[300],
                child: _currentUser?.username != null
                    ? Text(
                        _currentUser!.username![0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : const Icon(Icons.person, color: Colors.black),
              ),
            ),
          ),
        ],
      ),
      backgroundColor: const Color(0xFF111111),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SlidingTabSwitcher(
              tabs: const ["Active", "History"],
              onTabSelected: (index) {
                setState(() {
                  isActiveTab = index == 0;
                });
              },
            ),
            const SizedBox(height: 24),
            Expanded(
              child: StreamBuilder<List<Delivery>>(
                stream: _deliveryService.watchAllDeliveries(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error, size: 64, color: Colors.red),
                          const SizedBox(height: 16),
                          Text(
                            'Error: ${snapshot.error}',
                            style: const TextStyle(color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              _checkConnectivity();
                              if (_isOnline) _syncAllData();
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }

                  final deliveries = snapshot.data ?? [];

                  print(
                      'StreamBuilder received ${deliveries.length} deliveries');

                  // filter deliveries based on tab
                  final filteredDeliveries = isActiveTab
                      ? deliveries
                          .where((d) =>
                              d.status?.toLowerCase() != 'delivered' &&
                              d.status?.toLowerCase() != 'cancelled')
                          .toList()
                      : deliveries
                          .where((d) =>
                              d.status?.toLowerCase() == 'delivered' ||
                              d.status?.toLowerCase() == 'cancelled')
                          .toList();

                  return isActiveTab
                      ? ActiveTab(deliveries: filteredDeliveries)
                      : HistoryTab(deliveries: filteredDeliveries);
                },
              ),
            ),
          ],
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
