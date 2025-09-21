import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/delivery.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/entities/delivery_part.dart';
import '../../../domain/entities/part.dart';
import '../../../domain/entities/location.dart';
import '../../../domain/services/delivery_service.dart';
import '../../../domain/services/user_service.dart';
import '../../../domain/services/delivery_part_service.dart';
import '../../../domain/services/part_service.dart';
import '../../../domain/services/location_service.dart';
import '../../../domain/services/delivery_proof_upload_service.dart';
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
import '../../../core/utils/distance_calculator.dart';
import '../../providers/auth_provider.dart';

class DeliveredPage extends ConsumerStatefulWidget {
  final Delivery delivery;

  const DeliveredPage({super.key, required this.delivery});

  @override
  ConsumerState<DeliveredPage> createState() => _DeliveredPageState();
}

class _DeliveredPageState extends ConsumerState<DeliveredPage> {
  late final DeliveryService _deliveryService;
  late final UserService _userService;
  late final DeliveryPartService _deliveryPartService;
  late final PartService _partService;
  late final LocationService _locationService;
  
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
    final deliveryRepository = DeliveryRepositoryImpl(localDeliveryDataSource, remoteDeliveryDataSource);

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

    _deliveryService = DeliveryService(deliveryRepository, deliveryPartRepository, locationRepository);
  }

  Future<void> _loadLocations() async {
    if (_currentDelivery == null) return;

    setState(() => _isLoadingLocations = true);

    try {
      if (_currentDelivery!.pickupLocation != null) {
        _pickupLocation = await _locationService.watchLocationById(_currentDelivery!.pickupLocation!).first;
      }
      
      if (_currentDelivery!.deliveryLocation != null) {
        _deliveryLocation = await _locationService.watchLocationById(_currentDelivery!.deliveryLocation!).first;
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
      final distance = await DistanceCalculator.calculateDistance(
        _pickupLocation!.latitude!,
        _pickupLocation!.longitude!,
        _deliveryLocation!.latitude!,
        _deliveryLocation!.longitude!,
        useApi: true,
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

  int _getTotalItems() {
    return _deliveryParts.fold<int>(0, (sum, part) => sum + (part.quantity ?? 0));
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

  Widget _buildProofImageWidget(String? proofImagePath) {
    if (proofImagePath == null || proofImagePath.isEmpty) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<File?>(
      future: DeliveryProofUploadService.loadDeliveryProof(
        deliveryId: widget.delivery.deliveryId,
        remoteUrl: proofImagePath,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
              ),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          // Try to load from remote URL directly
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              proofImagePath,
              fit: BoxFit.cover,
              width: double.infinity,
              height: 200,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade800,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade800,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image_not_supported, 
                             color: Colors.grey, size: 48),
                        SizedBox(height: 8),
                        Text(
                          'Image not available',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        }

        final imageFile = snapshot.data!;
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            imageFile,
            fit: BoxFit.cover,
            width: double.infinity,
            height: 200,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image_not_supported, 
                           color: Colors.grey, size: 48),
                      SizedBox(height: 8),
                      Text(
                        'Image not available',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildLocationInfo(String label, String? locationId) {
    if (locationId == null) {
      return _buildLocationDisplay(label, 'Unknown Location', 'No address');
    }

    return StreamBuilder<Location?>(
      stream: _locationService.watchLocationById(locationId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLocationDisplay(label, 'Loading...', 'Loading...');
        }

        final location = snapshot.data;
        if (location == null) {
          return _buildLocationDisplay(label, 'Unknown Location', 'No address');
        }

        return _buildLocationDisplay(
          label,
          location.name ?? 'Unknown Location',
          location.address ?? location.type ?? 'Location Category',
        );
      },
    );
  }

  Widget _buildLocationDisplay(String label, String name, String address) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          address,
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildStatIcon(IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.grey.shade400,
          size: 16,
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildPartRow(DeliveryPart part) {
    final partDetails = _partsMap[part.partId];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              partDetails?.name ?? 'Unknown Part',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              (partDetails?.partId.length ?? 0) > 6
                  ? partDetails!.partId.substring(0, 6).toUpperCase()
                  : (partDetails?.partId ?? 'N/A').toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '${part.quantity ?? 0}',
              textAlign: TextAlign.right,
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

  @override
  Widget build(BuildContext context) {
    if (_currentDelivery == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF111111),
        appBar: AppBar(
          title: const Text('Delivered'),
          backgroundColor: const Color(0xFF111111),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('Delivery not found', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final delivery = _currentDelivery!;

    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const Text(
              'Delivered',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              delivery.deliveryId.length > 6
                  ? delivery.deliveryId.substring(0, 6).toUpperCase()
                  : delivery.deliveryId.toUpperCase(),
              style: const TextStyle(color: Colors.green, fontSize: 16),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey.shade300,
              backgroundImage: _currentUser != null ? _getProfileImage(_currentUser!) : null,
              child: _currentUser != null && _getProfileImage(_currentUser!) == null
                  ? (_currentUser!.username?.isNotEmpty == true
                      ? Text(
                          _currentUser!.username![0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.black, 
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
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
            // Delivered Status Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1D1D1D),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Delivery Completed',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatDateTime(delivery.deliveredTime),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildLocationInfo('From', delivery.pickupLocation),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.arrow_forward,
                        color: Colors.grey.shade400,
                        size: 20,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildLocationInfo('To', delivery.deliveryLocation),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatIcon(Icons.route, _distanceText),
                      _buildStatIcon(Icons.access_time, _durationText),
                      _buildStatIcon(Icons.inventory, '${_getTotalItems()} items'),
                    ],
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
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Delivered Items',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_isLoadingParts)
                    const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                      ),
                    )
                  else if (_errorMessage != null)
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    )
                  else if (_deliveryParts.isEmpty)
                    const Text(
                      'No parts found for this delivery',
                      style: TextStyle(color: Colors.grey),
                    )
                  else ...[
                    // Header row
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Part Name',
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Part ID',
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Qty',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Parts list
                    ...(_deliveryParts.map((part) => _buildPartRow(part)).toList()),
                  ],
                ],
              ),
            ),

            // Proof of Delivery Section
            if (delivery.proofImgPath != null && delivery.proofImgPath!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1D1D1D),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.camera_alt,
                          color: Colors.green,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Proof of Delivery',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Delivered at ${_formatDateTime(delivery.deliveredTime)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildProofImageWidget(delivery.proofImgPath),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}