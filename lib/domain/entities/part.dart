class Part {
  final String partId;
  final String? name;
  final String? description;
  final String? category;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Part({
    required this.partId,
    this.name,
    this.description,
    this.category,
    required this.createdAt,
    this.updatedAt,
  });

  Part copyWith({
    String? partId,
    String? name,
    String? description,
    String? category,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Part(
      partId: partId ?? this.partId,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Business logic
  bool get hasName => name != null && name!.isNotEmpty;

  bool get hasDescription => description != null && description!.isNotEmpty;

  bool get hasCategory => category != null && category!.isNotEmpty;

  String get displayName => name ?? 'Unnamed Part';

  String get displayCategory => category ?? 'Uncategorized';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Part &&
          runtimeType == other.runtimeType &&
          partId == other.partId;

  @override
  int get hashCode => partId.hashCode;
}
