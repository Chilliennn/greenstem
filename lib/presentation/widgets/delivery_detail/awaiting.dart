import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/delivery.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/entities/delivery_part.dart';
import '../../../domain/entities/part.dart';
import '../../../domain/services/delivery_service.dart';
import '../../../domain/services/user_service.dart';
import '../../../domain/services/delivery_part_service.dart';
import '../../../domain/services/part_service.dart';
import '../../../domain/services/location_service.dart';
import '../../../data/repositories/delivery_repository_impl.dart';
import '../../../data/repositories/user_repository_impl.dart';
import '../../../data/repositories/delivery_part_repository_impl.dart';
import '../../../data/repositories/part_repository_impl.dart';
import '../../../data/repositories/location_repository_impl.dart';
import '../../../data/datasources/local/local_delivery_database_service.dart';
import '../../../data/datasources/local/local_user_database_service.dart';
import '../../../data/datasources/local/local_delivery_part_database_service.dart';
import '../../../data/datasources/local/local_part_database_service.dart';
import '../../../data/datasources/local/local_location_database_service.dart';
import '../../../data/datasources/remote/remote_delivery_datasource.dart';
import '../../../data/datasources/remote/remote_user_datasource.dart';
import '../../../data/datasources/remote/remote_delivery_part_datasource.dart';
import '../../../data/datasources/remote/remote_part_datasource.dart';
import '../../../data/datasources/remote/remote_location_datasource.dart';
import '../../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';

class AwaitingPage extends ConsumerStatefulWidget {
  final Delivery delivery;

  const AwaitingPage({super.key, required this.delivery});

  @override
  ConsumerState<AwaitingPage> createState() => _AwaitingPageState();
}

class _AwaitingPageState extends ConsumerState<AwaitingPage> {
  late final DeliveryService _deliveryService;
  late final UserService _userService;
  late final DeliveryPartService _deliveryPartService;
  late final PartService _partService;
  late final LocationService _locationService;

  bool _isUpdating = false;
  bool _isLoadingParts = true;
  Delivery? _currentDelivery;
  User? _currentUser;
  List<DeliveryPart> _deliveryParts = [];
  Map<String, Part?> _partsMap = {};
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _currentDelivery = widget.delivery;
    _initializeServices();
    _loadCurrentUser();
    _loadDeliveryParts();
  }

  void _initializeServices() {
    // Initialize delivery services
    final localDeliveryDataSource = LocalDeliveryDatabaseService();
    final remoteDeliveryDataSource = SupabaseDeliveryDataSource();
    final deliveryRepository = DeliveryRepositoryImpl(localDeliveryDataSource, remoteDeliveryDataSource);
    _deliveryService = DeliveryService(deliveryRepository);

    // Initialize user services
    final localUserDataSource = LocalUserDatabaseService();
    final remoteUserDataSource = SupabaseUserDataSource();
    final userRepository = UserRepositoryImpl(localUserDataSource, remoteUserDataSource);
    _userService = UserService(userRepository);

    // Initialize delivery part services
    final localDeliveryPartDataSource = LocalDeliveryPartDatabaseService();
    final remoteDeliveryPartDataSource = SupabaseDeliveryPartDataSource();
    final deliveryPartRepository = DeliveryPartRepositoryImpl(localDeliveryPartDataSource, remoteDeliveryPartDataSource);
    _deliveryPartService = DeliveryPartService(deliveryPartRepository);

    // Initialize part services
    final localPartDataSource = LocalPartDatabaseService();
    final remotePartDataSource = SupabasePartDataSource();
    final partRepository = PartRepositoryImpl(localPartDataSource, remotePartDataSource);
    _partService = PartService(partRepository);

    // Initialize location services
    final localLocationDataSource = LocalLocationDatabaseService();
    final remoteLocationDataSource = SupabaseLocationDataSource();
    final locationRepository = LocationRepositoryImpl(localLocationDataSource, remoteLocationDataSource);
    _locationService = LocationService(locationRepository);
  }

  Future<void> _loadCurrentUser() async {
    try {
      final authState = ref.read(authProvider);
      if (authState.user != null) {
        final user = await _userService.watchUserById(authState.user!.userId).first;
        if (mounted) {
          setState(() {
            _currentUser = user;
          });
        }
      }
    } catch (e) {
      print('Error loading current user: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load user data';
        });
      }
    }
  }

  Future<void> _loadDeliveryParts() async {
    if (mounted) {
      setState(() {
        _isLoadingParts = true;
        _errorMessage = null;
      });
    }

    try {
      final allParts = await _deliveryPartService.watchAllDeliveryParts().first;
      final deliveryParts = allParts.where((part) => part.deliveryId == widget.delivery.deliveryId).toList();

      final partsMap = <String, Part?>{};
      for (final deliveryPart in deliveryParts) {
        if (deliveryPart.partId != null) {
          final part = await _partService.watchPartById(deliveryPart.partId!).first;
          partsMap[deliveryPart.partId!] = part;
        }
      }

      if (mounted) {
        setState(() {
          _deliveryParts = deliveryParts;
          _partsMap = partsMap;
          _isLoadingParts = false;
        });
      }
    } catch (e) {
      print('Error loading delivery parts: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load parts data';
          _isLoadingParts = false;
        });
      }
    }
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '-';
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '-';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _acceptDelivery() async {
    if (_currentDelivery == null) return;

    setState(() => _isUpdating = true);

    try {
      final updatedDelivery = _currentDelivery!.copyWith(
        status: 'picked up',
        updatedAt: DateTime.now(),
        pickupTime: DateTime.now(),
      );
      final result = await _deliveryService.updateDelivery(updatedDelivery);

      if (result != null && mounted) {
        setState(() {
          _currentDelivery = result;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Delivery accepted! You can now pick up the items.'),
            backgroundColor: AppColors.cyellow,
          ),
        );

        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept delivery: $e'),
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

  Future<String> _calculateDistanceAndTime() async {
    return await _locationService.calculateDistanceAndTime(
      _currentDelivery?.pickupLocation,
      _currentDelivery?.deliveryLocation,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentDelivery == null) {
      return Scaffold(
        backgroundColor: AppColors.cblack,
        appBar: AppBar(
          title: const Text('Awaiting'),
          backgroundColor: AppColors.cblack,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('Delivery not found', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final delivery = _currentDelivery!;

    return Scaffold(
      backgroundColor: AppColors.cblack,
      appBar: AppBar(
        backgroundColor: AppColors.cblack,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const Text(
              'Awaiting',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Text(
              delivery.deliveryId.length > 8
                  ? delivery.deliveryId.substring(0, 8).toUpperCase()
                  : delivery.deliveryId.toUpperCase(),
              style: const TextStyle(color: AppColors.cyellow, fontSize: 16),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Pickup and Delivery Location Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1D1D1D),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pick up from',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade400,
                              ),
                            ),
                            const SizedBox(height: 6),
                            FutureBuilder<String>(
                              future: _locationService
                                  .getLocationName(delivery.pickupLocation),
                              builder: (context, snapshot) {
                                return Text(
                                  snapshot.data ?? 'Unknown',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 4),
                            FutureBuilder<String>(
                              future: _locationService
                                  .getLocationAddress(delivery.pickupLocation),
                              builder: (context, snapshot) {
                                return Text(
                                  snapshot.data ?? 'No address available',
                                  style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 14,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Deliver to',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade400,
                              ),
                            ),
                            const SizedBox(height: 6),
                            FutureBuilder<String>(
                              future: _locationService
                                  .getLocationName(delivery.deliveryLocation),
                              builder: (context, snapshot) {
                                return Text(
                                  snapshot.data ?? 'Unknown',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 4),
                            FutureBuilder<String>(
                              future: _locationService.getLocationAddress(
                                  delivery.deliveryLocation),
                              builder: (context, snapshot) {
                                return Text(
                                  snapshot.data ?? 'No address available',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 14,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey.shade600)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.cyellow,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.local_shipping,
                            color: Colors.black,
                            size: 20,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.grey.shade600)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      FutureBuilder<String>(
                        future: _calculateDistanceAndTime(),
                        builder: (context, snapshot) {
                          return Text(
                            snapshot.data ?? '0.1 km • 5 min',
                            style: TextStyle(
                                color: Colors.grey.shade400, fontSize: 14),
                          );
                        },
                      ),
                      Text(
                        'Due: ${_formatDateTime(delivery.dueDatetime)}',
                        style: TextStyle(
                            color: Colors.grey.shade400, fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Expected Pickup Time Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1D1D1D),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    'Expected pickup time',
                    style: TextStyle(
                        color: Colors.grey.shade400, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatTime(delivery.dueDatetime),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Scheduled',
                    style: TextStyle(
                        color: Colors.grey.shade400, fontSize: 12),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Parts Information Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1D1D1D),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Parts Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_isLoadingParts)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(
                          valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.cyellow),
                        ),
                      ),
                    )
                  else if (_errorMessage != null)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          _errorMessage!,
                          style:
                          const TextStyle(color: Colors.red, fontSize: 16),
                        ),
                      ),
                    )
                  else if (_deliveryParts.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text(
                            'No parts found for this delivery',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        ),
                      )
                    else ...[
                        // Header row
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                'Name',
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Code',
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Unit',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Parts rows from database
                        ..._deliveryParts.map((part) => _buildPartRow(part)),
                        const SizedBox(height: 16),
                        Divider(color: Colors.grey.shade600),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Vehicle',
                              style: TextStyle(color: Colors.white, fontSize: 16),
                            ),
                            Text(
                              delivery.vehicleNumber ?? 'N/A',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Items',
                              style: TextStyle(color: Colors.white, fontSize: 16),
                            ),
                            Text(
                              '${_deliveryParts.fold<int>(0, (sum, part) => sum + (part.quantity ?? 0))}',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 16),
                            ),
                          ],
                        ),
                      ],
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Pick Up Button
            if (_isUpdating)
              const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.cyellow),
                ),
              )
            else
              ElevatedButton(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Confirm Pick Up'),
                      content: const Text(
                          'Are you sure you want to accept this delivery?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Confirm'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await _acceptDelivery();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.cyellow,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Pick Up',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Contact Button
            OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Contact feature coming soon'),
                    backgroundColor: AppColors.cyellow,
                  ),
                );
              },
              icon: const Icon(Icons.call, color: Colors.white),
              label: const Text(
                'Contact',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Colors.white),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildPartRow(DeliveryPart part) {
    final partDetails = _partsMap[part.partId];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              partDetails?.name ?? 'Unknown Part',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              (partDetails?.partId.length ?? 0) > 6
                  ? partDetails!.partId.substring(0, 6).toUpperCase()
                  : (partDetails?.partId ?? 'N/A').toUpperCase(),
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              '${part.quantity ?? 0}',
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}