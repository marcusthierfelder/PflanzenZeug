import 'capture_context_tag.dart';

class PlantPhoto {
  final String id;
  final String plantId;
  final String filePath;
  final DateTime takenAt;
  final String purpose; // 'identification', 'diagnosis', 'progress'

  /// Optionaler Kontext-Tag der beim Fotografieren ausgewählt wurde.
  /// Wird für spätere Re-Diagnosen mitgeführt.
  final CaptureContextTag? contextTag;

  PlantPhoto({
    required this.id,
    required this.plantId,
    required this.filePath,
    required this.takenAt,
    this.purpose = 'progress',
    this.contextTag,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'plantId': plantId,
        'filePath': filePath,
        'takenAt': takenAt.toIso8601String(),
        'purpose': purpose,
        if (contextTag != null) 'contextTag': contextTag!.toJson(),
      };

  factory PlantPhoto.fromJson(Map<dynamic, dynamic> json) => PlantPhoto(
        id: json['id'] as String,
        plantId: json['plantId'] as String,
        filePath: json['filePath'] as String,
        takenAt: DateTime.parse(json['takenAt'] as String),
        purpose: json['purpose'] as String? ?? 'progress',
        contextTag: json['contextTag'] != null
            ? CaptureContextTag.fromJson(
                json['contextTag'] as Map<dynamic, dynamic>)
            : null,
      );
}
