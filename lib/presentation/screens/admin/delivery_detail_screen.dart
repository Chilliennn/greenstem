import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/delivery.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/entities/location.dart';
import '../../../domain/entities/delivery_part.dart';
import '../../../domain/entities/part.dart';
import '../../../domain/services/delivery_service.dart';
import '../../../domain/services/user_service.dart';
import '../../../domain/services/location_service.dart';
import '../../../domain/services/delivery_part_service.dart';
import '../../../domain/services/part_service.dart';
import '../../../data/repositories/delivery_repository_impl.dart';
import '../../../data/repositories/user_repository_impl.dart';
import '../../../data/repositories/location_repository_impl.dart';
import '../../../data/repositories/delivery_part_repository_impl.dart';
import '../../../data/repositories/part_repository_impl.dart';
import '../../../data/datasources/local/local_delivery_database_service.dart';
import '../../../data/datasources/local/local_user_database_service.dart';
import '../../../data/datasources/local/local_location_database_service.dart';
import '../../../data/datasources/local/local_delivery_part_database_service.dart';
import '../../../data/datasources/local/local_part_database_service.dart';
import '../../../data/datasources/remote/remote_delivery_datasource.dart';
import '../../../data/datasources/remote/remote_user_datasource.dart';
import '../../../data/datasources/remote/remote_location_datasource.dart';
import '../../../data/datasources/remote/remote_delivery_part_datasource.dart';
import '../../../data/datasources/remote/remote_part_datasource.dart';
import '../../../core/utils/distance_calculator.dart';
import 'dart:io';
import '../profiles/profile_screen.dart';

class DeliveryOverviewDetailScreen extends ConsumerStatefulWidget {
  final Delivery delivery;

  const DeliveryOverviewDetailScreen({
    super.key,
    required this.delivery,
  });

  @override
  ConsumerState<DeliveryOverviewDetailScreen> createState() =>
      _DeliveryOverviewDetailScreenState();
}

class _DeliveryOverviewDetailScreenState
    extends ConsumerState<DeliveryOverviewDetailScreen> {
  late DeliveryService _deliveryService;
  late UserService _userService;
  late LocationService _locationService;
  late DeliveryPartService _deliveryPartService;
  late PartService _partService;

  bool _isLoadingParts = true;
  bool _isLoadingLocations = true;
  Delivery? _currentDelivery;
  User? _currentUser;
  List<DeliveryPart> _deliveryParts = [];
  Map<String, Part?> _partsMap = {};
  String? _errorMessage;

  Location? _pickupLocation;
  Location? _deliveryLocation;
  String _distanceText = 'Calculating...';
  String _durationText = '';

  @override
  void initState() {
    super.initState();
    _currentDelivery = widget.delivery;
    _initializeServices();
    _loadCurrentUser();
    _loadDeliveryParts();
    _loadLocations();
    _calculateDistance();
  }

  void _initializeServices() {
    // Initialize delivery services
    final localDeliveryDataSource = LocalDeliveryDatabaseService();
    final remoteDeliveryDataSource = SupabaseDeliveryDataSource();
    final deliveryRepository = DeliveryRepositoryImpl(
        localDeliveryDataSource, remoteDeliveryDataSource);

    // Initialize user services
    final localUserDataSource = LocalUserDatabaseService();
    final remoteUserDataSource = SupabaseUserDataSource();
    final userRepository =
        UserRepositoryImpl(localUserDataSource, remoteUserDataSource);
    _userService = UserService(userRepository);

    // Initialize delivery part services
    final localDeliveryPartDataSource = LocalDeliveryPartDatabaseService();
    final remoteDeliveryPartDataSource = SupabaseDeliveryPartDataSource();
    final deliveryPartRepository = DeliveryPartRepositoryImpl(
        localDeliveryPartDataSource, remoteDeliveryPartDataSource);
    _deliveryPartService = DeliveryPartService(deliveryPartRepository);

    // Initialize part services
    final localPartDataSource = LocalPartDatabaseService();
    final remotePartDataSource = SupabasePartDataSource();
    final partRepository =
        PartRepositoryImpl(localPartDataSource, remotePartDataSource);
    _partService = PartService(partRepository);

    // Initialize location services
    final localLocationDataSource = LocalLocationDatabaseService();
    final remoteLocationDataSource = SupabaseLocationDataSource();
    final locationRepository = LocationRepositoryImpl(
        localLocationDataSource, remoteLocationDataSource);
    _locationService = LocationService(locationRepository);

    _deliveryService = DeliveryService(
        deliveryRepository, deliveryPartRepository, locationRepository);
  }

  Future<void> _loadCurrentUser() async {
    if (_currentDelivery?.userId == null) return;

    try {
      final user =
          await _userService.watchUserById(_currentDelivery!.userId!).first;
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
      }
    } catch (e) {
      print('Error loading current user: $e');
    }
  }

  Future<void> _loadDeliveryParts() async {
    if (_currentDelivery == null) return;

    setState(() => _isLoadingParts = true);

    try {
      final allParts = await _deliveryPartService.watchAllDeliveryParts().first;
      final deliveryParts = allParts
          .where((part) => part.deliveryId == _currentDelivery!.deliveryId)
          .toList();

      final Map<String, Part?> partsMap = {};
      for (final deliveryPart in deliveryParts) {
        if (deliveryPart.partId != null) {
          try {
            final part =
                await _partService.watchPartById(deliveryPart.partId!).first;
            partsMap[deliveryPart.partId!] = part;
          } catch (e) {
            print('Error loading part ${deliveryPart.partId}: $e');
            partsMap[deliveryPart.partId!] = null;
          }
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
          _isLoadingParts = false;
          _errorMessage = 'Failed to load delivery parts';
        });
      }
    }
  }

  Future<void> _loadLocations() async {
    if (_currentDelivery == null) return;

    setState(() => _isLoadingLocations = true);

    try {
      if (_currentDelivery!.pickupLocation != null) {
        _pickupLocation = await _locationService
            .watchLocationById(_currentDelivery!.pickupLocation!)
            .first;
      }

      if (_currentDelivery!.deliveryLocation != null) {
        _deliveryLocation = await _locationService
            .watchLocationById(_currentDelivery!.deliveryLocation!)
            .first;
      }

      if (mounted) {
        setState(() => _isLoadingLocations = false);
      }
    } catch (e) {
      print('Error loading locations: $e');
      if (mounted) {
        setState(() {
          _isLoadingLocations = false;
          _errorMessage = 'Failed to load location data';
        });
      }
    }
  }

  Future<void> _calculateDistance() async {
    if (_pickupLocation?.latitude == null ||
        _pickupLocation?.longitude == null ||
        _deliveryLocation?.latitude == null ||
        _deliveryLocation?.longitude == null) {
      setState(() {
        _distanceText = 'n/a';
        _durationText = 'n/a';
      });
      return;
    }

    try {
      final coordinates = {
        'pickupLat': _pickupLocation!.latitude,
        'pickupLon': _pickupLocation!.longitude,
        'deliveryLat': _deliveryLocation!.latitude,
        'deliveryLon': _deliveryLocation!.longitude,
      };

      final distance = await DistanceCalculator.calculateDistance(
        coordinates['pickupLat']!,
        coordinates['pickupLon']!,
        coordinates['deliveryLat']!,
        coordinates['deliveryLon']!,
        useApi: false,
      );

      if (distance != null && mounted) {
        final durationHours = distance / 50.0;
        final hours = durationHours.floor();
        final minutes = ((durationHours - hours) * 60).round();

        String durationStr = '';
        if (hours > 0) {
          durationStr = '${hours}hr ';
        }
        durationStr += '${minutes} min';

        setState(() {
          _distanceText = DistanceCalculator.formatDistance(distance);
          _durationText = durationStr;
        });
      }
    } catch (e) {
      print('Error calculating distance: $e');
      setState(() {
        _distanceText = 'n/a';
        _durationText = 'n/a';
      });
    }
  }

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

  Future<int> _getTotalItemCount() async {
    try {
      return _deliveryParts.fold<int>(
          0, (sum, part) => sum + (part.quantity ?? 0));
    } catch (e) {
      return 0;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Color _getStatusColor() {
    switch (_currentDelivery?.status?.toLowerCase()) {
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
    if (_currentDelivery == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Delivery Details',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
        body: const Center(
          child: Text(
            'Delivery not found',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Delivery Details',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (_currentUser != null)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileScreen(),
                    ),
                  );
                },
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey.shade300,
                  backgroundImage: _getProfileImage(_currentUser!),
                  child: _currentUser != null &&
                          _getProfileImage(_currentUser!) == null
                      ? (_currentUser!.username?.isNotEmpty == true
                          ? Text(
                              _currentUser!.username![0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : const Icon(Icons.person,
                              color: Colors.black, size: 20))
                      : null,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getStatusColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _getStatusColor(), width: 1),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.local_shipping,
                    color: _getStatusColor(),
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentDelivery!.status ?? 'Unknown',
                    style: TextStyle(
                      color: _getStatusColor(),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Location Information (Single Section - Remove Redundancy)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Location Information',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_isLoadingLocations)
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    _buildDetailRow('Pickup Location',
                        _pickupLocation?.name ?? 'Not specified'),
                    _buildDetailRow('Pickup Address',
                        _pickupLocation?.address ?? 'Not specified'),
                    _buildDetailRow('Delivery Location',
                        _deliveryLocation?.name ?? 'Not specified'),
                    _buildDetailRow('Delivery Address',
                        _deliveryLocation?.address ?? 'Not specified'),
                    _buildDetailRow('Distance', _distanceText),
                    FutureBuilder<int>(
                      future: _getTotalItemCount(),
                      builder: (context, snapshot) {
                        return _buildDetailRow(
                            'Total Items', '${snapshot.data ?? 0}');
                      },
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Delivery Information
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Delivery Information',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow('Delivery ID', _currentDelivery!.deliveryId),
                  _buildDetailRow(
                      'User ID', _currentDelivery!.userId ?? 'Not assigned'),
                  _buildDetailRow(
                      'Status', _currentDelivery!.status ?? 'Unknown'),
                  _buildDetailRow('Vehicle Number',
                      _currentDelivery!.vehicleNumber ?? 'Not assigned'),
                  if (_currentDelivery!.dueDatetime != null)
                    _buildDetailRow('Due Date',
                        _formatDateTime(_currentDelivery!.dueDatetime!)),
                  _buildDetailRow('Created At',
                      _formatDateTime(_currentDelivery!.createdAt)),
                  _buildDetailRow('Updated At',
                      _formatDateTime(_currentDelivery!.updatedAt)),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Delivery Parts
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Delivery Parts',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_isLoadingParts)
                    const Center(child: CircularProgressIndicator())
                  else if (_deliveryParts.isEmpty)
                    const Text(
                      'No parts assigned to this delivery',
                      style: TextStyle(color: Colors.white54),
                    )
                  else
                    ..._deliveryParts.map((deliveryPart) {
                      final part = _partsMap[deliveryPart.partId];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3A3A3A),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4A4A4A),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.build,
                                color: Colors.white70,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    part?.name ?? 'Unknown Part',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    'Quantity: ${deliveryPart.quantity ?? 0}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ),
          const Text(
            ': ',
            style: TextStyle(color: Colors.white70),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
