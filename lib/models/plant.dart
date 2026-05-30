class Plant {
  final String id;
  String nickname;
  String? speciesName;
  String? scientificName;
  String location;
  String potInfo;
  bool isMixedPot;
  String? coverPhotoId;
  String? identificationResult;
  double? identificationConfidence;
  String? diagnosisResult;
  /// Strukturiertes JSON-Profil der Pflanzen-Identifikation (JSON-String).
  /// Kann null sein für Altdaten (Fallback auf [identificationResult] als Markdown).
  String? careProfileJson;
  /// Strukturiertes JSON der letzten Diagnose (JSON-String, neues Format).
  /// Kann null sein für Altdaten → Fallback auf [diagnosisResult] als Markdown.
  String? diagnosisResultJson;
  final DateTime createdAt;
  DateTime updatedAt;
  DateTime? lastCheckUp;

  Plant({
    required this.id,
    required this.nickname,
    this.speciesName,
    this.scientificName,
    this.location = '',
    this.potInfo = '',
    this.isMixedPot = false,
    this.coverPhotoId,
    this.identificationResult,
    this.identificationConfidence,
    this.diagnosisResult,
    this.careProfileJson,
    this.diagnosisResultJson,
    required this.createdAt,
    required this.updatedAt,
    this.lastCheckUp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'nickname': nickname,
        'speciesName': speciesName,
        'scientificName': scientificName,
        'location': location,
        'potInfo': potInfo,
        'isMixedPot': isMixedPot,
        'coverPhotoId': coverPhotoId,
        'identificationResult': identificationResult,
        'identificationConfidence': identificationConfidence,
        'diagnosisResult': diagnosisResult,
        'careProfileJson': careProfileJson,
        'diagnosisResultJson': diagnosisResultJson,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'lastCheckUp': lastCheckUp?.toIso8601String(),
      };

  factory Plant.fromJson(Map<dynamic, dynamic> json) => Plant(
        id: json['id'] as String,
        nickname: json['nickname'] as String,
        speciesName: json['speciesName'] as String?,
        scientificName: json['scientificName'] as String?,
        location: json['location'] as String? ?? '',
        potInfo: json['potInfo'] as String? ?? '',
        isMixedPot: json['isMixedPot'] as bool? ?? false,
        coverPhotoId: json['coverPhotoId'] as String?,
        identificationResult: json['identificationResult'] as String?,
        identificationConfidence: (json['identificationConfidence'] as num?)?.toDouble(),
        diagnosisResult: json['diagnosisResult'] as String?,
        // Defensiv: careProfileJson fehlt bei Altdaten → null (Fallback auf Markdown)
        careProfileJson: json['careProfileJson'] as String?,
        // Defensiv: diagnosisResultJson fehlt bei Altdaten → null (Fallback auf diagnosisResult)
        diagnosisResultJson: json['diagnosisResultJson'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        lastCheckUp: json['lastCheckUp'] != null
            ? DateTime.parse(json['lastCheckUp'] as String)
            : null,
      );
}
