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
import '../../../data/repositories/delivery_repository_impl.dart';
import '../../../data/repositories/user_repository_impl.dart';
import '../../../data/repositories/delivery_part_repository_impl.dart';
import '../../../data/repositories/part_repository_impl.dart';
import '../../../data/datasources/local/local_delivery_database_service.dart';
import '../../../data/datasources/local/local_user_database_service.dart';
import '../../../data/datasources/local/local_delivery_part_database_service.dart';
import '../../../data/datasources/local/local_part_database_service.dart';
import '../../../data/datasources/remote/remote_delivery_datasource.dart';
import '../../../data/datasources/remote/remote_user_datasource.dart';
import '../../../data/datasources/remote/remote_delivery_part_datasource.dart';
import '../../../data/datasources/remote/remote_part_datasource.dart';
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

  Future<void> _rejectDelivery() async {
    if (_currentDelivery == null) return;

    // Show confirmation dialog
    final shouldReject = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1D1D1D),
        title: const Text('Reject Delivery', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to reject this delivery? This action cannot be undone.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldReject != true) return;

    setState(() => _isUpdating = true);

    try {
      final updatedDelivery = _currentDelivery!.copyWith(
        status: 'rejected',
        updatedAt: DateTime.now(),
      );
      final result = await _deliveryService.updateDelivery(updatedDelivery);

      if (result != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Delivery rejected'),
            backgroundColor: Colors.red,
          ),
        );

        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject delivery: $e'),
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
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
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
              backgroundImage: _currentUser != null ? _getProfileImage(_currentUser!) : null,
              child: _currentUser != null && _getProfileImage(_currentUser!) == null
                  ? (_currentUser!.username?.isNotEmpty == true
                  ? Text(
                _currentUser!.username![0].toUpperCase(),
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
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
            // Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.cyellow,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Awaiting',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Due Time Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1D1D1D),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Due: ${_formatTime(delivery.dueDatetime)}',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  Text(
                    '0.2 km • 6 min',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Location Card
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
                              delivery.pickupLocation ?? 'Warehouse',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Warehouse 4',
                              style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
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
                              delivery.deliveryLocation ?? 'Bay 3A',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Workgroup Plant',
                              textAlign: TextAlign.right,
                              style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
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
                  Text(
                    'Expected pickup time',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(delivery.dueDatetime),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Vehicle Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1D1D1D),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.directions_car, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          delivery.vehicleNumber ?? 'Honda Civic 2019',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Fleet Number: #2',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Parts List
            if (_isLoadingParts)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.cyellow),
                  ),
                ),
              )
            else if (_deliveryParts.isNotEmpty) ...[
              ..._deliveryParts.map((part) => _buildPartCard(part)),
            ],

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
                onPressed: _acceptDelivery,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.cyellow,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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

            // Contact Button (Bottom)
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
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildPartCard(DeliveryPart part) {
    final partDetails = _partsMap[part.partId];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1D1D),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  partDetails?.name ?? 'Unknown Part',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  partDetails?.partId ?? 'N/A',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Qty ${part.quantity ?? 0}',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
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