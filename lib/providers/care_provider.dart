import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/care_schedule.dart';
import '../services/database_service.dart';

final overdueCaresProvider = Provider<List<CareSchedule>>((ref) {
  return DatabaseService.instance.getOverdueCareSchedules();
});
