import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/fertilizer.dart';
import '../services/database_service.dart';

final fertilizersProvider = Provider<List<Fertilizer>>((ref) {
  return DatabaseService.instance.getAllFertilizers();
});
