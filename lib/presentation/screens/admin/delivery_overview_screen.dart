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
import '../../widgets/home/sliding_tab_switcher.dart'; // Add this import

class DeliveryOverviewScreen extends ConsumerStatefulWidget {
  const DeliveryOverviewScreen({super.key});

  @override
  ConsumerState<DeliveryOverviewScreen> createState() =>
      _DeliveryOverviewScreenState();
}

class _DeliveryOverviewScreenState
    extends ConsumerState<DeliveryOverviewScreen> {
  // Remove TabController and SingleTickerProviderStateMixin
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

  // Add current tab index
  int _currentTabIndex = 0;

  Map<String, String> _locationNameCache = {};
  bool _isLoadingLocationNames = false;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    // Remove TabController initialization
    _initializeServices();
    _loadCurrentUser();
    _loadDeliveries();
  }

  @override
  void dispose() {
    // Remove TabController disposal
    super.dispose();
  }

  void _initializeServices() {
    // Initialize location services first (needed for DeliveryService)
    final localLocationDataSource = LocalLocationDatabaseService();
    final remoteLocationDataSource = SupabaseLocationDataSource();
    _locationRepository = LocationRepositoryImpl(
        localLocationDataSource, remoteLocationDataSource);
    _locationService = LocationService(_locationRepository);

    // Initialize delivery part services
    final localDeliveryPartDataSource = LocalDeliveryPartDatabaseService();
    final remoteDeliveryPartDataSource = SupabaseDeliveryPartDataSource();
    _deliveryPartRepository = DeliveryPartRepositoryImpl(
        localDeliveryPartDataSource, remoteDeliveryPartDataSource);
    _deliveryPartService = DeliveryPartService(_deliveryPartRepository);

    // Initialize delivery services with location and delivery part repositories
    final localDeliveryDataSource = LocalDeliveryDatabaseService();
    final remoteDeliveryDataSource = SupabaseDeliveryDataSource();
    _deliveryRepository = DeliveryRepositoryImpl(
        localDeliveryDataSource, remoteDeliveryDataSource);

    // IMPORTANT: Pass the repositories to DeliveryService like in item_card.dart
    _deliveryService = DeliveryService(
      _deliveryRepository,
      _deliveryPartRepository, // This was missing!
      _locationRepository, // This was missing!
    );

    // Initialize user services
    final localUserDataSource = LocalUserDatabaseService();
    final remoteUserDataSource = SupabaseUserDataSource();
    _userRepository =
        UserRepositoryImpl(localUserDataSource, remoteUserDataSource);
    _userService = UserService(_userRepository);

    // Initialize part services
    final localPartDataSource = LocalPartDatabaseService();
    final remotePartDataSource = SupabasePartDataSource();
    _partRepository =
        PartRepositoryImpl(localPartDataSource, remotePartDataSource);
    _partService = PartService(_partRepository);
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

  Future<void> _loadLocationNames() async {
    if (!_isRefreshing) {
      setState(() => _isLoadingLocationNames = true);
    }

    try {
      // Get all unique location IDs from all deliveries
      final allDeliveries = [..._assignedDeliveries, ..._completedDeliveries];
      final locationIds = <String>{};

      for (final delivery in allDeliveries) {
        if (delivery.pickupLocation != null &&
            delivery.pickupLocation!.isNotEmpty) {
          locationIds.add(delivery.pickupLocation!);
        }
        if (delivery.deliveryLocation != null &&
            delivery.deliveryLocation!.isNotEmpty) {
          locationIds.add(delivery.deliveryLocation!);
        }
      }

      // Load all location names concurrently
      final futures = locationIds.map((locationId) async {
        try {
          final locationName =
              await _deliveryService.getLocationName(locationId);
          final resolvedName = locationName ?? locationId;
          print('Resolved $locationId -> $resolvedName');
          return MapEntry(locationId, resolvedName);
        } catch (e) {
          print('Error loading location name for $locationId: $e');
          return MapEntry(locationId, locationId);
        }
      });

      final results = await Future.wait(futures);

      if (mounted) {
        setState(() {
          _locationNameCache = Map.fromEntries(results);
          _isLoadingLocationNames = false;
        });
      }
    } catch (e) {
      print('Error loading location names: $e');
      if (mounted) {
        setState(() {
          _isLoadingLocationNames = false;
        });
      }
    }
  }

  Future<void> _loadDeliveries() async {
    if (!_isRefreshing) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      print('Loading deliveries...');

      // Force refresh from remote
      final allDeliveries = await _deliveryService.watchAllDeliveries().first;

      final assignedDeliveries = allDeliveries
          .where((delivery) => delivery.status != 'delivered')
          .toList();
      final completedDeliveries = allDeliveries
          .where((delivery) => delivery.status == 'delivered')
          .toList();

      print(
          'Loaded ${assignedDeliveries.length} assigned and ${completedDeliveries.length} completed deliveries');

      if (mounted) {
        setState(() {
          _assignedDeliveries = assignedDeliveries;
          _completedDeliveries = completedDeliveries;
          _filteredAssignedDeliveries = assignedDeliveries;
          _filteredCompletedDeliveries = completedDeliveries;
          if (!_isRefreshing) _isLoading = false;
        });
      }

      // Load location names after deliveries are loaded
      await _loadLocationNames();

      // Apply current filters
      _applyFilters();
    } catch (e) {
      print('Error loading deliveries: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load deliveries: $e';
          if (!_isRefreshing) _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshAllData() async {
    if (_isRefreshing) return; // Prevent multiple simultaneous refreshes

    setState(() {
      _isRefreshing = true;
    });

    try {
      print('Starting pull-to-refresh...');

      // Clear caches to force fresh data
      _locationNameCache.clear();

      // Reload all data in parallel
      await Future.wait([
        _loadDeliveries(),
        _loadCurrentUser(),
      ]);

      _applyFilters();

      // Show success feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Deliveries updated successfully'),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }

      print('Pull-to-refresh completed successfully');
    } catch (e) {
      print('Error during pull-to-refresh: $e');

      // Show error feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Failed to refresh: ${e.toString()}'),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
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

        // Apply search query filter using resolved location names
        bool matchesSearch =
            _searchQuery.isEmpty || _matchesSearchQuery(delivery);

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

        // Apply search query filter using resolved location names
        bool matchesSearch =
            _searchQuery.isEmpty || _matchesSearchQuery(delivery);

        return matchesStatus && matchesDateRange && matchesSearch;
      }).toList();
    });
  }

  // helper method for search matching
  bool _matchesSearchQuery(Delivery delivery) {
    final query = _searchQuery.toLowerCase().trim();

    if (query.isEmpty) return true;

    // Search by delivery ID
    if (delivery.deliveryId.toLowerCase().contains(query)) {
      return true;
    }

    // Search by delivery status
    if (delivery.status?.toLowerCase().contains(query) == true) {
      return true;
    }

    // Search by vehicle number
    if (delivery.vehicleNumber?.toLowerCase().contains(query) == true) {
      return true;
    }

    // Search by pickup location name
    if (delivery.pickupLocation != null) {
      final pickupLocationName = _locationNameCache[delivery.pickupLocation!];
      if (pickupLocationName?.toLowerCase().contains(query) == true) {
        return true;
      }
      // Also search by location ID as fallback
      if (delivery.pickupLocation!.toLowerCase().contains(query)) {
        return true;
      }
    }

    // Search by delivery location name
    if (delivery.deliveryLocation != null) {
      final deliveryLocationName =
          _locationNameCache[delivery.deliveryLocation!];
      if (deliveryLocationName?.toLowerCase().contains(query) == true) {
        return true;
      }
      // Also search by location ID as fallback
      if (delivery.deliveryLocation!.toLowerCase().contains(query)) {
        return true;
      }
    }

    return false;
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
        title: Row(
          children: [
            const Text(
              'Delivery Overview',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            if (_isRefreshing) ...[
              const SizedBox(width: 8),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFFEA41D),
                ),
              ),
            ],
          ],
        ),
        actions: [
          // Add manual refresh button
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: _isRefreshing ? const Color(0xFFFEA41D) : Colors.white70,
            ),
            onPressed: _isRefreshing ? null : _refreshAllData,
            tooltip: 'Refresh deliveries',
          ),
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
      body: RefreshIndicator(
        onRefresh: _refreshAllData,
        color: const Color(0xFFFEA41D),
        backgroundColor: const Color(0xFF2A2A2A),
        displacement: 40.0,
        strokeWidth: 3.0,
        child: Column(
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
                  Icon(
                    Icons.search,
                    color: _isRefreshing ? Colors.white38 : Colors.white70,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      style: TextStyle(
                        color: _isRefreshing ? Colors.white38 : Colors.white,
                      ),
                      decoration: InputDecoration(
                        hintText: _isLoadingLocationNames
                            ? 'Loading locations...'
                            : _isRefreshing
                                ? 'Refreshing...'
                                : 'Search deliveries...',
                        hintStyle: const TextStyle(color: Colors.white54),
                        border: InputBorder.none,
                      ),
                      enabled: !_isLoadingLocationNames && !_isRefreshing,
                      onChanged: _filterDeliveries,
                    ),
                  ),
                  if (_isLoadingLocationNames || _isRefreshing)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white54,
                      ),
                    )
                  else
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

            // Replace TabBar with SlidingTabSwitcher
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: SlidingTabSwitcher(
                tabs: const ['Assigned', 'Completed'],
                initialIndex: _currentTabIndex,
                onTabSelected: (index) {
                  setState(() {
                    _currentTabIndex = index;
                  });
                },
              ),
            ),

            const SizedBox(height: 16),

            // Status indicator when refreshing
            if (_isRefreshing)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEA41D).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFFEA41D).withOpacity(0.3),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFFEA41D),
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Refreshing deliveries...',
                      style: TextStyle(
                        color: Color(0xFFFEA41D),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

            if (_isRefreshing) const SizedBox(height: 16),

            // Replace TabBarView with conditional rendering
            Expanded(
              child: _isLoading && !_isRefreshing
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null && !_isRefreshing
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _refreshAllData,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFEA41D),
                                  foregroundColor: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        )
                      : _currentTabIndex == 0
                          ? _buildDeliveryList(_filteredAssignedDeliveries)
                          : _buildDeliveryList(_filteredCompletedDeliveries),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryList(List<Delivery> deliveries) {
    if (deliveries.isEmpty && !_isLoading && !_isRefreshing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_shipping_outlined,
              color: Colors.white54,
              size: 48,
            ),
            SizedBox(height: 16),
            Text(
              'No deliveries found',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Pull down to refresh',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: deliveries.length,
      physics:
          const AlwaysScrollableScrollPhysics(), // Enable pull-to-refresh even with few items
      itemBuilder: (context, index) {
        final delivery = deliveries[index];
        return _DeliveryCard(
          delivery: delivery,
          deliveryService: _deliveryService,
          onTap: () => _navigateToDeliveryDetail(delivery),
          isRefreshing: _isRefreshing,
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

class _DeliveryCard extends StatefulWidget {
  final Delivery delivery;
  final DeliveryService deliveryService;
  final VoidCallback onTap;
  final bool isRefreshing;

  const _DeliveryCard({
    required this.delivery,
    required this.deliveryService,
    required this.onTap,
    this.isRefreshing = false,
  });

  @override
  State<_DeliveryCard> createState() => _DeliveryCardState();
}

class _DeliveryCardState extends State<_DeliveryCard> {
  String? _pickupLocationName;
  String? _deliveryLocationName;
  String? _distance;
  int? _itemCount;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(_DeliveryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload data when parent is refreshing or when delivery changes
    if (widget.isRefreshing && !oldWidget.isRefreshing ||
        widget.delivery.deliveryId != oldWidget.delivery.deliveryId) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final results = await Future.wait([
        _getLocationName(widget.delivery.pickupLocation),
        _getLocationName(widget.delivery.deliveryLocation),
        _calculateDistance(),
        _getItemCount(),
      ]);

      if (mounted) {
        setState(() {
          _pickupLocationName = results[0] as String;
          _deliveryLocationName = results[1] as String;
          _distance = results[2] as String;
          _itemCount = results[3] as int;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading delivery card data: $e');
      if (mounted) {
        setState(() {
          _pickupLocationName = 'Unknown Location';
          _deliveryLocationName = 'Unknown Location';
          _distance = 'n/a';
          _itemCount = 0;
          _isLoading = false;
        });
      }
    }
  }

  // Use the cached location names from parent if available
  Future<String> _getLocationName(String? locationId) async {
    if (locationId == null || locationId.isEmpty) {
      return 'Unknown Location';
    }

    try {
      final locationName =
          await widget.deliveryService.getLocationName(locationId);
      final resolvedName = locationName ?? locationId;

      return resolvedName;
    } catch (e) {
      print('Error getting location name for $locationId: $e');
      return locationId;
    }
  }

  // Calculate distance
  Future<String> _calculateDistance() async {
    if (widget.delivery.pickupLocation == null ||
        widget.delivery.deliveryLocation == null) {
      return 'n/a';
    }

    try {
      final coordinates = await widget.deliveryService.getDeliveryCoordinates(
        widget.delivery.pickupLocation!,
        widget.delivery.deliveryLocation!,
      );

      final distance = await DistanceCalculator.calculateDistance(
        coordinates['pickupLat'],
        coordinates['pickupLon'],
        coordinates['deliveryLat'],
        coordinates['deliveryLon'],
        useApi: false, // Same as item_card.dart
      );

      return DistanceCalculator.formatDistance(distance);
    } catch (e) {
      print('Error calculating distance: $e');
      return 'n/a';
    }
  }

  // Get item count
  Future<int> _getItemCount() async {
    try {
      // Use the same method as item_card.dart
      final itemCount = await widget.deliveryService
          .getNumberOfDeliveryPartsByDeliveryId(widget.delivery.deliveryId)
          .first;
      return itemCount ?? 0;
    } catch (e) {
      print('Error getting item count: $e');
      return 0;
    }
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Color _getStatusColor() {
    switch (widget.delivery.status?.toLowerCase()) {
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
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: widget.isRefreshing
              ? const Color(0xFF2A2A2A).withOpacity(0.7)
              : const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(12),
          border: widget.isRefreshing
              ? Border.all(
                  color: const Color(0xFFFEA41D).withOpacity(0.3),
                  width: 1,
                )
              : null,
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
                  child: Icon(
                    Icons.local_shipping_outlined,
                    color: widget.isRefreshing ? Colors.white70 : Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'From',
                            style:
                                TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                          Text(
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
                            child: _isLoading || widget.isRefreshing
                                ? Container(
                                    height: 16,
                                    width: 60,
                                    decoration: BoxDecoration(
                                      color: Colors.white24,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: widget.isRefreshing
                                        ? const Center(
                                            child: SizedBox(
                                              width: 10,
                                              height: 10,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 1.5,
                                                color: Colors.white54,
                                              ),
                                            ),
                                          )
                                        : null,
                                  )
                                : Text(
                                    _pickupLocationName ?? 'Loading...',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _isLoading || widget.isRefreshing
                                ? Container(
                                    height: 16,
                                    width: 60,
                                    decoration: BoxDecoration(
                                      color: Colors.white24,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: widget.isRefreshing
                                        ? const Center(
                                            child: SizedBox(
                                              width: 10,
                                              height: 10,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 1.5,
                                                color: Colors.white54,
                                              ),
                                            ),
                                          )
                                        : null,
                                  )
                                : Text(
                                    _deliveryLocationName ?? 'Loading...',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.right,
                                    overflow: TextOverflow.ellipsis,
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
                    widget.delivery.status ?? 'Unknown',
                    style: TextStyle(
                      color: _getStatusColor(),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'Due ${_formatTime(widget.delivery.dueDatetime)}',
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
                _isLoading || widget.isRefreshing
                    ? Container(
                        width: 50,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      )
                    : Text(
                        '${_itemCount ?? 0} items',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12),
                      ),
                const SizedBox(width: 16),
                const Icon(Icons.location_on_outlined,
                    color: Colors.white54, size: 16),
                const SizedBox(width: 4),
                _isLoading || widget.isRefreshing
                    ? Container(
                        width: 40,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      )
                    : Text(
                        _distance ?? 'n/a',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12),
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
