import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
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

class EnRoutePage extends ConsumerStatefulWidget {
  final Delivery delivery;

  const EnRoutePage({super.key, required this.delivery});

  @override
  ConsumerState<EnRoutePage> createState() => _EnRoutePageState();
}

class _EnRoutePageState extends ConsumerState<EnRoutePage> {
  late final DeliveryService _deliveryService;
  late final UserService _userService;
  late final DeliveryPartService _deliveryPartService;
  late final PartService _partService;
  late final LocationService _locationService;

  bool _isLoadingParts = true;
  bool _isLoadingLocations = true;
  bool _isUploading = false;
  Delivery? _currentDelivery;
  User? _currentUser;
  List<DeliveryPart> _deliveryParts = [];
  Map<String, Part?> _partsMap = {};
  File? _proofImage; // Changed to single image
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
        _pickupLocation!.latitude,
        _pickupLocation!.longitude,
        _deliveryLocation!.latitude,
        _deliveryLocation!.longitude,
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

  Future<void> _pickProofImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _proofImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      print('Error picking proof image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to take photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmDelivery() async {
    if (_currentDelivery == null) return;

    if (_proofImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please take a proof photo before confirming delivery'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final authState = ref.read(authProvider);
      final userId = authState.user?.userId ?? '';

      // Upload the delivery proof using the new service
      final remoteUrl = await DeliveryProofUploadService.saveDeliveryProofBoth(
        userId: userId,
        deliveryId: _currentDelivery!.deliveryId,
        imageFile: _proofImage!,
      );

      // Update delivery status to 'delivered' with proof image path
      final updatedDelivery = _currentDelivery!.copyWith(
        status: 'delivered',
        updatedAt: DateTime.now(),
        deliveredTime: DateTime.now(),
        proofImgPath: remoteUrl,
      );

      final result = await _deliveryService.updateDelivery(updatedDelivery);

      if (result != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Delivery confirmed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('Error confirming delivery: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to confirm delivery: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentDelivery == null) {
      return Scaffold(
        backgroundColor: AppColors.cblack,
        appBar: AppBar(
          title: const Text('En Route'),
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
              'En Route',
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
              style: const TextStyle(color: Colors.purple, fontSize: 16),
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
                            StreamBuilder<Location?>(
                              stream: _locationService.watchLocationById(delivery.pickupLocation!),
                              builder: (context, snapshot) {
                                final location = snapshot.data;
                                return Text(
                                  location?.name ?? 'Unknown',
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
                            color: Colors.purple,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.local_shipping,
                            color: Colors.white,
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
                      Text(
                        '$_distanceText • $_durationText',
                        style: TextStyle(
                            color: Colors.grey.shade400, fontSize: 14),
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

            // Stats Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1D1D1D),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    icon: Icons.location_on,
                    label: 'Distance',
                    value: _distanceText,
                  ),
                  _buildStatItem(
                    icon: Icons.access_time,
                    label: 'Time',
                    value: _durationText,
                  ),
                  _buildStatItem(
                    icon: Icons.inventory,
                    label: 'Items',
                    value: '${_getTotalItems()}',
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
                          AlwaysStoppedAnimation<Color>(Colors.purple),
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
                              '${_getTotalItems()}',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 16),
                            ),
                          ],
                        ),
                      ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Proof of Delivery Section
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
                    'Proof of Delivery',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_proofImage != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        _proofImage!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 200,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickProofImage,
                            icon: const Icon(Icons.camera_alt, color: Colors.white),
                            label: const Text(
                              'Retake Photo',
                              style: TextStyle(color: Colors.white),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: const BorderSide(color: Colors.white),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _proofImage = null;
                              });
                            },
                            icon: const Icon(Icons.delete, color: Colors.white),
                            label: const Text(
                              'Remove',
                              style: TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade800,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.grey.shade600,
                          style: BorderStyle.solid,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Take a photo as proof of delivery',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _pickProofImage,
                      icon: const Icon(Icons.camera_alt, color: Colors.white),
                      label: const Text(
                        'Take Photo',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Confirm Delivery Button
            if (_isUploading)
              const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
                ),
              )
            else
              ElevatedButton(
                onPressed: _confirmDelivery,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Confirm Delivery',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({required IconData icon, required String label, required String value}) {
    return Column(
      children: [
        Icon(icon, color: Colors.purple, size: 24),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 12,
          ),
        ),
        if (value.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
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