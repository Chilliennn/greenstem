import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:greenstem/data/datasources/local/local_delivery_part_database_service.dart';
import 'package:greenstem/data/datasources/local/local_location_database_service.dart';
import 'package:greenstem/data/datasources/remote/remote_delivery_part_datasource.dart';
import 'package:greenstem/data/datasources/remote/remote_location_datasource.dart';
import 'package:greenstem/data/repositories/location_repository_impl.dart';
import '../../../data/repositories/delivery_part_repository_impl.dart';
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
import '../../providers/auth_provider.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  late final DeliveryService _deliveryService;
  late final UserService _userService;
  late final DeliveryRepositoryImpl _deliveryRepository;
  late final DeliveryPartRepositoryImpl _deliveryPartRepository;
  late final UserRepositoryImpl _userRepository;
  late final LocationRepositoryImpl _locationRepository;

  bool _isOnline = false;
  StreamSubscription<bool>? _connectivitySubscription;
  bool isActiveTab = true;
  bool _isSyncing = false;
  bool _servicesInitialized = false;
  User? _currentUser; // cache the user here

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _checkConnectivity();
    _listenToConnectivity();
    _debugDataSync();
  }

  Future<void> _debugDataSync() async {
    print('debug: checking data synchronization...');

    try {
      final localDeliveries = await _deliveryRepository.getCachedDeliveries();
      print('local deliveries count: ${localDeliveries.length}');

      if (await NetworkService.hasConnection()) {
        print('network is available, checking remote data...');

        final remoteDataSource = SupabaseDeliveryDataSource();
        final remoteDeliveries = await remoteDataSource.getAllDeliveries();
        print('remote deliveries count: ${remoteDeliveries.length}');

        print('forcing sync from remote...');
        await _deliveryRepository.syncFromRemote();

        final localAfterSync = await _deliveryRepository.getCachedDeliveries();
        print('local deliveries after sync: ${localAfterSync.length}');
      } else {
        print('no network connection');
      }
    } catch (e) {
      print('debug sync error: $e');
    }
  }

  void _initializeServices() {
    try {
      final localLocationDataSource = LocalLocationDatabaseService();
      final remoteLocationDataSource = SupabaseLocationDataSource();
      _locationRepository = LocationRepositoryImpl(
          localLocationDataSource, remoteLocationDataSource);

      final localDeliveryPartDataSource = LocalDeliveryPartDatabaseService();
      final remoteDeliveryPartDataSource = SupabaseDeliveryPartDataSource();
      _deliveryPartRepository = DeliveryPartRepositoryImpl(
          localDeliveryPartDataSource, remoteDeliveryPartDataSource);

      final localDeliveryDataSource = LocalDeliveryDatabaseService();
      final remoteDeliveryDataSource = SupabaseDeliveryDataSource();
      _deliveryRepository = DeliveryRepositoryImpl(
          localDeliveryDataSource, remoteDeliveryDataSource);

      _deliveryService = DeliveryService(
          _deliveryRepository, _deliveryPartRepository, _locationRepository);

      final localUserDataSource = LocalUserDatabaseService();
      final remoteUserDataSource = SupabaseUserDataSource();
      _userRepository =
          UserRepositoryImpl(localUserDataSource, remoteUserDataSource);
      _userService = UserService(_userRepository);

      setState(() {
        _servicesInitialized = true;
      });

      print('all services initialized successfully');
    } catch (e) {
      print('error initializing services: $e');
    }
  }

  Future<void> _checkConnectivity() async {
    final isOnline = await NetworkService.hasConnection();
    if (mounted) {
      setState(() => _isOnline = isOnline);

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
      print('starting data synchronization...');
      await _deliveryRepository.syncFromRemote();
      await _userRepository.syncFromRemote();
      print('data synchronization completed');
    } catch (e) {
      print('sync error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  Future<User?> _getCurrentUser() async {
    if (_currentUser != null) {
      return _currentUser; // return cached user
    }

    try {
      final userService = ref.read(userServiceProvider);
      final user = await userService.watchCurrentUser().first;
      _currentUser = user; // cache the user
      return user;
    } catch (e) {
      print('error getting current user: $e');
      return null;
    }
  }

  // Add this method to get profile image - same logic as profile_screen.dart
  ImageProvider? _getProfileImage(User user) {
    if (user.profilePath == null || user.profilePath!.isEmpty) {
      return null;
    }

    if (user.profilePath!.startsWith('/')) {
      final File imageFile = File(user.profilePath!);
      if (imageFile.existsSync()) {
        return FileImage(imageFile);
      }
    }

    if (user.profilePath!.startsWith('http')) {
      return NetworkImage(user.profilePath!);
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (!_servicesInitialized) {
      return const Scaffold(
        backgroundColor: Color(0xFF111111),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Initializing services...',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }
    final userStream = ref.watch(userServiceProvider).watchCurrentUser();
    return StreamBuilder<User?>(
      stream: userStream,
      builder: (context, userSnapshot) {
        print(
            'dashboard screen: connectionstate=${userSnapshot.connectionState}, hasdata=${userSnapshot.hasData}, haserror=${userSnapshot.hasError}');

        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF111111),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Loading user data...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          );
        }
        if (userSnapshot.hasError) {
          print('dashboard screen user error: ${userSnapshot.error}');
          return Scaffold(
            backgroundColor: const Color(0xFF111111),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading user: ${userSnapshot.error}',
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
            ),
          );
        }
        final currentUser = userSnapshot.data;
        if (currentUser == null) {
          return const Scaffold(
            backgroundColor: Color(0xFF111111),
            body: Center(
              child: Text(
                'No user logged in',
                style: TextStyle(color: Colors.white),
              ),
            ),
          );
        }
        print('dashboard screen: current user loaded: ${currentUser.userId}');

        return _DashboardContent(
          currentUser: currentUser,
          deliveryService: _deliveryService,
          isOnline: _isOnline,
          onSyncData: _syncAllData,
          onCheckConnectivity: _checkConnectivity,
          getProfileImage: _getProfileImage, // Pass the method
        );
      },
    );
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _deliveryRepository.dispose();
    _userRepository.dispose();
    super.dispose();
  }
}

// separate widget for main content to prevent rebuilds
class _DashboardContent extends StatefulWidget {
  final User currentUser;
  final DeliveryService deliveryService;
  final bool isOnline;
  final VoidCallback onSyncData;
  final VoidCallback onCheckConnectivity;
  final ImageProvider? Function(User) getProfileImage; // Add this parameter

  const _DashboardContent({
    required this.currentUser,
    required this.deliveryService,
    required this.isOnline,
    required this.onSyncData,
    required this.onCheckConnectivity,
    required this.getProfileImage, // Add this parameter
  });

  @override
  State<_DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<_DashboardContent> {
  bool isActiveTab = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Dashboard',
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
                backgroundImage: widget.getProfileImage(
                    widget.currentUser), // Use the profile image
                child: widget.getProfileImage(widget.currentUser) == null
                    ? (widget.currentUser.username?.isNotEmpty == true
                        ? Text(
                            widget.currentUser.username![0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : const Icon(Icons.person, color: Colors.black))
                    : null, // Don't show child if we have an image
              ),
            ),
          ),
        ],
      ),
      backgroundColor: const Color(0xFF111111),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [],
        ),
      ),
    );
  }
}
