import '../../domain/entities/part.dart';

class PartModel {
  final String partId;
  final String? name;
  final String? description;
  final String? category;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isSynced;
  final bool needsSync;

  const PartModel({
    required this.partId,
    this.name,
    this.description,
    this.category,
    required this.createdAt,
    this.updatedAt,
    this.isSynced = false,
    this.needsSync = true,
  });

  factory PartModel.fromJson(Map<String, dynamic> json) {
    return PartModel(
      partId: json['part_id'] as String,
      name: json['name'] as String?,
      description: json['description'] as String?,
      category: json['category'] as String?,
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
      'part_id': partId,
      'name': name,
      'description': description,
      'category': category,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
      'needs_sync': needsSync ? 1 : 0,
    };
  }

  // Convert to domain entity
  Part toEntity() {
    return Part(
      partId: partId,
      name: name,
      description: description,
      category: category,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  // Create from domain entity
  factory PartModel.fromEntity(Part entity, {bool? isSynced, bool? needsSync}) {
    return PartModel(
      partId: entity.partId,
      name: entity.name,
      description: entity.description,
      category: entity.category,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      isSynced: isSynced ?? false,
      needsSync: needsSync ?? true,
    );
  }

  PartModel copyWith({
    String? partId,
    String? name,
    String? description,
    String? category,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
    bool? needsSync,
  }) {
    return PartModel(
      partId: partId ?? this.partId,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      needsSync: needsSync ?? this.needsSync,
    );
  }
}
