class PartModel {
  final String partId;
  final String? name;
  final String? description;
  final String? category;
  final DateTime createdAt;

  const PartModel({
    required this.partId,
    this.name,
    this.description,
    this.category,
    required this.createdAt,
  });

  factory PartModel.fromJson(Map<String, dynamic> json) {
    return PartModel(
      partId: json['part_id'],
      name: json['name'],
      description: json['description'],
      category: json['category'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'part_id': partId,
      'name': name,
      'description': description,
      'category': category,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
