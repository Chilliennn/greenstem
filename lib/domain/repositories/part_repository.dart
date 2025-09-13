import '../entities/part.dart';

abstract class PartRepository {
  // Offline-first read operations (streams)
  Stream<List<Part>> watchAllParts();

  Stream<List<Part>> watchPartsByCategory(String category);

  Stream<Part?> watchPartById(String partId);

  // Offline-first write operations
  Future<Part> createPart(Part part);

  Future<Part> updatePart(Part part);

  Future<void> deletePart(String partId);

  // Sync operations
  Future<void> syncToRemote();

  Future<void> syncFromRemote();

  Future<bool> hasNetworkConnection();

  // Local cache operations
  Future<List<Part>> getCachedParts();

  Future<void> clearCache();
}
