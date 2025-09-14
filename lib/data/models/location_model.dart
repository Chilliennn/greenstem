import '../../domain/entities/location.dart';

class LocationModel {
  final String locationId;
  final String? name;
  final String? type;
  final String? address;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isSynced;
  final bool needsSync;

  const LocationModel({
    required this.locationId,
    this.name,
    this.type,
    this.address,
    this.latitude,
    this.longitude,
    required this.createdAt,
    this.updatedAt,
    this.isSynced = false,
    this.needsSync = true,
  });

  factory LocationModel.fromJson(Map<String, dynamic> json) {
    return LocationModel(
      locationId: json['location_id'] as String,
      name: json['name'] as String?,
      type: json['type'] as String?,
      address: json['address'] as String?,
      latitude: json['latitude'] as double?,
      longitude: json['longitude'] as double?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      isSynced: (json['is_synced'] as int?) == 1,
      needsSync: (json['needs_sync'] as int?) == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'location_id': locationId,
      'name': name,
      'type': type,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
      'needs_sync': needsSync ? 1 : 0,
    };
  }

  // Convert to domain entity
  Location toEntity() {
    return Location(
      locationId: locationId,
      name: name,
      type: type,
      address: address,
      latitude: latitude,
      longitude: longitude,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  // Create from domain entity
  factory LocationModel.fromEntity(Location entity,
      {bool? isSynced, bool? needsSync}) {
    return LocationModel(
      locationId: entity.locationId,
      name: entity.name,
      type: entity.type,
      address: entity.address,
      latitude: entity.latitude,
      longitude: entity.longitude,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      isSynced: isSynced ?? false,
      needsSync: needsSync ?? true,
    );
  }

  LocationModel copyWith({
    String? locationId,
    String? name,
    String? type,
    String? address,
    double? latitude,
    double? longitude,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
    bool? needsSync,
  }) {
    return LocationModel(
      locationId: locationId ?? this.locationId,
      name: name ?? this.name,
      type: type ?? this.type,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      needsSync: needsSync ?? this.needsSync,
    );
  }
}
