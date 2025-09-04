class LocationModel {
  final String locationId;
  final String? name;
  final String? type;
  final String? address;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;

  const LocationModel({
    required this.locationId,
    this.name,
    this.type,
    this.address,
    this.latitude,
    this.longitude,
    required this.createdAt,
  });

  factory LocationModel.fromJson(Map<String, dynamic> json) {
    return LocationModel(
      locationId: json['location_id'],
      name: json['name'],
      type: json['type'],
      address: json['address'],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      createdAt: DateTime.parse(json['created_at']),
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
    };
  }
}
