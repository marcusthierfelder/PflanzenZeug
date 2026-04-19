class CareSchedule {
  final String id;
  final String plantId;
  final String type; // 'watering' or 'fertilizing'
  int intervalDays;
  DateTime lastDone;
  String? fertilizerId;
  String? notes;

  CareSchedule({
    required this.id,
    required this.plantId,
    required this.type,
    required this.intervalDays,
    required this.lastDone,
    this.fertilizerId,
    this.notes,
  });

  DateTime get nextDue => lastDone.add(Duration(days: intervalDays));
  bool get isOverdue => DateTime.now().isAfter(nextDue);

  Map<String, dynamic> toJson() => {
        'id': id,
        'plantId': plantId,
        'type': type,
        'intervalDays': intervalDays,
        'lastDone': lastDone.toIso8601String(),
        'fertilizerId': fertilizerId,
        'notes': notes,
      };

  factory CareSchedule.fromJson(Map<dynamic, dynamic> json) => CareSchedule(
        id: json['id'] as String,
        plantId: json['plantId'] as String,
        type: json['type'] as String,
        intervalDays: json['intervalDays'] as int,
        lastDone: DateTime.parse(json['lastDone'] as String),
        fertilizerId: json['fertilizerId'] as String?,
        notes: json['notes'] as String?,
      );
}
