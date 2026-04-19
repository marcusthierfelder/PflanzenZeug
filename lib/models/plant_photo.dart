class PlantPhoto {
  final String id;
  final String plantId;
  final String filePath;
  final DateTime takenAt;
  final String purpose; // 'identification', 'diagnosis', 'progress'

  PlantPhoto({
    required this.id,
    required this.plantId,
    required this.filePath,
    required this.takenAt,
    this.purpose = 'progress',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'plantId': plantId,
        'filePath': filePath,
        'takenAt': takenAt.toIso8601String(),
        'purpose': purpose,
      };

  factory PlantPhoto.fromJson(Map<dynamic, dynamic> json) => PlantPhoto(
        id: json['id'] as String,
        plantId: json['plantId'] as String,
        filePath: json['filePath'] as String,
        takenAt: DateTime.parse(json['takenAt'] as String),
        purpose: json['purpose'] as String? ?? 'progress',
      );
}
