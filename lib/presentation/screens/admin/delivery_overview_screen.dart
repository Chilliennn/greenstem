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
import '../admin/delivery_detail_screen.dart';
import '../../../domain/services/delivery_part_service.dart';
import '../../../domain/services/part_service.dart';
import '../../../data/repositories/delivery_part_repository_impl.dart';
import '../../../data/repositories/part_repository_impl.dart';
import '../../../data/datasources/local/local_delivery_part_database_service.dart';
import '../../../data/datasources/local/local_part_database_service.dart';
import '../../../data/datasources/remote/remote_delivery_part_datasource.dart';
import '../../../data/datasources/remote/remote_part_datasource.dart';
import '../../../domain/services/location_service.dart';
import '../../../data/repositories/location_repository_impl.dart';
import '../../../data/datasources/local/local_location_database_service.dart';
import '../../../data/datasources/remote/remote_location_datasource.dart';
import 'package:greenstem/presentation/screens/profiles/profile_screen.dart';

class DeliveryOverviewScreen extends ConsumerStatefulWidget {
  const DeliveryOverviewScreen({super.key});

  @override
  ConsumerState<DeliveryOverviewScreen> createState() =>
      _DeliveryOverviewScreenState();
}

class _DeliveryOverviewScreenState extends ConsumerState<DeliveryOverviewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final DeliveryService _deliveryService;
  late final UserService _userService;
  late final DeliveryPartService _deliveryPartService;
  late final PartService _partService;
  late final DeliveryRepositoryImpl _deliveryRepository;
  late final UserRepositoryImpl _userRepository;
  late final DeliveryPartRepositoryImpl _deliveryPartRepository;
  late final PartRepositoryImpl _partRepository;
  late final LocationService _locationService;
  late final LocationRepositoryImpl _locationRepository;

  List<Delivery> _assignedDeliveries = [];
  List<Delivery> _completedDeliveries = [];
  List<Delivery> _filteredAssignedDeliveries = [];
  List<Delivery> _filteredCompletedDeliveries = [];

  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  User? _currentUser;

  // Add filter state variables
  String? _selectedStatus;
  DateTime? _fromDate;
  DateTime? _toDate;

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
    final localDeliveryDataSource = LocalDeliveryDatabaseService();
    final remoteDeliveryDataSource = SupabaseDeliveryDataSource();
    _deliveryRepository = DeliveryRepositoryImpl(
        localDeliveryDataSource, remoteDeliveryDataSource);
    _deliveryService = DeliveryService(_deliveryRepository);

    final localUserDataSource = LocalUserDatabaseService();
    final remoteUserDataSource = SupabaseUserDataSource();
    _userRepository =
        UserRepositoryImpl(localUserDataSource, remoteUserDataSource);
    _userService = UserService(_userRepository);

    final localDeliveryPartDataSource = LocalDeliveryPartDatabaseService();
    final remoteDeliveryPartDataSource = SupabaseDeliveryPartDataSource();
    _deliveryPartRepository = DeliveryPartRepositoryImpl(
        localDeliveryPartDataSource, remoteDeliveryPartDataSource);
    _deliveryPartService = DeliveryPartService(_deliveryPartRepository);

    final localPartDataSource = LocalPartDatabaseService();
    final remotePartDataSource = SupabasePartDataSource();
    _partRepository =
        PartRepositoryImpl(localPartDataSource, remotePartDataSource);
    _partService = PartService(_partRepository);

    final localLocationDataSource = LocalLocationDatabaseService();
    final remoteLocationDataSource = SupabaseLocationDataSource();
    _locationRepository = LocationRepositoryImpl(
        localLocationDataSource, remoteLocationDataSource);
    _locationService = LocationService(_locationRepository);
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

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF2A2A2A),
              title: const Text(
                'Filter Deliveries',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Filter
                  const Text(
                    'Status',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3A3A3A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedStatus,
                      hint: const Text(
                        'Select Status',
                        style: TextStyle(color: Colors.white54),
                      ),
                      dropdownColor: const Color(0xFF3A3A3A),
                      underline: Container(),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text(
                            'All Statuses',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        ...['awaiting', 'picked up', 'en route', 'delivered']
                            .map((String status) {
                          return DropdownMenuItem<String>(
                            value: status,
                            child: Text(
                              status[0].toUpperCase() + status.substring(1),
                              style: const TextStyle(color: Colors.white),
                            ),
                          );
                        }),
                      ],
                      onChanged: (String? newValue) {
                        setDialogState(() {
                          _selectedStatus = newValue;
                        });
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Date Range Filter
                  const Text(
                    'Date Range',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _fromDate ??
                                  DateTime.now()
                                      .subtract(const Duration(days: 30)),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: const ColorScheme.dark(
                                      primary: Color(0xFFFEA41D),
                                      surface: Color(0xFF2A2A2A),
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) {
                              setDialogState(() {
                                _fromDate = picked;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3A3A3A),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _fromDate != null
                                        ? '${_fromDate!.day}/${_fromDate!.month}/${_fromDate!.year}'
                                        : 'From Date',
                                    style: TextStyle(
                                      color: _fromDate != null
                                          ? Colors.white
                                          : Colors.white54,
                                    ),
                                  ),
                                ),
                                if (_fromDate != null)
                                  GestureDetector(
                                    onTap: () {
                                      setDialogState(() {
                                        _fromDate = null;
                                      });
                                    },
                                    child: const Icon(
                                      Icons.clear,
                                      color: Colors.white54,
                                      size: 16,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _toDate ?? DateTime.now(),
                              firstDate: _fromDate ?? DateTime(2020),
                              lastDate: DateTime.now(),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: const ColorScheme.dark(
                                      primary: Color(0xFFFEA41D),
                                      surface: Color(0xFF2A2A2A),
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) {
                              setDialogState(() {
                                _toDate = picked;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3A3A3A),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _toDate != null
                                        ? '${_toDate!.day}/${_toDate!.month}/${_toDate!.year}'
                                        : 'To Date',
                                    style: TextStyle(
                                      color: _toDate != null
                                          ? Colors.white
                                          : Colors.white54,
                                    ),
                                  ),
                                ),
                                if (_toDate != null)
                                  GestureDetector(
                                    onTap: () {
                                      setDialogState(() {
                                        _toDate = null;
                                      });
                                    },
                                    child: const Icon(
                                      Icons.clear,
                                      color: Colors.white54,
                                      size: 16,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setDialogState(() {
                      _selectedStatus = null;
                      _fromDate = null;
                      _toDate = null;
                    });
                    _applyFilters();
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Clear',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    _applyFilters();
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Apply',
                    style: TextStyle(color: Color(0xFFFEA41D)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _applyFilters() {
    setState(() {
      _filteredAssignedDeliveries = _assignedDeliveries.where((delivery) {
        bool matchesStatus =
            _selectedStatus == null || delivery.status == _selectedStatus;
        bool matchesDateRange = true;

        if (_fromDate != null || _toDate != null) {
          final deliveryDate = delivery.createdAt;
          if (_fromDate != null && deliveryDate.isBefore(_fromDate!)) {
            matchesDateRange = false;
          }
          if (_toDate != null &&
              deliveryDate.isAfter(_toDate!.add(const Duration(days: 1)))) {
            matchesDateRange = false;
          }
        }

        // Apply search query filter
        bool matchesSearch = _searchQuery.isEmpty ||
            delivery.deliveryId
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ||
            delivery.pickupLocation
                    ?.toLowerCase()
                    .contains(_searchQuery.toLowerCase()) ==
                true ||
            delivery.deliveryLocation
                    ?.toLowerCase()
                    .contains(_searchQuery.toLowerCase()) ==
                true ||
            delivery.status
                    ?.toLowerCase()
                    .contains(_searchQuery.toLowerCase()) ==
                true;

        return matchesStatus && matchesDateRange && matchesSearch;
      }).toList();

      _filteredCompletedDeliveries = _completedDeliveries.where((delivery) {
        bool matchesStatus =
            _selectedStatus == null || delivery.status == _selectedStatus;
        bool matchesDateRange = true;

        if (_fromDate != null || _toDate != null) {
          final deliveryDate = delivery.createdAt;
          if (_fromDate != null && deliveryDate.isBefore(_fromDate!)) {
            matchesDateRange = false;
          }
          if (_toDate != null &&
              deliveryDate.isAfter(_toDate!.add(const Duration(days: 1)))) {
            matchesDateRange = false;
          }
        }

        // Apply search query filter
        bool matchesSearch = _searchQuery.isEmpty ||
            delivery.deliveryId
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ||
            delivery.pickupLocation
                    ?.toLowerCase()
                    .contains(_searchQuery.toLowerCase()) ==
                true ||
            delivery.deliveryLocation
                    ?.toLowerCase()
                    .contains(_searchQuery.toLowerCase()) ==
                true;

        return matchesStatus && matchesDateRange && matchesSearch;
      }).toList();
    });
  }

  void _filterDeliveries(String query) {
    setState(() {
      _searchQuery = query;
    });
    _applyFilters();
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
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfileScreen(),
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
                  icon: Icon(
                    Icons.tune,
                    color: (_selectedStatus != null ||
                            _fromDate != null ||
                            _toDate != null)
                        ? const Color(0xFFFEA41D)
                        : Colors.white70,
                  ),
                  onPressed: _showFilterDialog,
                ),
              ],
            ),
          ),

          // Rest of the build method remains the same...
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
        builder: (context) => DeliveryOverviewDetailScreen(
          delivery: delivery,
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

  // Get location name by ID
  Future<String> _getLocationName(String? locationId) async {
    if (locationId == null || locationId.isEmpty) {
      return 'Location Name';
    }

    try {
      final locationName = await deliveryService.getLocationName(locationId);
      return locationName ?? 'Location Name';
    } catch (e) {
      return 'Location Name';
    }
  }

  // Calculate distance
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

  // Calculate number of items using delivery parts
  Future<int> _getItemCount() async {
    try {
      final itemCount = await deliveryService
          .getNumberOfDeliveryPartsByDeliveryId(delivery.deliveryId)
          .first;
      return itemCount ?? 0;
    } catch (e) {
      return 0;
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
                            child: FutureBuilder<String>(
                              future: _getLocationName(delivery.pickupLocation),
                              builder: (context, snapshot) {
                                return Text(
                                  snapshot.data ?? 'Loading...',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FutureBuilder<String>(
                              future:
                                  _getLocationName(delivery.deliveryLocation),
                              builder: (context, snapshot) {
                                return Text(
                                  snapshot.data ?? 'Loading...',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                  textAlign: TextAlign.right,
                                  overflow: TextOverflow.ellipsis,
                                );
                              },
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
                const Text(
                  'Delivery Status: ',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
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
                FutureBuilder<int>(
                  future: _getItemCount(),
                  builder: (context, snapshot) {
                    return Text(
                      '${snapshot.data ?? 2} items',
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12),
                    );
                  },
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
