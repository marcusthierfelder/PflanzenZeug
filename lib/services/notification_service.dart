import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/care_schedule.dart';
import 'database_service.dart';

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Berlin'));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings);
    _initialized = true;
  }

  Future<void> requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> scheduleAllCareReminders() async {
    await _plugin.cancelAll();

    final db = DatabaseService.instance;
    final plants = db.getAllPlants();

    for (final plant in plants) {
      final schedules = db.getCareSchedulesForPlant(plant.id);
      for (final care in schedules) {
        await _scheduleCareNotification(
          care: care,
          plantName: plant.nickname,
        );
      }
    }
  }

  Future<void> _scheduleCareNotification({
    required CareSchedule care,
    required String plantName,
  }) async {
    final scheduledDate = tz.TZDateTime.from(care.nextDue, tz.local);
    final now = tz.TZDateTime.now(tz.local);

    // Nicht in der Vergangenheit planen
    if (scheduledDate.isBefore(now)) {
      // Bereits überfällig: sofortige Benachrichtigung
      await _plugin.show(
        care.id.hashCode,
        _title(care.type),
        '$plantName: ${_body(care.type)}',
        _details,
      );
      return;
    }

    await _plugin.zonedSchedule(
      care.id.hashCode,
      _title(care.type),
      '$plantName: ${_body(care.type)}',
      scheduledDate,
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  String _title(String type) =>
      type == 'watering' ? 'Gießen nicht vergessen!' : 'Zeit zum Düngen!';

  String _body(String type) => type == 'watering'
      ? 'Deine Pflanze braucht Wasser.'
      : 'Deine Pflanze braucht Dünger.';

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'care_reminders',
      'Pflege-Erinnerungen',
      channelDescription: 'Erinnerungen zum Gießen und Düngen',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );
}
