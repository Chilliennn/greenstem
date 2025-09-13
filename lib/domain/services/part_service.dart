import '../entities/part.dart';
import '../repositories/part_repository.dart';

class PartService {
  final PartRepository _repository;

  PartService(this._repository);

  // Stream-based reading (offline-first)
  Stream<List<Part>> watchAllParts() {
    return _repository.watchAllParts();
  }

  Stream<List<Part>> watchPartsByCategory(String category) {
    return _repository.watchPartsByCategory(category);
  }

  Stream<Part?> watchPartById(String partId) {
    return _repository.watchPartById(partId);
  }

  // Write operations (offline-first)
  Future<Part> createPart(Part part) async {
    try {
      return await _repository.createPart(part);
    } catch (e) {
      throw Exception('Failed to create part: $e');
    }
  }

  Future<Part> updatePart(Part part) async {
    try {
      return await _repository.updatePart(part);
    } catch (e) {
      throw Exception('Failed to update part: $e');
    }
  }

  Future<void> deletePart(String partId) async {
    try {
      await _repository.deletePart(partId);
    } catch (e) {
      throw Exception('Failed to delete part: $e');
    }
  }

  // Business logic methods
  Future<Part> updatePartName(String partId, String newName) async {
    final partStream = _repository.watchPartById(partId);
    final part = await partStream.first;

    if (part == null) {
      throw Exception('Part not found');
    }

    final updatedPart = part.copyWith(
      name: newName,
      updatedAt: DateTime.now(),
    );

    return await updatePart(updatedPart);
  }

  Future<Part> updatePartCategory(String partId, String newCategory) async {
    final partStream = _repository.watchPartById(partId);
    final part = await partStream.first;

    if (part == null) {
      throw Exception('Part not found');
    }

    final updatedPart = part.copyWith(
      category: newCategory,
      updatedAt: DateTime.now(),
    );

    return await updatePart(updatedPart);
  }

  Future<Part> updatePartDescription(
      String partId, String newDescription) async {
    final partStream = _repository.watchPartById(partId);
    final part = await partStream.first;

    if (part == null) {
      throw Exception('Part not found');
    }

    final updatedPart = part.copyWith(
      description: newDescription,
      updatedAt: DateTime.now(),
    );

    return await updatePart(updatedPart);
  }

  // Get unique categories
  Future<List<String>> getCategories() async {
    final parts = await _repository.getCachedParts();
    final categories = parts
        .map((part) => part.category)
        .where((category) => category != null && category.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();
    categories.sort();
    return categories;
  }

  // Sync operations
  Future<void> syncData() async {
    try {
      await _repository.syncToRemote();
      await _repository.syncFromRemote();
    } catch (e) {
      throw Exception('Failed to sync data: $e');
    }
  }

  Future<bool> hasNetworkConnection() => _repository.hasNetworkConnection();
}
