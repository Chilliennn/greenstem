class Location {
  final String locationId;
  final String? name;
  final String? type;
  final String? address;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Location({
    required this.locationId,
    this.name,
    this.type,
    this.address,
    this.latitude,
    this.longitude,
    required this.createdAt,
    required this.updatedAt,
  });

  Location copyWith({
    String? locationId,
    String? name,
    String? type,
    String? address,
    double? latitude,
    double? longitude,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Location(
      locationId: locationId ?? this.locationId,
      name: name ?? this.name,
      type: type ?? this.type,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Business logic
  bool get hasCoordinates => latitude != null && longitude != null;

  bool get hasAddress => address != null && address!.isNotEmpty;

  bool get hasName => name != null && name!.isNotEmpty;

  bool get isWarehouse => type?.toLowerCase() == 'warehouse';

  bool get isCustomer => type?.toLowerCase() == 'customer';

  bool get isPickupLocation => type?.toLowerCase() == 'pickup';

  bool get isDeliveryLocation => type?.toLowerCase() == 'delivery';

  String get displayName => name ?? 'Unnamed Location';

  String get displayType => type ?? 'Unknown';

  String get displayAddress => address ?? 'No address';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Location &&
          runtimeType == other.runtimeType &&
          locationId == other.locationId;

  @override
  int get hashCode => locationId.hashCode;
}
