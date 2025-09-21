import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:greenstem/presentation/screens/admin/delivery_overview_screen.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:greenstem/data/datasources/local/local_delivery_database_service.dart';
import 'package:greenstem/data/datasources/local/local_delivery_part_database_service.dart';
import 'package:greenstem/data/datasources/local/local_part_database_service.dart';
import 'package:greenstem/data/datasources/remote/remote_delivery_datasource.dart';
import 'package:greenstem/data/datasources/remote/remote_delivery_part_datasource.dart';
import 'package:greenstem/data/datasources/remote/remote_part_datasource.dart';
import 'package:greenstem/data/repositories/delivery_repository_impl.dart';
import 'package:greenstem/data/repositories/delivery_part_repository_impl.dart';
import 'package:greenstem/data/repositories/part_repository_impl.dart';
import 'package:greenstem/domain/entities/delivery.dart';
import 'package:greenstem/domain/entities/delivery_part.dart';
import 'package:greenstem/domain/entities/part.dart';
import 'package:greenstem/domain/services/delivery_service.dart';
import 'package:greenstem/domain/services/delivery_part_service.dart';
import 'package:greenstem/domain/services/part_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../auth/sign_in_screen.dart';
import '../profiles/profile_screen.dart';

class StackedColumnData {
  final String period;
  final String partName;
  final int count;

  StackedColumnData(this.period, this.partName, this.count);
}

// Add this new class after StackedColumnData
class DeliveryStatusData {
  final String status;
  final int count;
  final Color color;

  DeliveryStatusData(this.status, this.count, this.color);
}

// Add this new class at the top with other classes
class TopSellingPart {
  final String partId;
  final String name;
  final String? category;
  final String? description;
  final int totalSold;

  TopSellingPart({
    required this.partId,
    required this.name,
    this.category,
    this.description,
    required this.totalSold,
  });
}

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _isMonthlyView = true;
  List<Delivery> _deliveriesForColumnChart = [];
  List<Delivery> _deliveriesForPieChart = [];
  List<DeliveryPart> _deliveryParts = [];
  List<Part> _parts = [];
  bool _isLoading = true;
  String? _errorMessage;

  late DeliveryService _deliveryService;
  late DeliveryPartService _deliveryPartService;
  late PartService _partService;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _loadData();
  }

  void _initializeServices() {
    try {
      // Initialize delivery part repository and service first
      final localDeliveryPartDataSource = LocalDeliveryPartDatabaseService();
      final remoteDeliveryPartDataSource = SupabaseDeliveryPartDataSource();
      final deliveryPartRepository = DeliveryPartRepositoryImpl(
          localDeliveryPartDataSource, remoteDeliveryPartDataSource);
      _deliveryPartService = DeliveryPartService(deliveryPartRepository);

      // Initialize delivery repository and service
      final localDeliveryDataSource = LocalDeliveryDatabaseService();
      final remoteDeliveryDataSource = SupabaseDeliveryDataSource();
      final deliveryRepository = DeliveryRepositoryImpl(
          localDeliveryDataSource, remoteDeliveryDataSource);

      // Pass the repository, not the service
      _deliveryService = DeliveryService(
        deliveryRepository,
        deliveryPartRepository, // Pass repository, not service
      );

      // Initialize part repository and service
      final localPartDataSource = LocalPartDatabaseService();
      final remotePartDataSource = SupabasePartDataSource();
      final partRepository =
          PartRepositoryImpl(localPartDataSource, remotePartDataSource);
      _partService = PartService(partRepository);

      print('Services initialized successfully');
    } catch (e) {
      print('Error initializing services: $e');
      setState(() {
        _errorMessage = 'Failed to initialize services: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Load all required data
      final allDeliveries = await _deliveryService.watchAllDeliveries().first;
      final deliveryParts =
          await _deliveryPartService.watchAllDeliveryParts().first;
      final parts = await _partService.watchAllParts().first;

      setState(() {
        // For column chart: only delivered deliveries
        _deliveriesForColumnChart = allDeliveries
            .where((d) => d.status?.toLowerCase() == 'delivered')
            .toList();

        // For pie chart: all deliveries (will be filtered in _getPieChartData)
        _deliveriesForPieChart = allDeliveries;

        _deliveryParts = deliveryParts;
        _parts = parts;
        _isLoading = false;
      });

      print(
          '📊 Loaded ${_deliveriesForColumnChart.length} delivered orders for column chart');
      print(
          '📊 Loaded ${_deliveriesForPieChart.length} total deliveries for pie chart');
      print('📊 Loaded ${_deliveryParts.length} delivery parts');
      print('📊 Loaded ${_parts.length} parts');
    } catch (e) {
      print('❌ Error loading dashboard data: $e');
      setState(() {
        _errorMessage = 'Failed to load data: $e';
        _isLoading = false;
      });
    }
  }

  List<StackedColumnData> _getChartData() {
    if (_deliveriesForColumnChart.isEmpty ||
        _deliveriesForPieChart.isEmpty ||
        _deliveryParts.isEmpty ||
        _parts.isEmpty) {
      print(
          'Missing data for chart: deliveriesForColumnChart=${_deliveriesForColumnChart.length}, deliveriesForPieChart=${_deliveriesForPieChart.length}, parts=${_deliveryParts.length}, allParts=${_parts.length}');
      return [];
    }

    final List<StackedColumnData> chartData = [];
    final now = DateTime.now();

    // Create a map for quick part lookup
    final partMap = {for (var part in _parts) part.partId: part};

    if (_isMonthlyView) {
      // Group by month (last 12 months)
      for (int i = 11; i >= 0; i--) {
        final date = DateTime(now.year, now.month - i, 1);
        final periodKey = '${_getMonthName(date.month)} ${date.year}';

        // Get deliveries for this month
        final monthDeliveries = _deliveriesForColumnChart.where((delivery) {
          if (delivery.deliveredTime == null) return false;
          final deliveredDate = delivery.deliveredTime!;
          return deliveredDate.year == date.year &&
              deliveredDate.month == date.month;
        });

        // Count parts for each delivery in this month
        final partCounts = <String, int>{};

        for (final delivery in monthDeliveries) {
          final deliveryPartsForDelivery = _deliveryParts
              .where((dp) => dp.deliveryId == delivery.deliveryId);

          for (final deliveryPart in deliveryPartsForDelivery) {
            if (deliveryPart.partId != null &&
                partMap.containsKey(deliveryPart.partId)) {
              final part = partMap[deliveryPart.partId]!;
              final partName = part.name ?? 'Unknown Part';
              final quantity = deliveryPart.quantity ?? 1;

              partCounts[partName] = (partCounts[partName] ?? 0) + quantity;
            }
          }
        }

        // Add data for each part type (even if 0)
        final allPartNames = _parts.map((p) => p.name ?? 'Unknown').toSet();
        for (final partName in allPartNames) {
          final count = partCounts[partName] ?? 0;
          chartData.add(StackedColumnData(periodKey, partName, count));
        }
      }
    } else {
      // Group by year (last 5 years)
      for (int i = 4; i >= 0; i--) {
        final year = now.year - i;
        final periodKey = year.toString();

        // Get deliveries for this year
        final yearDeliveries = _deliveriesForColumnChart.where((delivery) {
          if (delivery.deliveredTime == null) return false;
          return delivery.deliveredTime!.year == year;
        });

        // Count parts for each delivery in this year
        final partCounts = <String, int>{};

        for (final delivery in yearDeliveries) {
          final deliveryPartsForDelivery = _deliveryParts
              .where((dp) => dp.deliveryId == delivery.deliveryId);

          for (final deliveryPart in deliveryPartsForDelivery) {
            if (deliveryPart.partId != null &&
                partMap.containsKey(deliveryPart.partId)) {
              final part = partMap[deliveryPart.partId]!;
              final partName = part.name ?? 'Unknown Part';
              final quantity = deliveryPart.quantity ?? 1;

              partCounts[partName] = (partCounts[partName] ?? 0) + quantity;
            }
          }
        }

        // Add data for each part type (even if 0)
        final allPartNames = _parts.map((p) => p.name ?? 'Unknown').toSet();
        for (final partName in allPartNames) {
          final count = partCounts[partName] ?? 0;
          chartData.add(StackedColumnData(periodKey, partName, count));
        }
      }
    }

    print('Generated ${chartData.length} chart data points');
    return chartData;
  }

  String _getMonthName(int month) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month];
  }

  List<StackedColumnSeries<StackedColumnData, String>> _createSeries() {
    final chartData = _getChartData();
    if (chartData.isEmpty) {
      print('No chart data available');
      return [];
    }

    // Group data by part name
    final groupedByPart = <String, List<StackedColumnData>>{};
    for (final data in chartData) {
      if (!groupedByPart.containsKey(data.partName)) {
        groupedByPart[data.partName] = [];
      }
      groupedByPart[data.partName]!.add(data);
    }

    // Create color palette
    final colors = [
      Color(0xFF101010),
      Color(0xFF2C2C2C),
      Color(0xFFFEA41D),
    ];

    final seriesList = <StackedColumnSeries<StackedColumnData, String>>[];
    int colorIndex = 0;

    for (final entry in groupedByPart.entries) {
      seriesList.add(
        StackedColumnSeries<StackedColumnData, String>(
          name: entry.key,
          dataSource: entry.value,
          xValueMapper: (data, _) => data.period,
          yValueMapper: (data, _) => data.count,
          color: colors[colorIndex % colors.length],
          dataLabelSettings: const DataLabelSettings(
            isVisible: false, // Turn off labels for cleaner look
          ),
        ),
      );
      colorIndex++;
    }

    print('Created ${seriesList.length} chart series');
    return seriesList;
  }

  // Add this method to get profile image (same as home screen)
  ImageProvider? _getProfileImage() {
    final authState = ref.read(authProvider);
    final user = authState.user;

    if (user?.profilePath == null || user!.profilePath!.isEmpty) {
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

  // Add this new method to get pie chart data
  List<DeliveryStatusData> _getPieChartData() {
    // Use _deliveriesForPieChart instead of _deliveries
    final allDeliveries = _deliveriesForPieChart;

    // Define the ONLY statuses we want to show in pie chart
    final allowedStatuses = {
      'incoming',
      'picked_up',
      'picked up',
      'en_route',
      'en route',
      'awaiting'
    };

    // Filter deliveries to ONLY include the allowed statuses
    final nonDeliveredDeliveries = allDeliveries.where((d) {
      if (d.status == null || d.status!.isEmpty) return false;

      final status = d.status!.toLowerCase().trim();

      // Only include if status is in our allowed list
      return allowedStatuses.contains(status);
    }).toList();

    print(
        '📊 Pie chart filtering: ${allDeliveries.length} total deliveries -> ${nonDeliveredDeliveries.length} pending deliveries');

    if (nonDeliveredDeliveries.isEmpty) {
      return [];
    }

    // Count deliveries by status
    final statusCounts = <String, int>{};
    for (final delivery in nonDeliveredDeliveries) {
      final status = delivery.status!.toLowerCase().trim();

      // Normalize status names for consistent grouping
      String normalizedStatus;
      switch (status) {
        case 'picked_up':
        case 'picked up':
          normalizedStatus = 'picked_up';
          break;
        case 'en_route':
        case 'en route':
          normalizedStatus = 'en_route';
          break;
        case 'incoming':
          normalizedStatus = 'incoming';
          break;
        case 'awaiting':
          normalizedStatus = 'awaiting';
          break;
        default:
          // Skip any unexpected statuses
          print('⚠️ Skipping unexpected status in pie chart: $status');
          continue;
      }

      statusCounts[normalizedStatus] =
          (statusCounts[normalizedStatus] ?? 0) + 1;
    }

    // Define colors for each status
    final statusColors = {
      'incoming': Color(0xFF101010),
      'awaiting': Color(0xFFFEA41D),
      'picked_up': Color(0xFF4B97FA),
      // Fix: changed from 'picked up' to 'picked_up'
      'en_route': Color(0xFFC084FC),
      // Fix: changed from 'en route' to 'en_route'
    };

    // Define display names for each status
    final statusDisplayNames = {
      'awaiting': 'Awaiting',
      'incoming': 'Incoming',
      'picked_up': 'Picked Up',
      'en_route': 'En Route',
    };

    // Create pie chart data
    final pieData = <DeliveryStatusData>[];
    for (final entry in statusCounts.entries) {
      final displayName = statusDisplayNames[entry.key] ?? entry.key;
      final color = statusColors[entry.key] ?? Colors.grey;

      pieData.add(DeliveryStatusData(
        displayName,
        entry.value,
        color,
      ));
    }

    print(
        '📊 Pie chart data: ${pieData.map((d) => '${d.status}: ${d.count}').join(', ')}');
    return pieData;
  }

  // Add this method to build the pie chart
  Widget _buildPieChart() {
    final pieData = _getPieChartData();

    if (pieData.isEmpty) {
      return Container(
        height: 300,
        decoration: BoxDecoration(
          color: AppColors.cgrey,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.pie_chart, color: Colors.white54, size: 48),
              SizedBox(height: 16),
              Text(
                'All deliveries completed!',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                'No pending deliveries to show',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 400,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cgrey,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pending Delivery Status Distribution',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SfCircularChart(
              legend: Legend(
                isVisible: true,
                position: LegendPosition.right,
                textStyle: const TextStyle(color: Colors.white, fontSize: 12),
                overflowMode: LegendItemOverflowMode.wrap,
              ),
              tooltipBehavior: TooltipBehavior(
                enable: true,
                color: AppColors.cgrey,
                textStyle: const TextStyle(color: Colors.white),
                builder: (dynamic data, dynamic point, dynamic series,
                    int pointIndex, int seriesIndex) {
                  final statusData = data as DeliveryStatusData;
                  final pieData = _getPieChartData();
                  final total =
                      pieData.fold(0, (sum, item) => sum + item.count);
                  final percentage =
                      ((statusData.count / total) * 100).toStringAsFixed(1);
                  return Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.cgrey,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      '${statusData.status}: ${statusData.count} deliveries ($percentage%)',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  );
                },
              ),
              series: <PieSeries<DeliveryStatusData, String>>[
                PieSeries<DeliveryStatusData, String>(
                  dataSource: pieData,
                  xValueMapper: (data, _) => data.status,
                  yValueMapper: (data, _) => data.count,
                  pointColorMapper: (data, _) => data.color,
                  dataLabelSettings: const DataLabelSettings(
                    isVisible: true,
                    labelPosition: ChartDataLabelPosition.outside,
                    textStyle: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    connectorLineSettings: ConnectorLineSettings(
                      color: Colors.white,
                      width: 1,
                    ),
                  ),
                  dataLabelMapper: (data, _) => '${data.count}',
                  radius: '80%',
                  explode: true,
                  explodeIndex: 0,
                  explodeOffset: '10%',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationLink(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end, // align button to the right
      children: [
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const DeliveryOverviewScreen(),
              ),
            );
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                'View Detailed Delivery Overview',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  decoration: TextDecoration.underline,
                ),
              ),
              SizedBox(width: 4), // spacing between text and icon
              Icon(Icons.keyboard_arrow_right, color: Colors.white, size: 16),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get current user for profile display
    final authState = ref.watch(authProvider);
    final currentUser = authState.user;

    return Scaffold(
      backgroundColor: AppColors.cblack,
      appBar: AppBar(
        title: const Text(
          'Dashboard',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadData,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(20),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey[300],
                backgroundImage: _getProfileImage(),
                child: _getProfileImage() == null
                    ? (currentUser?.username?.isNotEmpty == true
                        ? Text(
                            currentUser!.username![0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : const Icon(Icons.person, color: Colors.black))
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text('Loading dashboard data...',
                      style: TextStyle(color: Colors.white)),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.cyellow,
                          foregroundColor: Colors.black,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Existing content
                      _buildViewToggle(),
                      const SizedBox(height: 24),
                      _buildChart(),
                      const SizedBox(height: 24),
                      _buildStatsCards(),

                      // NEW PIE CHART SECTION
                      const SizedBox(height: 32),
                      _buildPieChart(),
                      _buildNavigationLink(context),
                      const SizedBox(height: 24),
                      _buildTopSellingParts(),
                      const SizedBox(
                        height: 24,
                      )
                    ],
                  ),
                ),
    );
  }

  Widget _buildViewToggle() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cgrey,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleButton('Monthly', _isMonthlyView, () {
            setState(() => _isMonthlyView = true);
          }),
          _buildToggleButton('Yearly', !_isMonthlyView, () {
            setState(() => _isMonthlyView = false);
          }),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String text, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.cyellow : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildChart() {
    final chartData = _getChartData();

    if (chartData.isEmpty) {
      return Container(
        height: 300,
        decoration: BoxDecoration(
          color: AppColors.cgrey,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bar_chart, color: Colors.white54, size: 48),
              SizedBox(height: 16),
              Text(
                'No delivery data available',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                'Complete some deliveries to see the chart',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 450,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cgrey,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_isMonthlyView ? 'Monthly' : 'Yearly'} Parts Delivered',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SfCartesianChart(
              primaryXAxis: CategoryAxis(
                labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
                axisLine: const AxisLine(color: Colors.white),
                majorTickLines: const MajorTickLines(color: Colors.white),
                labelRotation: _isMonthlyView ? 45 : 0,
              ),
              primaryYAxis: NumericAxis(
                labelStyle: const TextStyle(color: Colors.white),
                axisLine: const AxisLine(color: Colors.white),
                majorTickLines: const MajorTickLines(color: Colors.white),
                majorGridLines: const MajorGridLines(color: Colors.grey),
                title: AxisTitle(
                  text: 'Number of Parts',
                  textStyle: const TextStyle(color: Colors.white),
                ),
              ),
              legend: Legend(
                isVisible: true,
                position: LegendPosition.bottom,
                textStyle: const TextStyle(color: Colors.white, fontSize: 10),
                overflowMode: LegendItemOverflowMode.wrap,
              ),
              tooltipBehavior: TooltipBehavior(
                enable: true,
                color: AppColors.cgrey,
                textStyle: const TextStyle(color: Colors.white),
                format: 'point.x: point.y parts',
              ),
              series: _createSeries(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    final chartData = _getChartData();
    final totalParts = chartData.fold(0, (sum, data) => sum + data.count);
    final uniqueParts = chartData.map((data) => data.partName).toSet().length;
    final activePeriods = chartData
        .where((data) => data.count > 0)
        .map((data) => data.period)
        .toSet()
        .length;
    final avgPerPeriod = activePeriods > 0 ? (totalParts / activePeriods) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Summary Statistics',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
                child: _buildStatCard('Total Parts Delivered',
                    totalParts.toString(), Icons.inventory, Colors.blue)),
            const SizedBox(width: 16),
            Expanded(
                child: _buildStatCard('Different Part Types',
                    uniqueParts.toString(), Icons.category, Colors.green)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
                child: _buildStatCard(
                    'Active Periods',
                    activePeriods.toString(),
                    Icons.calendar_month,
                    Colors.orange)),
            const SizedBox(width: 16),
            Expanded(
                child: _buildStatCard(
                    'Avg per Period',
                    avgPerPeriod.toStringAsFixed(1),
                    Icons.trending_up,
                    Colors.purple)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cgrey,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Reusable method to build individual status cards
  Widget _buildStatusCard(
      String title, String value, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cgrey,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Add this method to get top selling parts
  List<TopSellingPart> _getTopSellingParts() {
    if (_deliveriesForColumnChart.isEmpty ||
        _deliveryParts.isEmpty ||
        _parts.isEmpty) {
      return [];
    }

    // Count total quantity sold for each part
    final partSales = <String, int>{};

    for (final delivery in _deliveriesForColumnChart) {
      final deliveryPartsForDelivery =
          _deliveryParts.where((dp) => dp.deliveryId == delivery.deliveryId);

      for (final deliveryPart in deliveryPartsForDelivery) {
        if (deliveryPart.partId != null) {
          final quantity = deliveryPart.quantity ?? 1;
          partSales[deliveryPart.partId!] =
              (partSales[deliveryPart.partId!] ?? 0) + quantity;
        }
      }
    }

    // Create TopSellingPart objects and sort by sales
    final topParts = <TopSellingPart>[];
    final partMap = {for (var part in _parts) part.partId: part};

    for (final entry in partSales.entries) {
      if (partMap.containsKey(entry.key)) {
        final part = partMap[entry.key]!;
        topParts.add(TopSellingPart(
          partId: part.partId,
          name: part.name ?? 'Unknown Part',
          category: part.category,
          description: part.description,
          totalSold: entry.value,
        ));
      }
    }

    // Sort by total sold (descending) and take top 3
    topParts.sort((a, b) => b.totalSold.compareTo(a.totalSold));
    return topParts.take(3).toList();
  }

  // Add this method to build the top selling parts section
  Widget _buildTopSellingParts() {
    final topParts = _getTopSellingParts();

    if (topParts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cgrey,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Column(
            children: [
              Icon(Icons.inventory_2, color: Colors.white54, size: 48),
              SizedBox(height: 16),
              Text(
                'No sales data available',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cgrey,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top 3 Selling Products',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...topParts.asMap().entries.map((entry) {
            final index = entry.key;
            final part = entry.value;
            return _buildTopPartItem(part, index + 1);
          }).toList(),
        ],
      ),
    );
  }

  // Add this method to build individual part items
  Widget _buildTopPartItem(TopSellingPart part, int rank) {
    return InkWell(
      onTap: () => _showPartDetailsDialog(part),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            // Rank badge
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: _getRankColor(rank),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$rank',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Part info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    part.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (part.category != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      part.category!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Total sold
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.cyellow.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${part.totalSold} sold',
                style: const TextStyle(
                  color: AppColors.cyellow,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              color: Colors.white54,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  // Add this method to get rank colors
  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber; // Gold
      case 2:
        return Colors.grey; // Silver
      case 3:
        return Colors.orange; // Bronze
      default:
        return Colors.blue;
    }
  }

  // Add this method to show part details dialog
  void _showPartDetailsDialog(TopSellingPart part) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: AppColors.cgrey,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    const Icon(
                      Icons.inventory_2,
                      color: AppColors.cyellow,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Part Details',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Part name
                _buildDetailRow('Name', part.name),

                // Part category
                if (part.category != null)
                  _buildDetailRow('Category', part.category!),

                // Total sold
                _buildDetailRow('Total Sold', '${part.totalSold} units'),

                // Description
                if (part.description != null &&
                    part.description!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Description',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(
                      part.description!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Close button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.cyellow,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Add this helper method for detail rows
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w600,
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

  @override
  void dispose() {
    super.dispose();
  }
}
