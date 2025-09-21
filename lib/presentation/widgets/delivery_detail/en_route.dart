import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
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
  late final _url = "https://www.poslaju.com.my";

  bool _isLoadingParts = true;
  bool _isLoadingLocations = true;
  bool _isUploading = false;
  Delivery? _currentDelivery;
  User? _currentUser;
  List<DeliveryPart> _deliveryParts = [];
  Map<String, Part?> _partsMap = {};
  File? _proofImage;
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
      print('🔍 Loading locations for delivery: ${_currentDelivery!.deliveryId}');
      print('🔍 Pickup location ID: ${_currentDelivery!.pickupLocation}');
      print('🔍 Delivery location ID: ${_currentDelivery!.deliveryLocation}');

      if (_currentDelivery!.pickupLocation != null) {
        _pickupLocation = await _locationService.watchLocationById(_currentDelivery!.pickupLocation!).first;
        print('🔍 Pickup location loaded: ${_pickupLocation?.name}, lat: ${_pickupLocation?.latitude}, lon: ${_pickupLocation?.longitude}');
      }

      if (_currentDelivery!.deliveryLocation != null) {
        _deliveryLocation = await _locationService.watchLocationById(_currentDelivery!.deliveryLocation!).first;
        print('🔍 Delivery location loaded: ${_deliveryLocation?.name}, lat: ${_deliveryLocation?.latitude}, lon: ${_deliveryLocation?.longitude}');
      }

      if (mounted) {
        setState(() => _isLoadingLocations = false);
        _calculateDistance();
      }
    } catch (e) {
      print('❌ Error loading locations: $e');
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
            backgroundColor: Colors.purple,
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

  Future<void> launchMyUrl(String url) async {
    final Uri uri = Uri.parse(url);

    if (!await launchUrl(uri)) {
      throw Exception('Could not launch $uri');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentDelivery == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF111111),
        appBar: AppBar(
          title: const Text('En Route'),
          backgroundColor: const Color(0xFF111111),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('Delivery not found', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final delivery = _currentDelivery!;
    final progress = _calculateProgress();

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
              'En Route',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
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
              backgroundImage: _currentUser != null ? _getProfileImage(_currentUser!) : null,
              child: _currentUser != null && _getProfileImage(_currentUser!) == null
                  ? (_currentUser!.username?.isNotEmpty == true
                      ? Text(
                          _currentUser!.username![0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.black, 
                            fontWeight: FontWeight.bold,
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
                            StreamBuilder<Location?>(
                              stream: _locationService.watchLocationById(delivery.pickupLocation!),
                              builder: (context, snapshot) {
                                final location = snapshot.data;
                                return Text(
                                  location?.address ?? 'No address available',
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
                            StreamBuilder<Location?>(
                              stream: _locationService.watchLocationById(delivery.deliveryLocation!),
                              builder: (context, snapshot) {
                                final location = snapshot.data;
                                return Text(
                                  location?.name ?? 'Unknown',
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
                            StreamBuilder<Location?>(
                              stream: _locationService.watchLocationById(delivery.deliveryLocation!),
                              builder: (context, snapshot) {
                                final location = snapshot.data;
                                return Text(
                                  location?.address ?? 'No address available',
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
                          color: Colors.grey.shade400,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Due: ${_formatDateTime(delivery.dueDatetime)}',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Progress and Times Card
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pick up at',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _formatTime(delivery.pickupTime),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Actual',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'ETA',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 14,
                            ),
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
                            'Estimated',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey.shade700,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.purple),
                    minHeight: 6,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${(progress * 100).toInt()}%',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 14,
                      ),
                    ),
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
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
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
                    // Parts list
                    ...(_deliveryParts.map((part) => _buildPartRow(part)).toList()),
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
                          style: const TextStyle(color: Colors.white, fontSize: 16),
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
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Proof of Delivery Card
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
                  // Show captured images if any
                  if (_proofImage != null) 
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        _proofImage!,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Button Row: Confirm Delivery with Camera Icon
            Row(
              children: [
                // Confirm Delivery Button
                Expanded(
                  child: _isUploading
                      ? const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
                          ),
                        )
                      : ElevatedButton.icon(
                          onPressed: _confirmDelivery,
                          icon: const Icon(Icons.check_circle, color: Colors.white, size: 20),
                          label: const Text(
                            'Confirm Delivery',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                ),
                
                const SizedBox(width: 12),
                
                // Camera Button
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D1D1D),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: IconButton(
                    onPressed: _pickProofImage,
                    icon: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 24,
                    ),
                    padding: const EdgeInsets.all(18),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Contact Button
            OutlinedButton.icon(
              onPressed: () async {
                launchMyUrl(_url);
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

  double _calculateProgress() {
    if (_currentDelivery == null ||
        _currentDelivery!.pickupTime == null ||
        _currentDelivery!.dueDatetime == null) {
      return 0.0;
    }

    final now = DateTime.now();
    final pickupTime = _currentDelivery!.pickupTime!;
    final eta = _currentDelivery!.dueDatetime!;

    if (now.isBefore(pickupTime)) return 0.0; // Not started
    if (now.isAfter(eta)) return 1.0; // Completed

    final elapsed = now.difference(pickupTime).inMinutes;
    final totalEstimated = eta.difference(pickupTime).inMinutes;

    return totalEstimated > 0 ? elapsed / totalEstimated : 0.75; // Default to 75% if calculation fails
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '-';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
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
              overflow: TextOverflow.ellipsis,
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